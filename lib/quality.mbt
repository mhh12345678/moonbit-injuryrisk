///|
/// The category of a data-quality finding.
pub(all) enum QualityIssueKind {
  InvalidDate
  DuplicateDate
  NegativeValue
  OutOfRange
  MissingDate
  UnorderedDate
  EmptyRecordSet
} derive(Debug, Eq, ToJson)

///|
pub(all) struct QualityIssue {
  kind : QualityIssueKind
  index : Int
  date : String
  field : String
  message : String
  blocking : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct QualityReport {
  record_count : Int
  valid_record_count : Int
  issue_count : Int
  blocking_issue_count : Int
  missing_date_count : Int
  duplicate_date_count : Int
  score : Double
  issues : Array[QualityIssue]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct QualityPolicy {
  require_iso_date : Bool
  require_non_negative_load : Bool
  maximum_intensity : Double
  maximum_pain : Double
  maximum_sleep_hours : Double
  maximum_sleep_quality : Double
  maximum_fatigue : Double
} derive(Debug, Eq, ToJson)

///|
pub fn default_quality_policy() -> QualityPolicy {
  {
    require_iso_date: true,
    require_non_negative_load: true,
    maximum_intensity: 10.0,
    maximum_pain: 10.0,
    maximum_sleep_hours: 24.0,
    maximum_sleep_quality: 5.0,
    maximum_fatigue: 10.0,
  }
}

///|
fn issue(
  kind : QualityIssueKind,
  index : Int,
  date : String,
  field : String,
  message : String,
  blocking : Bool,
) -> QualityIssue {
  { kind, index, date, field, message, blocking }
}

///|
pub fn validate_record(
  record : DailyRecord,
  index : Int,
  policy : QualityPolicy,
) -> Array[QualityIssue] {
  let issues = []
  if policy.require_iso_date && parse_date(record.date) is None {
    issues.push(
      issue(
        InvalidDate,
        index,
        record.date,
        "date",
        "date must use a valid YYYY-MM-DD value",
        true,
      ),
    )
  }
  if policy.require_non_negative_load && record.training_duration < 0.0 {
    issues.push(
      issue(
        NegativeValue,
        index,
        record.date,
        "training_duration",
        "training duration cannot be negative",
        true,
      ),
    )
  }
  if policy.require_non_negative_load && record.training_intensity < 0.0 {
    issues.push(
      issue(
        NegativeValue,
        index,
        record.date,
        "training_intensity",
        "training intensity cannot be negative",
        true,
      ),
    )
  }
  if record.training_intensity > policy.maximum_intensity {
    issues.push(
      issue(
        OutOfRange,
        index,
        record.date,
        "training_intensity",
        "training intensity exceeds the configured scale",
        true,
      ),
    )
  }
  if record.pain_level < 0.0 || record.pain_level > policy.maximum_pain {
    issues.push(
      issue(
        OutOfRange,
        index,
        record.date,
        "pain_level",
        "pain level is outside the configured scale",
        true,
      ),
    )
  }
  if record.sleep_hours < 0.0 || record.sleep_hours > policy.maximum_sleep_hours {
    issues.push(
      issue(
        OutOfRange,
        index,
        record.date,
        "sleep_hours",
        "sleep duration is outside the configured range",
        true,
      ),
    )
  }
  if record.sleep_quality < 0.0 ||
    record.sleep_quality > policy.maximum_sleep_quality {
    issues.push(
      issue(
        OutOfRange,
        index,
        record.date,
        "sleep_quality",
        "sleep quality is outside the configured range",
        true,
      ),
    )
  }
  if record.fatigue < 0.0 || record.fatigue > policy.maximum_fatigue {
    issues.push(
      issue(
        OutOfRange,
        index,
        record.date,
        "fatigue",
        "fatigue is outside the configured range",
        true,
      ),
    )
  }
  if record.training_duration.is_nan() ||
    record.training_intensity.is_nan() ||
    record.pain_level.is_nan() ||
    record.sleep_hours.is_nan() ||
    record.sleep_quality.is_nan() ||
    record.fatigue.is_nan() {
    issues.push(
      issue(
        OutOfRange,
        index,
        record.date,
        "numeric_value",
        "numeric telemetry values cannot be NaN",
        true,
      ),
    )
  }
  issues
}

///|
pub fn validate_records(
  records : Array[DailyRecord],
  policy : QualityPolicy,
) -> QualityReport {
  let issues = []
  let valid = Array::new(capacity=records.length())
  for index, record in records {
    let record_issues = validate_record(record, index, policy)
    if record_issues.length() == 0 {
      valid.push(record)
    }
    for item in record_issues {
      issues.push(item)
    }
  }
  let duplicates = duplicate_date_indices(records)
  for index in duplicates {
    issues.push(
      issue(
        DuplicateDate,
        index,
        records[index].date,
        "date",
        "date occurs more than once",
        false,
      ),
    )
  }
  let missing = missing_dates(records)
  for date in missing {
    issues.push(
      issue(
        MissingDate,
        -1,
        date,
        "date",
        "date is missing from an otherwise continuous interval",
        false,
      ),
    )
  }
  let blocking = issues.filter(item => item.blocking).length()
  let base = records.length() * 2 + 1
  let penalty = issues.length().to_double() * 100.0 / base.to_double()
  {
    record_count: records.length(),
    valid_record_count: valid.length(),
    issue_count: issues.length(),
    blocking_issue_count: blocking,
    missing_date_count: missing.length(),
    duplicate_date_count: duplicates.length(),
    score: if records.length() == 0 {
      0.0
    } else {
      (100.0 - penalty).max(0.0)
    },
    issues,
  }
}

///|
pub fn quality_band(score : Double) -> String {
  if score >= 95.0 {
    "excellent"
  } else if score >= 80.0 {
    "good"
  } else if score >= 60.0 {
    "review"
  } else {
    "poor"
  }
}

///|
pub fn has_blocking_quality_issue(report : QualityReport) -> Bool {
  report.blocking_issue_count > 0
}

///|
pub fn normalize_records(records : Array[DailyRecord]) -> Array[DailyRecord] {
  let sorted = sort_records_by_date(records)
  let normalized = []
  let seen : Map[String, Bool] = Map([])
  for record in sorted {
    if !seen.contains(record.date) {
      seen[record.date] = true
      normalized.push(record)
    }
  }
  normalized
}

///|
pub fn records_with_valid_dates(
  records : Array[DailyRecord],
) -> Array[DailyRecord] {
  records.filter(record => parse_date(record.date) is Some(_))
}

///|
pub fn records_in_date_range(
  records : Array[DailyRecord],
  range : DateRange,
) -> Array[DailyRecord] {
  records.filter(record => {
    match parse_date(record.date) {
      Some(date) => date_is_in_range(date, range)
      None => false
    }
  })
}

///|
pub fn fill_missing_records(
  records : Array[DailyRecord],
  target_sleep : Double,
) -> Array[DailyRecord] {
  let normalized = normalize_records(records)
  if normalized.length() == 0 {
    return []
  }
  let first = parse_date(normalized[0].date)
  let last = parse_date(normalized[normalized.length() - 1].date)
  let filled = []
  match (first, last) {
    (Some(first), Some(last)) =>
      for date in dates_in_range({ start: first, end: last }) {
        let formatted = format_date(date)
        let existing = normalized.filter(record => record.date == formatted)
        if existing.length() > 0 {
          filled.push(existing[0])
        } else {
          filled.push({
            date: formatted,
            training_duration: 0.0,
            training_intensity: 0.0,
            pain_level: 0.0,
            pain_site: None,
            sleep_hours: target_sleep,
            sleep_quality: 0.0,
            fatigue: 0.0,
          })
        }
      }
    _ => ()
  }
  filled
}

///|
pub fn invalid_record_indices(
  records : Array[DailyRecord],
  policy : QualityPolicy,
) -> Array[Int] {
  let indices = []
  for index, record in records {
    if validate_record(record, index, policy).length() > 0 {
      indices.push(index)
    }
  }
  indices
}

///|
pub fn completeness_ratio(records : Array[DailyRecord]) -> Double {
  if records.length() == 0 {
    0.0
  } else {
    let missing = missing_dates(records).length()
    let expected = records.length() + missing
    if expected == 0 {
      0.0
    } else {
      records.length().to_double() / expected.to_double()
    }
  }
}

///|
pub fn date_order_issues(records : Array[DailyRecord]) -> Array[QualityIssue] {
  let issues = []
  for i in 1..<records.length() {
    let previous = parse_date(records[i - 1].date)
    let current = parse_date(records[i].date)
    if previous is Some(previous) &&
      current is Some(current) &&
      compare_dates(previous, current) is After {
      issues.push(
        issue(
          UnorderedDate,
          i,
          records[i].date,
          "date",
          "records are not in chronological order",
          false,
        ),
      )
    }
  }
  issues
}

///|
pub fn quality_report_text(report : QualityReport) -> String {
  let builder = StringBuilder()
  builder.write_string("quality=")
  builder.write_string(quality_band(report.score))
  builder.write_string(" score=")
  builder.write_string(report.score.to_string())
  builder.write_string(" records=")
  builder.write_string(report.record_count.to_string())
  builder.write_string(" issues=")
  builder.write_string(report.issue_count.to_string())
  builder.write_string(" blocking=")
  builder.write_string(report.blocking_issue_count.to_string())
  builder.to_string()
}
