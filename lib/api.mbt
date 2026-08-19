///|
/// Stable convenience entry points for small applications and examples.
pub(all) struct QuickMetrics {
  record_count : Int
  total_load : Double
  average_load : Double
  average_sleep : Double
  maximum_pain : Double
  average_fatigue : Double
  quality_score : Double
} derive(Debug, Eq, ToJson)

///|
pub fn quick_metrics(records : Array[DailyRecord]) -> QuickMetrics {
  {
    record_count: records.length(),
    total_load: total_load_values(training_loads(records)),
    average_load: mean_load_values(training_loads(records)),
    average_sleep: average_sleep_hours(records),
    maximum_pain: max_pain_level(records),
    average_fatigue: average_fatigue(records),
    quality_score: validate_records(records, default_quality_policy()).score,
  }
}

///|
pub fn assess_with_defaults(
  records : Array[DailyRecord],
  target_date : String,
) -> ComprehensiveAssessment? {
  assess_comprehensive(records, target_date, default_risk_policy())
}

///|
pub fn screen_csv(csv : String, target_date : String?) -> WorkflowResult {
  let config = { ..default_workflow_config(), target_date, }
  run_csv_workflow(csv, config)
}

///|
pub fn health_check(records : Array[DailyRecord]) -> PipelineAudit {
  audit_records(records, default_risk_policy())
}

///|
pub fn quick_report(records : Array[DailyRecord]) -> String {
  match assess_latest(records, default_risk_policy()) {
    Some(assessment) =>
      report_text(render_assessment(assessment, default_report_options()))
    None => "no valid telemetry record"
  }
}

///|
pub fn library_capabilities() -> Array[String] {
  [
    "sliding workload and ACWR metrics", "sleep, fatigue, pain, and readiness analysis",
    "configurable explainable risk policies", "data quality and CSV ingestion", "timeline, cohort, and plan review",
    "plain-text and CSV reporting",
  ]
}

///|
pub fn safe_target_date(
  records : Array[DailyRecord],
  requested : String?,
) -> String? {
  choose_target_date(normalize_records(records), requested)
}

///|
pub fn policy_summary(policy : RiskPolicy) -> String {
  validate_policy(policy).valid.to_string() +
  " " +
  policy.name +
  " rules=" +
  policy.rules.length().to_string() +
  " windows=" +
  policy.acute_window.to_string() +
  "/" +
  policy.chronic_window.to_string()
}

///|
pub fn risk_level_for_score(score : Double) -> RiskLevel {
  weighted_risk_level(bounded(score, 0.0, 100.0))
}

///|
pub fn merge_record_sources(
  first : Array[DailyRecord],
  second : Array[DailyRecord],
) -> Array[DailyRecord] {
  let merged = first.copy()
  for record in second {
    merged.push(record)
  }
  normalize_records(merged)
}

///|
pub fn source_summary(
  first : Array[DailyRecord],
  second : Array[DailyRecord],
) -> String {
  let merged = merge_record_sources(first, second)
  "first=" +
  first.length().to_string() +
  " second=" +
  second.length().to_string() +
  " merged=" +
  merged.length().to_string() +
  " duplicates_removed=" +
  (first.length() + second.length() - merged.length()).to_string()
}

///|
pub fn effective_record_count(records : Array[DailyRecord]) -> Int {
  records_with_valid_dates(normalize_records(records)).length()
}

///|
pub fn project_ready(records : Array[DailyRecord]) -> Bool {
  let audit = health_check(records)
  audit.passed && records.length() >= 7
}

///|
pub fn project_status(records : Array[DailyRecord]) -> String {
  if records.length() == 0 {
    "empty"
  } else if project_ready(records) {
    "ready"
  } else {
    "needs-review"
  }
}

///|
pub fn project_status_text(records : Array[DailyRecord]) -> String {
  "status=" +
  project_status(records) +
  " effective_records=" +
  effective_record_count(records).to_string() +
  " capabilities=" +
  library_capabilities().length().to_string()
}

///|
pub fn project_summary(records : Array[DailyRecord]) -> String {
  let metrics = quick_metrics(records)
  project_status_text(records) +
  " total_load=" +
  metrics.total_load.to_string() +
  " average_sleep=" +
  metrics.average_sleep.to_string() +
  " maximum_pain=" +
  metrics.maximum_pain.to_string() +
  " average_fatigue=" +
  metrics.average_fatigue.to_string()
}

///|
pub fn project_summary_lines(records : Array[DailyRecord]) -> Array[String] {
  let metrics = quick_metrics(records)
  [
    "status=" + project_status(records),
    "records=" + metrics.record_count.to_string(),
    "load=" + metrics.total_load.to_string(),
    "sleep=" + metrics.average_sleep.to_string(),
    "pain=" + metrics.maximum_pain.to_string(),
    "fatigue=" + metrics.average_fatigue.to_string(),
    "quality=" + metrics.quality_score.to_string(),
  ]
}

///|
pub fn project_has_actionable_risk(records : Array[DailyRecord]) -> Bool {
  match assess_latest(records, default_risk_policy()) {
    Some(assessment) => assessment_is_actionable(assessment)
    None => true
  }
}

///|
pub fn project_recommended_change(records : Array[DailyRecord]) -> Double {
  match decision_for_records(records, default_risk_policy()) {
    Some(decision) => decision.allowed_load_change
    None => 0.0
  }
}

///|
pub fn project_recommended_change_text(records : Array[DailyRecord]) -> String {
  "recommended_load_change=" +
  project_recommended_change(records).to_string() +
  "%"
}

///|
pub fn project_action_required_text(records : Array[DailyRecord]) -> String {
  if project_has_actionable_risk(records) {
    "action-required"
  } else {
    "monitor"
  }
}

///|
pub fn project_health_line(records : Array[DailyRecord]) -> String {
  project_status(records) +
  " / " +
  project_action_required_text(records) +
  " / " +
  project_recommended_change_text(records)
}

///|
pub(all) struct ProjectSnapshot {
  status : String
  health_line : String
  record_count : Int
  source_record_count : Int
  actionable : Bool
  recommended_change : Double
} derive(Debug, Eq, ToJson)

///|
pub fn project_snapshot(records : Array[DailyRecord]) -> ProjectSnapshot {
  {
    status: project_status(records),
    health_line: project_health_line(records),
    record_count: records.length(),
    source_record_count: effective_record_count(records),
    actionable: project_has_actionable_risk(records),
    recommended_change: project_recommended_change(records),
  }
}

///|
pub fn project_snapshot_text(snapshot : ProjectSnapshot) -> String {
  "status=" +
  snapshot.status +
  " records=" +
  snapshot.record_count.to_string() +
  " effective=" +
  snapshot.source_record_count.to_string() +
  " actionable=" +
  snapshot.actionable.to_string() +
  " change=" +
  snapshot.recommended_change.to_string() +
  "%"
}
