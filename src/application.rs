use anyhow::{Context, Result, bail, ensure};
use serde_json::{Map, Value};

use crate::schema::validate_json_file;
use crate::workspace::Workspace;

pub fn validate_all(workspace: &Workspace) -> Result<()> {
    let schema = workspace.path("schemas/application.schema.json");
    let mut candidates = vec![
        workspace.path("templates/application.json"),
        workspace.path("cvl/general/de-ch/application.json"),
        workspace.path("cvl/general/en-ch/application.json"),
    ];
    let opportunities = workspace.path("opportunities");
    if opportunities.is_dir() {
        for organisation in std::fs::read_dir(&opportunities)? {
            let organisation = organisation?;
            if !organisation.file_type()?.is_dir() {
                continue;
            }
            for position in std::fs::read_dir(organisation.path())? {
                let position = position?;
                let record = position.path().join("application.json");
                if record.is_file() {
                    candidates.push(record);
                }
            }
        }
    }
    candidates.sort();
    for path in candidates {
        let application = validate_json_file(&path, &schema)?;
        let template = path == workspace.path("templates/application.json");
        validate_line_contracts(
            workspace,
            &application,
            &workspace.relative(&path)?.display().to_string(),
            !template,
        )?;
        let relative = workspace.relative(&path)?;
        let parts = relative
            .components()
            .map(|item| item.as_os_str().to_string_lossy())
            .collect::<Vec<_>>();
        if parts.windows(2).any(|pair| pair == ["general", "de-ch"])
            && application.pointer("/job/language").and_then(Value::as_str) != Some("de-CH")
        {
            bail!("{}: expected de-CH language", relative.display());
        }
        if parts.windows(2).any(|pair| pair == ["general", "en-ch"])
            && application.pointer("/job/language").and_then(Value::as_str) != Some("en-CH")
        {
            bail!("{}: expected en-CH language", relative.display());
        }
    }
    Ok(())
}

pub fn validate_profiles(workspace: &Workspace) -> Result<()> {
    let schema = workspace.path("schemas/profile.schema.json");
    validate_json_file(&workspace.path("templates/profile.json"), &schema)?;
    validate_json_file(&workspace.path("cvl/general/profile.json"), &schema)?;
    Ok(())
}

pub fn validate_station_files(workspace: &Workspace) -> Result<()> {
    let schema = workspace.path("schemas/stations.schema.json");
    validate_json_file(&workspace.path("templates/stations.json"), &schema)?;
    validate_json_file(&workspace.path("cvl/general/stations.json"), &schema)?;
    Ok(())
}

