use std::collections::HashMap;
use std::sync::OnceLock;

use anyhow::{Context, Result, ensure};
use ctypst::Document;
use serde_json::Value;

use crate::render::{
    Compiler, DocumentKind, DocumentSpec, cvl_cl_spec, cvl_cv_spec, opportunity_specs,
};
use crate::workspace::Workspace;

pub fn cvl_specs(workspace: &Workspace) -> Result<Vec<DocumentSpec>> {
    let mut specs = Vec::new();
    for locale in ["de-ch", "en-ch"] {
        let mut cv = cvl_cv_spec(workspace, locale, 4)?;
        cv.inputs
            .insert("line-contracts".to_owned(), "report".to_owned());
        specs.push(cv);
        let mut cl = cvl_cl_spec(workspace, locale)?;
        cl.inputs
            .insert("line-contracts".to_owned(), "report".to_owned());
        specs.push(cl);
    }
    Ok(specs)
}

pub fn keyed_specs(
    workspace: &Workspace,
    organisation: &str,
    position: &str,
) -> Result<Vec<DocumentSpec>> {
    let mut specs = opportunity_specs(workspace, organisation, position)?;
    for spec in &mut specs {
        spec.inputs
            .insert("line-contracts".to_owned(), "report".to_owned());
    }
    Ok(specs)
}

pub fn evaluate(workspace: &Workspace, spec: &DocumentSpec) -> Result<Vec<Value>> {
    evaluate_with(workspace, &Compiler::new(workspace)?, spec)
}

fn evaluate_with(
    workspace: &Workspace,
    compiler: &Compiler,
    spec: &DocumentSpec,
) -> Result<Vec<Value>> {
    let document = compiler.compile(workspace, spec)?;
    document_metrics(workspace, spec, &document)
}

/// Query the line/layout metrics of an already compiled document and enforce
/// the structural metric set. Lets callers reuse one compilation for both
/// measurement and PDF export instead of compiling twice.
pub fn document_metrics(
    workspace: &Workspace,
    spec: &DocumentSpec,
    document: &Document,
) -> Result<Vec<Value>> {
    let mut metrics = Vec::new();
    for label_name in ["ccvl-line", "ccvl-layout"] {
        metrics.extend(
            ctypst::query_json(document, label_name)
                .with_context(|| format!("cannot query {} metrics", spec.name))?,
        );
    }
    validate_metric_set(workspace, spec, &metrics)?;
    Ok(metrics)
}

/// Format the fill violation of one measured line, if any. Shared by the
/// standalone `measure` command and the fused check gate so both report the
/// same failure text.
pub fn line_failure(
    spec: &DocumentSpec,
    index: usize,
    metric: &Value,
) -> Result<Option<String>> {
    violation(metric).map(|state| {
        state.map(|state| {
            format!(
                "{} #{} {state}: {:.1} outside {}–{}",
                spec.name,
                index + 1,
                number_field(metric, "actual_fill")
                    .expect("violation implies numeric actual_fill"),
                number_field(metric, "min_fill").expect("violation implies numeric min_fill"),
                number_field(metric, "max_fill").expect("violation implies numeric max_fill"),
            )
        })
    })
}

