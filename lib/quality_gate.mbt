///|
/// Application-facing quality gates for deciding whether analysis may proceed.
pub(all) struct QualityGateConfig {
  minimum_score : Double
  maximum_blocking_issues : Int
  minimum_records : Int
  minimum_coverage : Double
  require_continuous_dates : Bool
  reject_duplicates : Bool
  reject_unordered : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct QualityGateCheck {
  name : String
  passed : Bool
  actual : Double
  expected : Double
  message : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct QualityGateResult {
  config : QualityGateConfig
  report : QualityReport
  checks : Array[QualityGateCheck]
  passed : Bool
  blocking_count : Int
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub fn default_quality_gate_config() -> QualityGateConfig {
  {
    minimum_score: 80.0,
    maximum_blocking_issues: 0,
    minimum_records: 7,
    minimum_coverage: 0.80,
    require_continuous_dates: false,
    reject_duplicates: true,
    reject_unordered: false,
  }
}

///|
fn gate_check(
  name : String,
  passed : Bool,
  actual : Double,
  expected : Double,
  message : String,
) -> QualityGateCheck {
  { name, passed, actual, expected, message }
}

///|
fn gate_recommendation(checks : Array[QualityGateCheck]) -> String {
  if checks.all(check => check.passed) {
    "analysis is permitted"
  } else if checks
    .filter(check => !check.passed)
    .any(check => check.name == "blocking_issues") {
    "repair blocking input values before analysis"
  } else if checks
    .filter(check => !check.passed)
    .any(check => check.name == "coverage") {
    "collect a longer continuous baseline"
  } else {
    "review data quality findings before using the output"
  }
}

///|
pub fn evaluate_quality_gate(
  records : Array[DailyRecord],
  config : QualityGateConfig,
) -> QualityGateResult {
  let report = validate_records(records, default_quality_policy())
  let order_issues = date_order_issues(records).length()
  let coverage = completeness_ratio(records)
  let checks = [
    gate_check(
      "minimum_records",
      records.length() >= config.minimum_records,
      records.length().to_double(),
      config.minimum_records.to_double(),
      "minimum history length",
    ),
    gate_check(
      "quality_score",
      report.score >= config.minimum_score,
      report.score,
      config.minimum_score,
      "quality score floor",
    ),
    gate_check(
      "blocking_issues",
      report.blocking_issue_count <= config.maximum_blocking_issues,
      report.blocking_issue_count.to_double(),
      config.maximum_blocking_issues.to_double(),
      "blocking issue limit",
    ),
    gate_check(
      "coverage",
      coverage >= config.minimum_coverage,
      coverage,
      config.minimum_coverage,
      "date coverage floor",
    ),
    gate_check(
      "duplicates",
      !config.reject_duplicates || report.duplicate_date_count == 0,
      report.duplicate_date_count.to_double(),
      0.0,
      "duplicate date rule",
    ),
    gate_check(
      "ordering",
      !config.reject_unordered || order_issues == 0,
      order_issues.to_double(),
      0.0,
      "chronological order rule",
    ),
    gate_check(
      "continuous_dates",
      !config.require_continuous_dates || report.missing_date_count == 0,
      report.missing_date_count.to_double(),
      0.0,
      "continuous date rule",
    ),
  ]
  let failed = checks.filter(check => !check.passed).length()
  {
    config,
    report,
    checks,
    passed: failed == 0,
    blocking_count: failed,
    recommendation: gate_recommendation(checks),
  }
}

///|
pub fn quality_gate_for_defaults(
  records : Array[DailyRecord],
) -> QualityGateResult {
  evaluate_quality_gate(records, default_quality_gate_config())
}

///|
pub fn quality_gate_failed_checks(
  result : QualityGateResult,
) -> Array[QualityGateCheck] {
  result.checks.filter(check => !check.passed)
}

///|
pub fn quality_gate_check(
  result : QualityGateResult,
  name : String,
) -> QualityGateCheck? {
  for check in result.checks {
    if check.name == name {
      return Some(check)
    }
  }
  None
}

///|
pub fn quality_gate_passes(result : QualityGateResult) -> Bool {
  result.passed
}

///|
pub fn quality_gate_allows_assessment(result : QualityGateResult) -> Bool {
  result.passed && result.report.blocking_issue_count == 0
}

///|
pub fn quality_gate_data_quality(result : QualityGateResult) -> String {
  quality_band(result.report.score)
}

///|
pub fn quality_gate_coverage(result : QualityGateResult) -> Double {
  completeness_ratio(
    result.report.issues
    .filter(issue => issue.kind != MissingDate)
    .map(issue => {
      date: issue.date,
      training_duration: 0.0,
      training_intensity: 0.0,
      pain_level: 0.0,
      pain_site: None,
      sleep_hours: 0.0,
      sleep_quality: 0.0,
      fatigue: 0.0,
    }),
  )
}

///|
pub fn quality_gate_issue_kinds(result : QualityGateResult) -> Array[String] {
  let names = []
  for issue in result.report.issues {
    let name = match issue.kind {
      InvalidDate => "invalid_date"
      DuplicateDate => "duplicate_date"
      NegativeValue => "negative_value"
      OutOfRange => "out_of_range"
      MissingDate => "missing_date"
      UnorderedDate => "unordered_date"
      EmptyRecordSet => "empty_record_set"
    }
    if !names.contains(name) {
      names.push(name)
    }
  }
  names
}

///|
pub fn quality_gate_repairable(result : QualityGateResult) -> Bool {
  result.report.blocking_issue_count == 0 && result.report.issue_count > 0
}

///|
pub fn quality_gate_repair(
  records : Array[DailyRecord],
  result : QualityGateResult,
) -> Array[DailyRecord] {
  if result.report.blocking_issue_count > 0 {
    []
  } else {
    normalize_records(fill_missing_records(records, 8.0))
  }
}

///|
pub fn quality_gate_after_repair(
  records : Array[DailyRecord],
  config : QualityGateConfig,
) -> QualityGateResult {
  evaluate_quality_gate(records, config)
}

///|
pub fn quality_gate_summary(result : QualityGateResult) -> String {
  "passed=" +
  result.passed.to_string() +
  " score=" +
  result.report.score.to_string() +
  " records=" +
  result.report.record_count.to_string() +
  " failed_checks=" +
  result.blocking_count.to_string() +
  " recommendation=" +
  result.recommendation
}

///|
pub fn quality_gate_text(result : QualityGateResult) -> String {
  let builder = StringBuilder::new()
  builder.write_string(quality_gate_summary(result))
  for check in result.checks {
    builder.write_string(
      "\n" +
      check.name +
      " passed=" +
      check.passed.to_string() +
      " actual=" +
      check.actual.to_string() +
      " expected=" +
      check.expected.to_string(),
    )
  }
  builder.to_string()
}

///|
pub fn quality_gate_csv_header() -> String {
  "name,passed,actual,expected,message"
}

///|
pub fn quality_gate_check_csv(check : QualityGateCheck) -> String {
  check.name +
  "," +
  check.passed.to_string() +
  "," +
  check.actual.to_string() +
  "," +
  check.expected.to_string() +
  "," +
  check.message
}

///|
pub fn quality_gate_csv(result : QualityGateResult) -> String {
  let builder = StringBuilder::new()
  builder.write_string(quality_gate_csv_header())
  for check in result.checks {
    builder.write_string("\n")
    builder.write_string(quality_gate_check_csv(check))
  }
  builder.to_string()
}

///|
pub fn quality_gate_config_valid(config : QualityGateConfig) -> Bool {
  config.minimum_score >= 0.0 &&
  config.minimum_score <= 100.0 &&
  config.maximum_blocking_issues >= 0 &&
  config.minimum_records >= 0 &&
  config.minimum_coverage >= 0.0 &&
  config.minimum_coverage <= 1.0
}

///|
pub fn quality_gate_result_valid(result : QualityGateResult) -> Bool {
  quality_gate_config_valid(result.config) &&
  result.report.score >= 0.0 &&
  result.report.score <= 100.0 &&
  result.checks.length() > 0 &&
  result.blocking_count >= 0
}
