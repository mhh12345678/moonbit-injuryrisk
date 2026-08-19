///|
/// Data lifecycle utilities for normalized, exportable telemetry stores.
pub(all) struct LifecyclePolicy {
  retain_days : Int
  minimum_quality : Double
  fill_missing : Bool
  deduplicate : Bool
  sort_dates : Bool
  redact_notes : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct LifecycleResult {
  original_count : Int
  retained_count : Int
  removed_count : Int
  filled_count : Int
  duplicate_count : Int
  quality_before : Double
  quality_after : Double
  records : Array[DailyRecord]
  status : String
} derive(Debug, Eq, ToJson)

///|
pub fn default_lifecycle_policy() -> LifecyclePolicy {
  {
    retain_days: 365,
    minimum_quality: 80.0,
    fill_missing: false,
    deduplicate: true,
    sort_dates: true,
    redact_notes: false,
  }
}

///|
fn redact_record(record : DailyRecord, redact : Bool) -> DailyRecord {
  if !redact {
    record
  } else {
    {
      date: record.date,
      training_duration: record.training_duration,
      training_intensity: record.training_intensity,
      pain_level: record.pain_level,
      pain_site: None,
      sleep_hours: record.sleep_hours,
      sleep_quality: record.sleep_quality,
      fatigue: record.fatigue,
    }
  }
}

///|
fn lifecycle_date_limit(
  records : Array[DailyRecord],
  retain_days : Int,
) -> String? {
  if records.length() == 0 || retain_days <= 0 {
    None
  } else {
    let sorted = sort_records_by_date(records)
    match parse_date(sorted[sorted.length() - 1].date) {
      Some(date) =>
        match add_days(date, -retain_days + 1) {
          Some(value) => Some(format_date(value))
          None => None
        }
      None => None
    }
  }
}

///|
fn lifecycle_in_retention(record : DailyRecord, limit : String?) -> Bool {
  match limit {
    None => true
    Some(limit) =>
      match (parse_date(record.date), parse_date(limit)) {
        (Some(date), Some(limit)) =>
          compare_dates(date, limit) is After || date == limit
        _ => false
      }
  }
}

///|
pub fn apply_lifecycle(
  records : Array[DailyRecord],
  policy : LifecyclePolicy,
) -> LifecycleResult {
  let before = validate_records(records, default_quality_policy())
  let limit = lifecycle_date_limit(records, policy.retain_days)
  let selected = records
    .filter(record => lifecycle_in_retention(record, limit))
    .map(record => redact_record(record, policy.redact_notes))
  let deduped = if policy.deduplicate {
    normalize_records(selected)
  } else {
    selected
  }
  let filled = if policy.fill_missing {
    fill_missing_records(deduped, 8.0)
  } else {
    deduped
  }
  let output = if policy.sort_dates {
    sort_records_by_date(filled)
  } else {
    filled
  }
  let after = validate_records(output, default_quality_policy())
  let status = if after.blocking_issue_count > 0 {
    "blocked"
  } else if after.score < policy.minimum_quality {
    "review"
  } else {
    "ready"
  }
  {
    original_count: records.length(),
    retained_count: output.length(),
    removed_count: (records.length() - output.length()).max(0),
    filled_count: (output.length() - deduped.length()).max(0),
    duplicate_count: duplicate_date_indices(records).length(),
    quality_before: before.score,
    quality_after: after.score,
    records: output,
    status,
  }
}

///|
pub fn lifecycle_retained(
  records : Array[DailyRecord],
  policy : LifecyclePolicy,
) -> Array[DailyRecord] {
  apply_lifecycle(records, policy).records
}

///|
pub fn lifecycle_is_ready(result : LifecycleResult) -> Bool {
  result.status == "ready"
}

///|
pub fn lifecycle_quality_change(result : LifecycleResult) -> Double {
  result.quality_after - result.quality_before
}

///|
pub fn lifecycle_coverage(result : LifecycleResult) -> Double {
  completeness_ratio(result.records)
}

///|
pub fn lifecycle_date_span(result : LifecycleResult) -> Int {
  if result.records.length() == 0 {
    0
  } else {
    let sorted = sort_records_by_date(result.records)
    match
      (parse_date(sorted[0].date), parse_date(sorted[sorted.length() - 1].date)) {
      (Some(first), Some(last)) => days_between(first, last) + 1
      _ => 0
    }
  }
}

///|
pub fn lifecycle_next_action(result : LifecycleResult) -> String {
  if result.status == "blocked" {
    "repair blocking records"
  } else if result.status == "review" {
    "review retained data quality"
  } else if result.filled_count > 0 {
    "annotate filled records before downstream export"
  } else {
    "continue with retained records"
  }
}

///|
pub fn lifecycle_summary_text(result : LifecycleResult) -> String {
  "status=" +
  result.status +
  " original=" +
  result.original_count.to_string() +
  " retained=" +
  result.retained_count.to_string() +
  " removed=" +
  result.removed_count.to_string() +
  " filled=" +
  result.filled_count.to_string() +
  " quality_before=" +
  result.quality_before.to_string() +
  " quality_after=" +
  result.quality_after.to_string() +
  " coverage=" +
  lifecycle_coverage(result).to_string() +
  " action=" +
  lifecycle_next_action(result)
}

///|
pub fn lifecycle_policy_valid(policy : LifecyclePolicy) -> Bool {
  policy.retain_days > 0 &&
  policy.minimum_quality >= 0.0 &&
  policy.minimum_quality <= 100.0
}

///|
pub fn lifecycle_result_valid(result : LifecycleResult) -> Bool {
  result.original_count >= 0 &&
  result.retained_count >= 0 &&
  result.removed_count >= 0 &&
  result.filled_count >= 0 &&
  result.quality_before >= 0.0 &&
  result.quality_before <= 100.0 &&
  result.quality_after >= 0.0 &&
  result.quality_after <= 100.0
}