pub fn measure(
    workspace: &Workspace,
    specs: &[DocumentSpec],
    show_all: bool,
    emit: bool,
) -> Result<Vec<String>> {
    let compiler = Compiler::new(workspace)?;
    let mut failures = Vec::new();
    for spec in specs {
        let metrics = evaluate_with(workspace, &compiler, spec)?;
        let advisories = preference_warnings(workspace, spec, &metrics)?;
        if emit {
            for advisory in &advisories {
                println!("WARN {advisory}");
            }
        }
        let mut document_failures = Vec::new();
        for (index, metric) in metrics.iter().enumerate() {
            let state = violation(metric)?;
            if show_all || state.is_some() {
                let status = if state.is_none() { "PASS" } else { "FAIL" };
                let unit = metric.get("unit").and_then(Value::as_str).unwrap_or("%");
                println!(
                    "{status} {} #{} {} {:.1}{unit} (target {}{unit}, allowed {}–{}{unit}): {}",
                    spec.name,
                    index + 1,
                    string_field(metric, "kind")?,
                    number_field(metric, "actual_fill")?,
                    number_field(metric, "target_fill")?,
                    number_field(metric, "min_fill")?,
                    number_field(metric, "max_fill")?,
                    compact_text(metric.get("text").unwrap_or(&Value::Null))
                );
            }
            if let Some(failure) = line_failure(spec, index, metric)? {
                document_failures.push(failure);
            }
        }
        failures.extend(document_failures.iter().cloned());
        if emit && !show_all {
            println!(
                "{} {}: {} measured lines{}",
                if document_failures.is_empty() {
                    "PASS"
                } else {
                    "FAIL"
                },
                spec.name,
                metrics.len(),
                if advisories.is_empty() {
                    String::new()
                } else {
                    format!(", {} preference warning(s)", advisories.len())
                }
            );
        }
    }
    if !failures.is_empty() && emit {
        eprintln!(
            "Line measurement failed. Rewrite with relevant, verified signal—not filler—then run `ccvl measure` again."
        );
    }
    Ok(failures)
}

pub fn violation(metric: &Value) -> Result<Option<&'static str>> {
    let actual = number_field(metric, "actual_fill")?;
    if actual < number_field(metric, "min_fill")? {
        Ok(Some("too short"))
    } else if actual > number_field(metric, "max_fill")? {
        Ok(Some("too long"))
    } else {
        Ok(None)
    }
}

fn validate_metric_set(
    workspace: &Workspace,
    spec: &DocumentSpec,
    metrics: &[Value],
) -> Result<()> {
    let mut counts = HashMap::<&str, usize>::new();
    for metric in metrics {
        *counts.entry(string_field(metric, "kind")?).or_default() += 1;
    }
    match spec.kind {
        DocumentKind::Cv => {
            ensure!(
                counts.get("cv-summary") == Some(&5),
                "{}: expected exactly five measured Summary lines",
                spec.name
            );
            for required in ["cv-heading", "cv-subheading", "cv-bullet"] {
                ensure!(
                    counts.get(required).copied().unwrap_or_default() > 0,
                    "{}: no measured {required} lines found",
                    spec.name
                );
            }
        }
        DocumentKind::CoverLetter => {
            let contract = workspace.read_json("ccvl.json")?;
            let contract = contract
                .pointer("/documents/cover_letter")
                .context("missing cover-letter contract")?;
            let paragraph_counts = paragraph_counts(spec, metrics)?;
            let paragraph_contracts = contract
                .get("paragraphs")
                .and_then(Value::as_array)
                .context("missing paragraph contracts")?;
            for (index, (actual, declared)) in
                paragraph_counts.iter().zip(paragraph_contracts).enumerate()
            {
                let min = usize::try_from(
                    declared
                        .pointer("/lines/minimum")
                        .and_then(Value::as_u64)
                        .unwrap_or(0),
                )?;
                let max = usize::try_from(
                    declared
                        .pointer("/lines/maximum")
                        .and_then(Value::as_u64)
                        .unwrap_or(0),
                )?;
                ensure!(
                    (min..=max).contains(actual),
                    "{}: paragraph {} must use {min}–{max} lines, found {actual}",
                    spec.name,
                    index + 1
                );
            }
            let body = counts.get("cl-body").copied().unwrap_or_default();
            ensure!(
                (25..=28).contains(&body),
                "{}: expected 25–28 body lines, found {body}",
                spec.name
            );
            ensure!(
                counts.get("cl-highlight") == Some(&5),
                "{}: expected five one-line highlights",
                spec.name
            );
            ensure!(
                counts.get("cl-vertical-gap") == Some(&1)
                    && counts.get("cl-highlight-center") == Some(&1),
                "{}: expected one vertical-gap and one highlight-position metric",
                spec.name
            );
            ensure!(
                metrics.len() == body + 7,
                "{}: unexpected cover-letter metric set",
                spec.name
            );
        }
    }
    Ok(())
}