pub fn validate_line_contracts(
    workspace: &Workspace,
    application: &Value,
    location: &str,
    require_text: bool,
) -> Result<()> {
    let pages = application
        .pointer("/tailored_cv/pages")
        .and_then(Value::as_u64)
        .context("tailored_cv.pages is missing")?;
    ensure!(
        [2, 3, 4].contains(&pages),
        "{location}.tailored_cv.pages: expected 2, 3, or 4"
    );
    let summary = array_at(application, "/tailored_cv/summary")?;
    ensure!(
        summary.len() == 5,
        "{location}.tailored_cv.summary: expected exactly five lines"
    );
    for (index, line) in summary.iter().enumerate() {
        validate_line(
            line,
            &format!("{location}.tailored_cv.summary[{}]", index + 1),
            require_text,
        )?;
    }

    let cover = object_at(application, "/tailored_cl")?;
    let enabled = cover
        .get("enabled")
        .and_then(Value::as_bool)
        .context("tailored_cl.enabled is not a boolean")?;
    if !enabled {
        ensure!(
            cover.len() == 1,
            "{location}.tailored_cl: a disabled cover letter may not retain hidden content"
        );
        return Ok(());
    }
    ensure!(
        cover.len() == 3 && cover.contains_key("paragraphs") && cover.contains_key("highlights"),
        "{location}.tailored_cl: an enabled cover letter requires paragraphs and highlights"
    );

    let contract = workspace.read_json("ccvl.json")?;
    let cl_contract = contract
        .pointer("/documents/cover_letter")
        .context("ccvl.json has no cover-letter contract")?;
    let paragraph_contracts = array_at(cl_contract, "/paragraphs")?;
    let paragraphs = cover
        .get("paragraphs")
        .and_then(Value::as_array)
        .context("tailored_cl.paragraphs is not an array")?;
    ensure!(
        paragraphs.len() == paragraph_contracts.len(),
        "{location}.tailored_cl.paragraphs: expected {} paragraphs, found {}",
        paragraph_contracts.len(),
        paragraphs.len()
    );

    let body_floor = cl_contract
        .pointer("/line_fill/body")
        .context("missing body line-fill contract")?;
    let mut counts = Vec::with_capacity(paragraphs.len());
    for (index, (paragraph, paragraph_contract)) in
        paragraphs.iter().zip(paragraph_contracts).enumerate()
    {
        let lines = array_at(paragraph, "/lines")?;
        let bounds = paragraph_contract
            .get("lines")
            .context("missing paragraph bounds")?;
        let minimum = usize::try_from(u64_at(bounds, "/minimum")?)?;
        let maximum = usize::try_from(u64_at(bounds, "/maximum")?)?;
        ensure!(
            (minimum..=maximum).contains(&lines.len()),
            "{location}.tailored_cl.paragraphs[{}]: expected {minimum}–{maximum} lines, found {}",
            index + 1,
            lines.len()
        );
        counts.push(lines.len());
        for (line_index, line) in lines.iter().enumerate() {
            let line_location = format!(
                "{location}.tailored_cl.paragraphs[{}].lines[{}]",
                index + 1,
                line_index + 1
            );
            validate_line(line, &line_location, require_text)?;
            validate_floor(line, body_floor, &line_location)?;
        }
    }
    let total = counts.iter().sum::<usize>();
    validate_count(
        total,
        cl_contract
            .pointer("/body_lines")
            .context("missing body line contract")?,
        &format!("{location}.tailored_cl.paragraphs"),
        "body lines",
    )?;
    for region in array_at(cl_contract, "/paragraph_regions")? {
        let numbers = array_at(region, "/paragraphs")?
            .iter()
            .map(|value| value.as_u64().context("invalid paragraph number"))
            .collect::<Result<Vec<_>>>()?;
        let start =
            usize::try_from(numbers.first().copied().context("empty paragraph region")?)? - 1;
        let end = usize::try_from(numbers.last().copied().context("empty paragraph region")?)?;
        validate_count(
            counts[start..end].iter().sum(),
            region,
            &format!("{location}.tailored_cl.paragraphs[{}:{}]", start + 1, end),
            "shared lines",
        )?;
    }

    let highlights = cover
        .get("highlights")
        .and_then(Value::as_array)
        .context("tailored_cl.highlights is not an array")?;
    let expected = usize::try_from(u64_at(cl_contract, "/highlights/count")?)?;
    ensure!(
        highlights.len() == expected,
        "{location}.tailored_cl.highlights: expected {expected} items, found {}",
        highlights.len()
    );
    let highlight_floor = cl_contract
        .pointer("/line_fill/highlight")
        .context("missing highlight line-fill contract")?;
    for (index, line) in highlights.iter().enumerate() {
        let line_location = format!("{location}.tailored_cl.highlights[{}]", index + 1);
        validate_line(line, &line_location, require_text)?;
        validate_floor(line, highlight_floor, &line_location)?;
    }
    Ok(())
}

fn validate_line(line: &Value, location: &str, require_text: bool) -> Result<()> {
    let text = line
        .get("text")
        .and_then(Value::as_str)
        .context("line text is missing")?;
    ensure!(
        !require_text || !text.trim().is_empty(),
        "{location}.text: a rendered line cannot be empty"
    );
    let minimum = u64_at(line, "/min_fill")?;
    let target = u64_at(line, "/target_fill")?;
    let maximum = u64_at(line, "/max_fill")?;
    ensure!(
        minimum <= target && target <= maximum,
        "{location}: expected min_fill <= target_fill <= max_fill"
    );
    ensure!(
        minimum >= 1 && maximum <= 100,
        "{location}: fill bounds must remain within 1–100"
    );
    Ok(())
}

fn validate_floor(line: &Value, floor: &Value, location: &str) -> Result<()> {
    ensure!(
        u64_at(line, "/min_fill")? >= u64_at(floor, "/minimum")?
            && u64_at(line, "/target_fill")? >= u64_at(floor, "/target")?
            && u64_at(line, "/max_fill")? <= u64_at(floor, "/maximum")?,
        "{location}: line contract weakens the required fill floor or target"
    );
    Ok(())
}

fn validate_count(actual: usize, bounds: &Value, location: &str, label: &str) -> Result<()> {
    let minimum = usize::try_from(u64_at(bounds, "/minimum")?)?;
    let maximum = usize::try_from(u64_at(bounds, "/maximum")?)?;
    ensure!(
        (minimum..=maximum).contains(&actual),
        "{location}: expected {minimum}–{maximum} {label}, found {actual}"
    );
    Ok(())
}

pub(crate) fn array_at<'a>(value: &'a Value, pointer: &str) -> Result<&'a Vec<Value>> {
    value
        .pointer(pointer)
        .and_then(Value::as_array)
        .with_context(|| format!("missing array at {pointer}"))
}

pub(crate) fn object_at<'a>(value: &'a Value, pointer: &str) -> Result<&'a Map<String, Value>> {
    value
        .pointer(pointer)
        .and_then(Value::as_object)
        .with_context(|| format!("missing object at {pointer}"))
}

