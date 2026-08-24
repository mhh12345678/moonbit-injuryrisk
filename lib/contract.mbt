///|
/// Contract checks used before an assessment is published downstream.
pub(all) struct ContractCheck {
  name : String
  passed : Bool
  observed : String
  expected : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ContractReport {
  passed : Bool
  checks : Array[ContractCheck]
} derive(Debug, Eq, ToJson)

///|
fn contract_check(
  name : String,
  passed : Bool,
  observed : String,
  expected : String,
) -> ContractCheck {
  { name, passed, observed, expected }
}

///|
pub fn check_record_contract(records : Array[DailyRecord]) -> ContractReport {
  let checks = []
  checks.push(
    contract_check(
      "non-empty",
      records.length() > 0,
      records.length().to_string(),
      "> 0 records",
    ),
  )
  checks.push(
    contract_check(
      "valid-dates",
      records_with_valid_dates(records).length() == records.length(),
      records_with_valid_dates(records).length().to_string(),
      records.length().to_string(),
    ),
  )
  checks.push(
    contract_check(
      "unique-dates",
      duplicate_date_indices(records).length() == 0,
      duplicate_date_indices(records).length().to_string(),
      "0 duplicates",
    ),
  )
  checks.push(
    contract_check(
      "chronological",
      date_order_issues(records).length() == 0,
      date_order_issues(records).length().to_string(),
      "0 ordering issues",
    ),
  )
  { passed: checks.filter(check => !check.passed).length() == 0, checks }
}

///|
pub fn check_assessment_contract(
  assessment : ComprehensiveAssessment,
) -> ContractReport {
  let checks = []
  checks.push(
    contract_check(
      "risk-bounded",
      assessment.risk_score >= 0.0 && assessment.risk_score <= 100.0,
      assessment.risk_score.to_string(),
      "0..100",
    ),
  )
  checks.push(
    contract_check(
      "readiness-bounded",
      assessment.readiness_score >= 0.0 && assessment.readiness_score <= 100.0,
      assessment.readiness_score.to_string(),
      "0..100",
    ),
  )
  checks.push(
    contract_check(
      "quality-bounded",
      assessment.quality.score >= 0.0 && assessment.quality.score <= 100.0,
      assessment.quality.score.to_string(),
      "0..100",
    ),
  )
  checks.push(
    contract_check(
      "report-present",
      assessment.summary != "",
      if assessment.summary == "" {
        "empty"
      } else {
        "present"
      },
      "present",
    ),
  )
  { passed: checks.filter(check => !check.passed).length() == 0, checks }
}

///|
pub fn contract_report_text(report : ContractReport) -> String {
  let builder = StringBuilder()
  builder.write_string("passed=" + report.passed.to_string())
  for check in report.checks {
    builder.write_string(
      "\n[" +
      (if check.passed { "pass" } else { "fail" }) +
      "] " +
      check.name +
      " observed=" +
      check.observed +
      " expected=" +
      check.expected,
    )
  }
  builder.to_string()
}

///|
pub fn check_policy_contract(policy : RiskPolicy) -> ContractReport {
  let validation = validate_policy(policy)
  let checks = []
  checks.push(
    contract_check(
      "policy-valid",
      validation.valid,
      validation.errors.length().to_string(),
      "0 errors",
    ),
  )
  checks.push(
    contract_check(
      "acute-window",
      policy.acute_window > 0,
      policy.acute_window.to_string(),
      "> 0",
    ),
  )
  checks.push(
    contract_check(
      "chronic-window",
      policy.chronic_window >= policy.acute_window,
      policy.chronic_window.to_string(),
      "at least acute window",
    ),
  )
  checks.push(
    contract_check(
      "sleep-target",
      policy.sleep_target > 0.0,
      policy.sleep_target.to_string(),
      "> 0",
    ),
  )
  { passed: checks.filter(check => !check.passed).length() == 0, checks }
}

///|
pub fn check_csv_contract(result : TelemetryCsvResult) -> ContractReport {
  let checks = []
  checks.push(
    contract_check(
      "csv-has-records",
      result.records.length() > 0,
      result.records.length().to_string(),
      "> 0",
    ),
  )
  checks.push(
    contract_check(
      "csv-row-shape",
      result.issues.filter(issue => issue.field == "row").length() == 0,
      result.issues.length().to_string(),
      "no malformed rows",
    ),
  )
  checks.push(
    contract_check(
      "csv-valid-date",
      records_with_valid_dates(result.records).length() ==
      result.records.length(),
      "checked",
      "all dates valid",
    ),
  )
  { passed: checks.filter(check => !check.passed).length() == 0, checks }
}

///|
pub fn contract_report_passes(report : ContractReport) -> Bool {
  report.passed && report.checks.filter(check => !check.passed).length() == 0
}

///|
pub fn contract_check_names(report : ContractReport) -> Array[String] {
  report.checks.map(check => check.name)
}

///|
pub fn contract_failed_checks(report : ContractReport) -> Array[ContractCheck] {
  report.checks.filter(check => !check.passed)
}

///|
pub fn contract_warning_text(report : ContractReport) -> String {
  let failed = contract_failed_checks(report)
  if failed.length() == 0 {
    "all contract checks passed"
  } else {
    "failed checks=" + failed.map(check => check.name).join(",")
  }
}