fn paragraph_pattern() -> &'static regex::Regex {
    static PATTERN: OnceLock<regex::Regex> = OnceLock::new();
    PATTERN.get_or_init(|| {
        regex::Regex::new(r"^cl\.paragraph\.(\d+)\.(\d+)$").expect("fixed metric id pattern")
    })
}

fn paragraph_counts(spec: &DocumentSpec, metrics: &[Value]) -> Result<Vec<usize>> {
    let pattern = paragraph_pattern();
    let mut counts = vec![0; 6];
    for metric in metrics
        .iter()
        .filter(|metric| metric.get("kind").and_then(Value::as_str) == Some("cl-body"))
    {
        let id = string_field(metric, "id")?;
        let captures = pattern
            .captures(id)
            .with_context(|| format!("{}: malformed cover-letter body metric id", spec.name))?;
        let paragraph = captures[1].parse::<usize>()?;
        ensure!(
            (1..=6).contains(&paragraph),
            "{}: metric references an unknown paragraph",
            spec.name
        );
        counts[paragraph - 1] += 1;
    }
    Ok(counts)
}

/// Accepted-but-dispreferred line totals per cover-letter region. Spelled out
/// as warnings rather than failures; the fused check gate calls this for its
/// error propagation even when it discards the advisories.
pub fn preference_warnings(
    workspace: &Workspace,
    spec: &DocumentSpec,
    metrics: &[Value],
) -> Result<Vec<String>> {
    if spec.kind != DocumentKind::CoverLetter {
        return Ok(Vec::new());
    }
    let counts = paragraph_counts(spec, metrics)?;
    let contract = workspace.read_json("ccvl.json")?;
    let contract = contract
        .pointer("/documents/cover_letter")
        .context("missing cover-letter contract")?;
    let mut warnings = Vec::new();
    for region in contract
        .get("paragraph_regions")
        .and_then(Value::as_array)
        .context("missing paragraph regions")?
    {
        let numbers = region
            .get("paragraphs")
            .and_then(Value::as_array)
            .context("missing region paragraphs")?
            .iter()
            .filter_map(Value::as_u64)
            .map(usize::try_from)
            .collect::<std::result::Result<Vec<_>, _>>()?;
        let total = numbers
            .iter()
            .map(|number| counts[number - 1])
            .sum::<usize>();
        let preferred = region
            .get("preferred_totals")
            .and_then(Value::as_array)
            .context("missing preferred totals")?
            .iter()
            .filter_map(Value::as_u64)
            .map(usize::try_from)
            .collect::<std::result::Result<Vec<_>, _>>()?;
        if !preferred.contains(&total) {
            warnings.push(format!(
                "{}: paragraphs {}–{} use {total} lines; accepted, but {} is preferred",
                spec.name,
                numbers[0],
                numbers[numbers.len() - 1],
                preferred
                    .iter()
                    .map(ToString::to_string)
                    .collect::<Vec<_>>()
                    .join(" or ")
            ));
        }
    }
    if counts[5] != 3 {
        warnings.push(format!(
            "{}: paragraph 6 uses {} lines; accepted, but 3 is preferred to mirror paragraph 1",
            spec.name, counts[5]
        ));
    }
    Ok(warnings)
}

fn string_field<'a>(value: &'a Value, field: &str) -> Result<&'a str> {
    value
        .get(field)
        .and_then(Value::as_str)
        .with_context(|| format!("metric has no {field}"))
}

fn number_field(value: &Value, field: &str) -> Result<f64> {
    value
        .get(field)
        .and_then(Value::as_f64)
        .with_context(|| format!("metric has no numeric {field}"))
}

fn compact_text(value: &Value) -> String {
    let text = value
        .as_str()
        .map_or_else(|| value.to_string(), str::to_owned);
    let compact = text.split_whitespace().collect::<Vec<_>>().join(" ");
    if compact.chars().count() <= 120 {
        compact
    } else {
        format!("{}…", compact.chars().take(119).collect::<String>())
    }
}

#[cfg(test)]
mod tests {
    use std::path::{Path, PathBuf};

    use serde_json::json;

    use super::*;

