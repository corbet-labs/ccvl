use std::path::Path;

use anyhow::{Context, Result, bail};
use regex::Regex;
use serde_json::Value;

use crate::workspace::read_json;

pub fn validate_json_file(path: &Path, schema_path: &Path) -> Result<Value> {
    let schema = read_json(schema_path)?;
    let value = read_json(path)?;
    validate_schema(&value, &schema, &schema, &path.display().to_string())?;
    Ok(value)
}

pub fn validate_schema(value: &Value, schema: &Value, root: &Value, location: &str) -> Result<()> {
    let object = schema
        .as_object()
        .with_context(|| format!("{location}: schema node is not an object"))?;
    if let Some(reference) = object.get("$ref").and_then(Value::as_str) {
        let resolved = resolve_ref(root, reference)?;
        return validate_schema(value, resolved, root, location);
    }
    if let Some(expected) = object.get("const")
        && value != expected
    {
        bail!("{location}: expected constant {expected}");
    }
    if let Some(values) = object.get("enum").and_then(Value::as_array)
        && !values.contains(value)
    {
        bail!("{location}: {value} is not in {values:?}");
    }
    if let Some(types) = object.get("type") {
        let matches = match types {
            Value::String(expected) => value_has_type(value, expected)?,
            Value::Array(expected) => expected.iter().any(|item| {
                item.as_str()
                    .is_some_and(|name| value_has_type(value, name).unwrap_or(false))
            }),
            _ => false,
        };
        if !matches {
            bail!("{location}: value has the wrong JSON type");
        }
    }

    if let Some(map) = value.as_object() {
        if let Some(required) = object.get("required").and_then(Value::as_array) {
            let missing = required
                .iter()
                .filter_map(Value::as_str)
                .filter(|field| !map.contains_key(*field))
                .collect::<Vec<_>>();
            if !missing.is_empty() {
                bail!("{location}: missing required fields {}", missing.join(", "));
            }
        }
        let properties = object.get("properties").and_then(Value::as_object);
        if object.get("additionalProperties") == Some(&Value::Bool(false)) {
            let unknown = map
                .keys()
                .filter(|key| properties.is_none_or(|items| !items.contains_key(*key)))
                .collect::<Vec<_>>();
            if !unknown.is_empty() {
                bail!(
                    "{location}: unknown fields {}",
                    unknown.into_iter().cloned().collect::<Vec<_>>().join(", ")
                );
            }
        }
        if let Some(properties) = properties {
            for (key, child) in map {
                if let Some(child_schema) = properties.get(key) {
                    validate_schema(child, child_schema, root, &format!("{location}.{key}"))?;
                }
            }
        }
    }

    if let Some(items) = value.as_array() {
        let minimum = usize::try_from(object.get("minItems").and_then(Value::as_u64).unwrap_or(0))?;
        if items.len() < minimum {
            bail!("{location}: too few items");
        }
        if let Some(maximum) = object.get("maxItems").and_then(Value::as_u64)
            && items.len() > usize::try_from(maximum)?
        {
            bail!("{location}: too many items");
        }
        if let Some(item_schema) = object.get("items") {
            for (index, child) in items.iter().enumerate() {
                validate_schema(child, item_schema, root, &format!("{location}[{index}]"))?;
            }
        }
    }

    if let Some(number) = value.as_i64() {
        if let Some(minimum) = object.get("minimum").and_then(Value::as_i64)
            && number < minimum
        {
            bail!("{location}: value is below minimum {minimum}");
        }
        if let Some(maximum) = object.get("maximum").and_then(Value::as_i64)
            && number > maximum
        {
            bail!("{location}: value is above maximum {maximum}");
        }
    }
    if let Some(text) = value.as_str()
        && let Some(pattern) = object.get("pattern").and_then(Value::as_str)
    {
        let anchored = format!("^(?:{pattern})$");
        if !Regex::new(&anchored)
            .with_context(|| format!("unsupported schema pattern {pattern:?}"))?
            .is_match(text)
        {
            bail!("{location}: value does not match {pattern:?}");
        }
    }
    Ok(())
}

fn value_has_type(value: &Value, expected: &str) -> Result<bool> {
    Ok(match expected {
        "array" => value.is_array(),
        "boolean" => value.is_boolean(),
        "integer" => value.as_i64().is_some() || value.as_u64().is_some(),
        "null" => value.is_null(),
        "object" => value.is_object(),
        "string" => value.is_string(),
        other => bail!("validator does not support JSON Schema type {other:?}"),
    })
}

fn resolve_ref<'a>(root: &'a Value, reference: &str) -> Result<&'a Value> {
    let pointer = reference
        .strip_prefix('#')
        .with_context(|| format!("only local schema references are supported: {reference}"))?;
    root.pointer(pointer)
        .with_context(|| format!("unresolved schema reference: {reference}"))
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

    fn schema() -> Value {
        json!({
            "type": "object",
            "additionalProperties": false,
            "required": ["name", "count", "values", "state"],
            "properties": {
                "name": {"type": "string", "pattern": "^[a-z-]+$"},
                "count": {"type": "integer", "minimum": 1, "maximum": 3},
                "values": {
                    "type": "array",
                    "minItems": 1,
                    "maxItems": 2,
                    "items": {"$ref": "#/$defs/value"}
                },
                "state": {"enum": ["ready", "blocked"]},
                "empty": {"const": null}
            },
            "$defs": {"value": {"type": ["string", "null"]}}
        })
    }

    fn assert_invalid(value: &Value) {
        let schema = schema();
        assert!(validate_schema(value, &schema, &schema, "fixture").is_err());
    }

    #[test]
    fn valid_nested_document_and_local_reference_are_accepted() {
        let schema = schema();
        validate_schema(
            &json!({
                "name": "valid-name",
                "count": 1,
                "values": ["one", null],
                "state": "ready",
                "empty": null
            }),
            &schema,
            &schema,
            "fixture",
        )
        .unwrap();
    }

    #[test]
    fn required_and_additional_properties_are_enforced() {
        assert_invalid(&json!({"name": "valid", "count": 1, "values": ["one"]}));
        assert_invalid(&json!({
            "name": "valid", "count": 1, "values": ["one"], "state": "ready", "other": 1
        }));
    }

    #[test]
    fn booleans_and_integers_remain_distinct_json_types() {
        assert_invalid(&json!({
            "name": "valid", "count": true, "values": ["one"], "state": "ready"
        }));
        let boolean = json!({"type": "boolean"});
        validate_schema(&json!(true), &boolean, &boolean, "fixture").unwrap();
        assert!(validate_schema(&json!(1), &boolean, &boolean, "fixture").is_err());
    }

    #[test]
    fn pattern_numeric_enum_and_array_bounds_are_enforced() {
        for document in [
            json!({"name": "NOT VALID", "count": 1, "values": ["one"], "state": "ready"}),
            json!({"name": "valid", "count": 0, "values": ["one"], "state": "ready"}),
            json!({"name": "valid", "count": 4, "values": ["one"], "state": "ready"}),
            json!({"name": "valid", "count": 1, "values": [], "state": "ready"}),
            json!({"name": "valid", "count": 1, "values": ["one", "two", "three"], "state": "ready"}),
            json!({"name": "valid", "count": 1, "values": ["one"], "state": "unknown"}),
        ] {
            assert_invalid(&document);
        }
    }
}
