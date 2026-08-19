///|
/// Run manifests make an analysis result portable between CLI, CI, and services.
pub(all) struct RunManifest {
  run_id : String
  athlete_label : String
  generated_for : String
  status : String
  accepted : Bool
  record_count : Int
  session_count : Int
  alert_count : Int
  event_count : Int
  intervention_count : Int
  action_count : Int
  quality_score : Double
  coverage_percent : Double
  risk_score : Double
  readiness_score : Double
  artifact_names : Array[String]
  checksum : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RunManifestCheck {
  name : String
  passed : Bool
  actual : String
  expected : String
  message : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RunManifestReport {
  manifest : RunManifest
  checks : Array[RunManifestCheck]
  passed : Bool
  status : String
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
fn run_manifest_checksum(manifest : RunManifest) -> String {
  let mut value = manifest.run_id.length() + manifest.record_count
  for character in run_manifest_text(manifest) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn build_run_manifest(
  run : DecisionRun,
  performance : PerformanceSnapshot,
  athlete_label : String,
) -> RunManifest {
  let artifacts = [
    "decision", "monitoring", "events", "interventions", "baseline", "audit", "export",
    "performance",
  ]
  let base = {
    run_id: run.config.run_id,
    athlete_label,
    generated_for: run.monitoring.generated_for,
    status: run.status,
    accepted: run.accepted,
    record_count: performance.record_count,
    session_count: performance.session_count,
    alert_count: performance.alert_count,
    event_count: performance.event_count,
    intervention_count: performance.intervention_count,
    action_count: decision_run_action_count(run),
    quality_score: performance.quality_score,
    coverage_percent: performance.coverage_percent,
    risk_score: performance.risk_mean,
    readiness_score: performance.readiness_mean,
    artifact_names: artifacts,
    checksum: "",
  }
  {
    run_id: base.run_id,
    athlete_label: base.athlete_label,
    generated_for: base.generated_for,
    status: base.status,
    accepted: base.accepted,
    record_count: base.record_count,
    session_count: base.session_count,
    alert_count: base.alert_count,
    event_count: base.event_count,
    intervention_count: base.intervention_count,
    action_count: base.action_count,
    quality_score: base.quality_score,
    coverage_percent: base.coverage_percent,
    risk_score: base.risk_score,
    readiness_score: base.readiness_score,
    artifact_names: base.artifact_names,
    checksum: run_manifest_checksum(base),
  }
}

///|
pub fn run_manifest_for_run(
  run : DecisionRun,
  athlete_label : String,
) -> RunManifest {
  build_run_manifest(run, performance_snapshot([], [], run), athlete_label)
}

///|
pub fn run_manifest_check(
  name : String,
  passed : Bool,
  actual : String,
  expected : String,
  message : String,
) -> RunManifestCheck {
  { name, passed, actual, expected, message }
}

///|
pub fn validate_run_manifest(manifest : RunManifest) -> RunManifestReport {
  let checks = [
    run_manifest_check(
      "run_id",
      manifest.run_id != "",
      manifest.run_id,
      "non-empty",
      "run id is present",
    ),
    run_manifest_check(
      "athlete_label",
      manifest.athlete_label != "",
      manifest.athlete_label,
      "non-empty",
      "athlete label is present",
    ),
    run_manifest_check(
      "generated_for",
      manifest.generated_for != "",
      manifest.generated_for,
      "non-empty",
      "generation date is present",
    ),
    run_manifest_check(
      "record_count",
      manifest.record_count >= 0,
      manifest.record_count.to_string(),
      "non-negative",
      "record count is valid",
    ),
    run_manifest_check(
      "quality_score",
      manifest.quality_score >= 0.0 && manifest.quality_score <= 100.0,
      manifest.quality_score.to_string(),
      "0..100",
      "quality score is bounded",
    ),
    run_manifest_check(
      "coverage_percent",
      manifest.coverage_percent >= 0.0 && manifest.coverage_percent <= 100.0,
      manifest.coverage_percent.to_string(),
      "0..100",
      "coverage is bounded",
    ),
    run_manifest_check(
      "risk_score",
      manifest.risk_score >= 0.0 && manifest.risk_score <= 100.0,
      manifest.risk_score.to_string(),
      "0..100",
      "risk is bounded",
    ),
    run_manifest_check(
      "readiness_score",
      manifest.readiness_score >= 0.0 && manifest.readiness_score <= 100.0,
      manifest.readiness_score.to_string(),
      "0..100",
      "readiness is bounded",
    ),
    run_manifest_check(
      "artifacts",
      manifest.artifact_names.length() >= 5,
      manifest.artifact_names.length().to_string(),
      ">=5",
      "core artifacts are listed",
    ),
    run_manifest_check(
      "checksum",
      manifest.checksum == run_manifest_checksum(manifest),
      manifest.checksum,
      "deterministic",
      "manifest checksum matches content",
    ),
  ]
  let passed = checks.all(check => check.passed)
  {
    manifest,
    checks,
    passed,
    status: if passed {
      "valid"
    } else {
      "invalid"
    },
    recommendation: if passed {
      "manifest is ready for export"
    } else {
      "repair manifest fields before export"
    },
  }
}

///|
pub fn run_manifest_valid(manifest : RunManifest) -> Bool {
  validate_run_manifest(manifest).passed
}

///|
pub fn run_manifest_checks(
  report : RunManifestReport,
) -> Array[RunManifestCheck] {
  report.checks
}

///|
pub fn run_manifest_failed_checks(
  report : RunManifestReport,
) -> Array[RunManifestCheck] {
  report.checks.filter(check => !check.passed)
}

///|
pub fn run_manifest_check_by_name(
  report : RunManifestReport,
  name : String,
) -> RunManifestCheck? {
  for check in report.checks {
    if check.name == name {
      return Some(check)
    }
  }
  None
}

///|
pub fn run_manifest_check_count(report : RunManifestReport) -> Int {
  report.checks.length()
}

///|
pub fn run_manifest_failure_count(report : RunManifestReport) -> Int {
  run_manifest_failed_checks(report).length()
}

///|
pub fn run_manifest_status(report : RunManifestReport) -> String {
  report.status
}

///|
pub fn run_manifest_passes(report : RunManifestReport) -> Bool {
  report.passed
}

///|
pub fn run_manifest_requires_review(report : RunManifestReport) -> Bool {
  !report.passed
}

///|
pub fn run_manifest_run_id(manifest : RunManifest) -> String {
  manifest.run_id
}

///|
pub fn run_manifest_athlete_label(manifest : RunManifest) -> String {
  manifest.athlete_label
}

///|
pub fn run_manifest_date(manifest : RunManifest) -> String {
  manifest.generated_for
}

///|
pub fn run_manifest_status_value(manifest : RunManifest) -> String {
  manifest.status
}

///|
pub fn run_manifest_record_count(manifest : RunManifest) -> Int {
  manifest.record_count
}

///|
pub fn run_manifest_session_count(manifest : RunManifest) -> Int {
  manifest.session_count
}

///|
pub fn run_manifest_alert_count(manifest : RunManifest) -> Int {
  manifest.alert_count
}

///|
pub fn run_manifest_event_count(manifest : RunManifest) -> Int {
  manifest.event_count
}

///|
pub fn run_manifest_intervention_count(manifest : RunManifest) -> Int {
  manifest.intervention_count
}

///|
pub fn run_manifest_action_count(manifest : RunManifest) -> Int {
  manifest.action_count
}

///|
pub fn run_manifest_quality(manifest : RunManifest) -> Double {
  manifest.quality_score
}

///|
pub fn run_manifest_coverage(manifest : RunManifest) -> Double {
  manifest.coverage_percent
}

///|
pub fn run_manifest_risk(manifest : RunManifest) -> Double {
  manifest.risk_score
}

///|
pub fn run_manifest_readiness(manifest : RunManifest) -> Double {
  manifest.readiness_score
}

///|
pub fn run_manifest_artifacts(manifest : RunManifest) -> Array[String] {
  manifest.artifact_names
}

///|
pub fn run_manifest_has_artifact(manifest : RunManifest, name : String) -> Bool {
  manifest.artifact_names.contains(name)
}

///|
pub fn run_manifest_missing_artifacts(
  manifest : RunManifest,
  expected : Array[String],
) -> Array[String] {
  expected.filter(name => !manifest.artifact_names.contains(name))
}

///|
pub fn run_manifest_artifact_count(manifest : RunManifest) -> Int {
  manifest.artifact_names.length()
}

///|
pub fn run_manifest_action_rate(manifest : RunManifest) -> Double {
  if manifest.record_count == 0 {
    0.0
  } else {
    manifest.action_count.to_double() /
    manifest.record_count.to_double() *
    100.0
  }
}

///|
pub fn run_manifest_alert_rate(manifest : RunManifest) -> Double {
  if manifest.record_count == 0 {
    0.0
  } else {
    manifest.alert_count.to_double() / manifest.record_count.to_double() * 100.0
  }
}

///|
pub fn run_manifest_event_rate(manifest : RunManifest) -> Double {
  if manifest.record_count == 0 {
    0.0
  } else {
    manifest.event_count.to_double() / manifest.record_count.to_double() * 100.0
  }
}

///|
pub fn run_manifest_intervention_rate(manifest : RunManifest) -> Double {
  if manifest.record_count == 0 {
    0.0
  } else {
    manifest.intervention_count.to_double() /
    manifest.record_count.to_double() *
    100.0
  }
}

///|
pub fn run_manifest_recommendation(manifest : RunManifest) -> String {
  if !manifest.accepted {
    "review decision evidence before progression"
  } else if manifest.alert_count > 0 || manifest.event_count > 0 {
    "complete follow-up actions"
  } else {
    "continue the current cadence"
  }
}

///|
pub fn run_manifest_text(manifest : RunManifest) -> String {
  "run_id=" +
  manifest.run_id +
  " athlete=" +
  manifest.athlete_label +
  " date=" +
  manifest.generated_for +
  " status=" +
  manifest.status +
  " accepted=" +
  manifest.accepted.to_string() +
  " records=" +
  manifest.record_count.to_string() +
  " sessions=" +
  manifest.session_count.to_string() +
  " alerts=" +
  manifest.alert_count.to_string() +
  " events=" +
  manifest.event_count.to_string() +
  " interventions=" +
  manifest.intervention_count.to_string() +
  " actions=" +
  manifest.action_count.to_string() +
  " quality=" +
  manifest.quality_score.to_string() +
  " coverage=" +
  manifest.coverage_percent.to_string() +
  " risk=" +
  manifest.risk_score.to_string() +
  " readiness=" +
  manifest.readiness_score.to_string() +
  " artifacts=" +
  manifest.artifact_names.join(";") +
  " checksum=" +
  manifest.checksum
}

///|
pub fn run_manifest_check_text(check : RunManifestCheck) -> String {
  check.name +
  " passed=" +
  check.passed.to_string() +
  " actual=" +
  check.actual +
  " expected=" +
  check.expected +
  " message=" +
  check.message
}

///|
pub fn run_manifest_report_text(report : RunManifestReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "status=" +
    report.status +
    " passed=" +
    report.passed.to_string() +
    " recommendation=" +
    report.recommendation,
  )
  for check in report.checks {
    builder.write_string("\n" + run_manifest_check_text(check))
  }
  builder.to_string()
}

///|
pub fn run_manifest_csv_header() -> String {
  "run_id,athlete_label,generated_for,status,accepted,record_count,session_count,alert_count,event_count,intervention_count,action_count,quality_score,coverage_percent,risk_score,readiness_score,artifacts,checksum"
}

///|
pub fn run_manifest_csv(manifest : RunManifest) -> String {
  manifest.run_id +
  "," +
  manifest.athlete_label +
  "," +
  manifest.generated_for +
  "," +
  manifest.status +
  "," +
  manifest.accepted.to_string() +
  "," +
  manifest.record_count.to_string() +
  "," +
  manifest.session_count.to_string() +
  "," +
  manifest.alert_count.to_string() +
  "," +
  manifest.event_count.to_string() +
  "," +
  manifest.intervention_count.to_string() +
  "," +
  manifest.action_count.to_string() +
  "," +
  manifest.quality_score.to_string() +
  "," +
  manifest.coverage_percent.to_string() +
  "," +
  manifest.risk_score.to_string() +
  "," +
  manifest.readiness_score.to_string() +
  "," +
  manifest.artifact_names.join(";") +
  "," +
  manifest.checksum
}

///|
pub fn run_manifest_report_csv(report : RunManifestReport) -> String {
  run_manifest_csv(report.manifest)
}

///|
pub fn run_manifest_summary_header() -> Array[String] {
  [
    "run_id", "status", "accepted", "records", "alerts", "events", "actions", "quality",
    "coverage", "risk", "readiness", "valid",
  ]
}

///|
pub fn run_manifest_summary(manifest : RunManifest) -> Array[String] {
  [
    manifest.run_id,
    manifest.status,
    manifest.accepted.to_string(),
    manifest.record_count.to_string(),
    manifest.alert_count.to_string(),
    manifest.event_count.to_string(),
    manifest.action_count.to_string(),
    manifest.quality_score.to_string(),
    manifest.coverage_percent.to_string(),
    manifest.risk_score.to_string(),
    manifest.readiness_score.to_string(),
    run_manifest_valid(manifest).to_string(),
  ]
}

///|
pub fn run_manifest_summary_csv(manifest : RunManifest) -> String {
  run_manifest_summary_header().join(",") +
  "\n" +
  run_manifest_summary(manifest).join(",")
}

///|
pub fn run_manifest_contract(manifest : RunManifest) -> Array[String] {
  [
    manifest.status,
    run_manifest_valid(manifest).to_string(),
    run_manifest_recommendation(manifest),
    run_manifest_action_rate(manifest).to_string(),
    run_manifest_alert_rate(manifest).to_string(),
    run_manifest_checksum(manifest),
  ]
}

///|
pub fn run_manifest_checksum_value(manifest : RunManifest) -> String {
  manifest.checksum
}

///|
pub fn run_manifest_reproducible(
  left : RunManifest,
  right : RunManifest,
) -> Bool {
  run_manifest_checksum(left) == run_manifest_checksum(right)
}

///|
pub fn run_manifest_exportable(manifest : RunManifest) -> Bool {
  run_manifest_valid(manifest) && manifest.artifact_names.length() >= 5
}

///|
pub fn run_manifest_export_status(manifest : RunManifest) -> String {
  if run_manifest_exportable(manifest) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn run_manifest_status_code(manifest : RunManifest) -> Int {
  if !run_manifest_valid(manifest) {
    422
  } else if manifest.status == "critical" {
    409
  } else if manifest.accepted {
    200
  } else {
    206
  }
}

///|
pub fn run_manifest_review_days(manifest : RunManifest) -> Int {
  if manifest.status == "critical" {
    0
  } else if !manifest.accepted {
    1
  } else if manifest.alert_count > 0 {
    3
  } else {
    7
  }
}

///|
pub fn run_manifest_review_label(manifest : RunManifest) -> String {
  "review_in_" + run_manifest_review_days(manifest).to_string() + "_days"
}