    fn workspace() -> Workspace {
        Workspace::at(Path::new(env!("CARGO_MANIFEST_DIR"))).unwrap()
    }

    fn cover_letter_spec() -> DocumentSpec {
        DocumentSpec {
            name: "fixture".to_owned(),
            kind: DocumentKind::CoverLetter,
            source: PathBuf::from("fixture.typ"),
            output: PathBuf::from("fixture.pdf"),
            inputs: std::collections::BTreeMap::new(),
            expected_pages: 1,
        }
    }

    fn metric(kind: &str, identifier: &str) -> Value {
        json!({"kind": kind, "id": identifier})
    }

    fn metric_set(paragraph_lengths: &[usize]) -> Vec<Value> {
        let mut metrics = paragraph_lengths
            .iter()
            .enumerate()
            .flat_map(|(paragraph, length)| {
                (1..=*length).map(move |line| {
                    metric("cl-body", &format!("cl.paragraph.{}.{line}", paragraph + 1))
                })
            })
            .collect::<Vec<_>>();
        metrics
            .extend((1..=5).map(|index| metric("cl-highlight", &format!("cl.highlight.{index}"))));
        metrics.push(metric("cl-vertical-gap", "cl.vertical-gap"));
        metrics.push(metric("cl-highlight-center", "cl.highlight-center"));
        metrics
    }

    #[test]
    fn underfill_and_overflow_are_both_failures_for_any_unit() {
        let base = json!({"min_fill": 60, "target_fill": 80, "max_fill": 95});
        let mut metric = base.clone();
        metric["actual_fill"] = json!(59.9);
        assert_eq!(violation(&metric).unwrap(), Some("too short"));
        metric["actual_fill"] = json!(80.0);
        assert_eq!(violation(&metric).unwrap(), None);
        metric["actual_fill"] = json!(95.1);
        assert_eq!(violation(&metric).unwrap(), Some("too long"));

        metric["unit"] = json!("pt");
        metric["min_fill"] = json!(12);
        metric["target_fill"] = json!(20);
        metric["max_fill"] = json!(30);
        metric["actual_fill"] = json!(11.9);
        assert_eq!(violation(&metric).unwrap(), Some("too short"));
        metric["actual_fill"] = json!(24.1);
        assert_eq!(violation(&metric).unwrap(), None);
        metric["actual_fill"] = json!(30.1);
        assert_eq!(violation(&metric).unwrap(), Some("too long"));
    }

    #[test]
    fn cover_letter_metric_set_requires_structure_and_layout_metrics() {
        let workspace = workspace();
        let spec = cover_letter_spec();
        let complete = metric_set(&[3, 6, 6, 5, 5, 3]);
        validate_metric_set(&workspace, &spec, &complete).unwrap();
        assert!(
            preference_warnings(&workspace, &spec, &complete)
                .unwrap()
                .is_empty()
        );

        let dispreferred = metric_set(&[3, 5, 6, 5, 5, 3]);
        validate_metric_set(&workspace, &spec, &dispreferred).unwrap();
        let warnings = preference_warnings(&workspace, &spec, &dispreferred).unwrap();
        assert_eq!(warnings.len(), 1);
        assert!(warnings[0].contains("paragraphs 2–3 use 11 lines"));

        let shorter_close = metric_set(&[3, 5, 5, 5, 5, 2]);
        validate_metric_set(&workspace, &spec, &shorter_close).unwrap();
        assert_eq!(
            preference_warnings(&workspace, &spec, &shorter_close).unwrap(),
            [
                "fixture: paragraph 6 uses 2 lines; accepted, but 3 is preferred to mirror paragraph 1"
            ]
        );

        for missing_kind in ["cl-vertical-gap", "cl-highlight-center"] {
            let incomplete = complete
                .iter()
                .filter(|item| item["kind"].as_str() != Some(missing_kind))
                .cloned()
                .collect::<Vec<_>>();
            let error = validate_metric_set(&workspace, &spec, &incomplete)
                .unwrap_err()
                .to_string();
            assert!(error.contains("vertical-gap and one highlight-position"));
        }
    }
}