pub(crate) fn u64_at(value: &Value, pointer: &str) -> Result<u64> {
    value
        .pointer(pointer)
        .and_then(Value::as_u64)
        .with_context(|| format!("missing integer at {pointer}"))
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

    fn workspace() -> Workspace {
        Workspace::at(std::path::Path::new(env!("CARGO_MANIFEST_DIR"))).unwrap()
    }

    fn line() -> Value {
        json!({"text": "evidence", "min_fill": 75, "target_fill": 90, "max_fill": 100})
    }

    fn application(paragraph_lengths: &[usize]) -> Value {
        json!({
            "tailored_cv": {
                "pages": 4,
                "summary": (0..5).map(|_| line()).collect::<Vec<_>>()
            },
            "tailored_cl": {
                "enabled": true,
                "paragraphs": paragraph_lengths.iter().map(|length| json!({
                    "lines": (0..*length).map(|_| line()).collect::<Vec<_>>()
                })).collect::<Vec<_>>(),
                "highlights": (0..5).map(|_| {
                    json!({"text": "evidence", "min_fill": 60, "target_fill": 82, "max_fill": 100})
                }).collect::<Vec<_>>()
            }
        })
    }

    #[test]
    fn cv_only_application_is_valid_without_hidden_cover_letter_content() {
        let mut draft = application(&[3, 6, 6, 5, 5, 3]);
        draft["tailored_cl"] = json!({"enabled": false});
        validate_line_contracts(&workspace(), &draft, "fixture", true).unwrap();

        draft["tailored_cl"]["paragraphs"] = json!([]);
        let error = validate_line_contracts(&workspace(), &draft, "fixture", true)
            .unwrap_err()
            .to_string();
        assert!(error.contains("disabled cover letter"));
    }

    #[test]
    fn accepted_cover_letter_distributions_match_the_declared_regions() {
        let workspace = workspace();
        for lengths in [
            [3, 6, 6, 5, 5, 3],
            [3, 5, 7, 5, 5, 3],
            [3, 7, 5, 5, 5, 2],
            [3, 5, 5, 5, 5, 2],
            [3, 5, 6, 5, 5, 3],
        ] {
            validate_line_contracts(&workspace, &application(&lengths), "fixture", true).unwrap();
        }
    }

    #[test]
    fn fixed_individual_and_shared_line_budgets_are_enforced() {
        let workspace = workspace();
        for (lengths, expected) in [
            ([2, 6, 6, 5, 5, 3], "paragraphs[1]: expected 3–3 lines"),
            ([3, 4, 6, 5, 5, 3], "paragraphs[2]: expected 5–7 lines"),
            ([3, 6, 6, 5, 5, 4], "paragraphs[6]: expected 2–3 lines"),
            (
                [3, 5, 5, 6, 7, 2],
                "paragraphs[4:5]: expected 10–12 shared lines",
            ),
        ] {
            let error =
                validate_line_contracts(&workspace, &application(&lengths), "fixture", true)
                    .unwrap_err()
                    .to_string();
            assert!(error.contains(expected), "unexpected error: {error}");
        }
    }

    #[test]
    fn every_middle_paragraph_distribution_obeys_all_declared_bounds() {
        let workspace = workspace();
        for second in 4..=8 {
            for third in 4..=8 {
                for fourth in 4..=8 {
                    for fifth in 4..=8 {
                        let middle = [second, third, fourth, fifth];
                        let valid = middle.iter().all(|count| (5..=7).contains(count))
                            && (10..=12).contains(&(second + third))
                            && (10..=12).contains(&(fourth + fifth))
                            && (20..=22).contains(&middle.iter().sum::<usize>());
                        let lengths = [3, second, third, fourth, fifth, 3];
                        assert_eq!(
                            validate_line_contracts(
                                &workspace,
                                &application(&lengths),
                                "fixture",
                                true,
                            )
                            .is_ok(),
                            valid,
                            "unexpected result for {middle:?}"
                        );
                    }
                }
            }
        }
    }

    #[test]
    fn weakened_fill_floor_is_rejected() {
        let mut draft = application(&[3, 6, 6, 5, 5, 3]);
        draft["tailored_cl"]["paragraphs"][0]["lines"][0]["min_fill"] = json!(74);
        let error = validate_line_contracts(&workspace(), &draft, "fixture", true)
            .unwrap_err()
            .to_string();
        assert!(error.contains("weakens the required fill floor"));
    }

    #[test]
    fn fill_bounds_are_ordered() {
        let mut invalid = line();
        invalid["min_fill"] = json!(91);
        assert!(validate_line(&invalid, "fixture", true).is_err());
    }

    #[test]
    fn empty_rendered_lines_are_rejected() {
        let mut invalid = line();
        invalid["text"] = json!("  ");
        assert!(validate_line(&invalid, "fixture", true).is_err());
    }
}
