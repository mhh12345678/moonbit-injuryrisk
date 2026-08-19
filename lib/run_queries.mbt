///|
/// Query helpers for consumers that need small slices of a completed run.
pub fn query_latest_alert(run : DecisionRun) -> MonitoringAlert? {
  let alerts = monitoring_alerts(run.monitoring)
  if alerts.length() == 0 {
    None
  } else {
    Some(alerts[alerts.length() - 1])
  }
}

///|
pub fn query_latest_event(run : DecisionRun) -> RiskEvent? {
  if run.events.events.length() == 0 {
    None
  } else {
    Some(run.events.events[run.events.events.length() - 1])
  }
}

///|
pub fn query_latest_brief(run : DecisionRun) -> DailyBrief? {
  match run.latest {
    Some(assessment) => Some(daily_brief(assessment))
    None => None
  }
}

///|
pub fn query_action_dates(run : DecisionRun) -> Array[String] {
  monitoring_action_dates(run.monitoring)
}

///|
pub fn query_escalation_dates(run : DecisionRun) -> Array[String] {
  monitoring_escalation_dates(run.monitoring)
}

///|
pub fn query_high_risk_dates(run : DecisionRun) -> Array[String] {
  run.monitoring.monitors
  .filter(monitor => {
    match monitor.assessment {
      Some(value) => value.risk_level == High
      None => false
    }
  })
  .map(monitor => monitor.date)
}

///|
pub fn query_low_readiness_dates(
  run : DecisionRun,
  floor : Double,
) -> Array[String] {
  run.monitoring.monitors
  .filter(monitor => {
    match monitor.assessment {
      Some(value) => value.readiness_score < floor
      None => true
    }
  })
  .map(monitor => monitor.date)
}

///|
pub fn query_quality_failures(run : DecisionRun) -> Array[String] {
  run.quality.report.issues.map(issue => issue.date)
}

///|
pub fn query_intervention_ids(run : DecisionRun) -> Array[String] {
  match run.interventions {
    Some(plan) => plan.interventions.map(item => item.id)
    None => []
  }
}

///|
pub fn query_pending_intervention_ids(run : DecisionRun) -> Array[String] {
  match run.interventions {
    Some(plan) => pending_interventions(plan).map(item => item.id)
    None => []
  }
}

///|
pub fn query_baseline_concerns(run : DecisionRun) -> Array[String] {
  run.baseline.drifts.filter(item => item.concern).map(item => item.metric)
}

///|
pub fn query_evidence_domains(run : DecisionRun) -> Array[String] {
  evidence_domains(build_evidence_matrix(evidence_from_run(run.monitoring)))
}

///|
pub fn query_open_reviews(register : ReviewRegister) -> Array[String] {
  open_reviews(register).map(review => review.id)
}

///|
pub fn query_run_has_data(run : DecisionRun) -> Bool {
  run.quality.report.record_count > 0
}

///|
pub fn query_run_is_reliable(run : DecisionRun) -> Bool {
  run.accepted && run.quality.report.score >= 80.0 && run.audit.valid
}

///|
pub fn query_run_status_code(run : DecisionRun) -> Int {
  match run.status {
    "accepted" => 0
    "review" => 1
    "action_required" => 2
    "critical" => 3
    "quality_rejected" => 4
    _ => 5
  }
}

///|
pub fn query_risk_band_code(level : RiskLevel) -> Int {
  match level {
    Low => 0
    Medium => 1
    High => 2
  }
}

///|
pub fn query_alert_severity_code(severity : MonitorAlertSeverity) -> Int {
  match severity {
    Info => 0
    Watch => 1
    Action => 2
    Escalate => 3
  }
}

///|
pub fn query_priority_code(priority : RiskEventPriority) -> Int {
  match priority {
    Routine => 0
    Important => 1
    Urgent => 2
    Critical => 3
  }
}

///|
pub fn query_summary_fields(run : DecisionRun) -> Array[String] {
  [
    run.status,
    run.accepted.to_string(),
    decision_run_latest_risk(run).to_string(),
    decision_run_latest_readiness(run).to_string(),
    decision_run_alert_count(run).to_string(),
    decision_run_event_count(run).to_string(),
    decision_run_action_count(run).to_string(),
    run.quality.report.score.to_string(),
    run.baseline.profile.coverage_percent.to_string(),
  ]
}

///|
pub fn query_summary_header() -> Array[String] {
  [
    "status", "accepted", "risk", "readiness", "alerts", "events", "actions", "quality",
    "baseline_coverage",
  ]
}

///|
pub fn query_summary_csv(run : DecisionRun) -> String {
  query_summary_header().join(",") + "\n" + query_summary_fields(run).join(",")
}

///|
pub fn query_event_kind_counts(run : DecisionRun) -> Array[Int] {
  decision_audit_kinds().map(kind => {
    audit_entries_by_kind(run.audit, kind).length()
  })
}

///|
pub fn query_alert_kind_counts(run : DecisionRun) -> Array[Int] {
  [
    monitoring_alert_count_by_kind(run.monitoring, RiskScore),
    monitoring_alert_count_by_kind(run.monitoring, Readiness),
    monitoring_alert_count_by_kind(run.monitoring, Pain),
    monitoring_alert_count_by_kind(run.monitoring, LoadRatio),
    monitoring_alert_count_by_kind(run.monitoring, Sleep),
    monitoring_alert_count_by_kind(run.monitoring, Fatigue),
    monitoring_alert_count_by_kind(run.monitoring, Quality),
    monitoring_alert_count_by_kind(run.monitoring, TrainingStreak),
  ]
}

///|
pub fn query_metric_value(run : DecisionRun, metric : String) -> Double {
  match metric {
    "risk" => decision_run_latest_risk(run)
    "readiness" => decision_run_latest_readiness(run)
    "quality" => run.quality.report.score
    "coverage" => run.baseline.profile.coverage_percent
    "load" =>
      match run.latest {
        Some(value) => value.load.average_load
        None => 0.0
      }
    "recovery" =>
      match run.latest {
        Some(value) => value.recovery.recovery_score
        None => 0.0
      }
    "acwr" =>
      match run.latest {
        Some(value) => value.load.acwr
        None => 0.0
      }
    _ => 0.0
  }
}

///|
pub fn query_metric_names() -> Array[String] {
  ["risk", "readiness", "quality", "coverage", "load", "recovery", "acwr"]
}

///|
pub fn query_metric_is_actionable(run : DecisionRun, metric : String) -> Bool {
  match metric {
    "risk" => query_metric_value(run, metric) >= 40.0
    "readiness" => query_metric_value(run, metric) < 70.0
    "quality" => query_metric_value(run, metric) < 80.0
    "coverage" => query_metric_value(run, metric) < 80.0
    "acwr" => query_metric_value(run, metric) > 1.5
    "recovery" => query_metric_value(run, metric) < 70.0
    _ => false
  }
}

///|
pub fn query_actionable_metrics(run : DecisionRun) -> Array[String] {
  query_metric_names().filter(metric => query_metric_is_actionable(run, metric))
}

///|
pub fn query_run_recommendation(run : DecisionRun) -> String {
  let metrics = query_actionable_metrics(run)
  if metrics.length() == 0 {
    "no metric is currently outside the action band"
  } else {
    "review metrics: " + metrics.join(",")
  }
}

///|
pub fn query_record_dates(run : DecisionRun) -> Array[String] {
  run.quality.report.issues.map(issue => issue.date)
}

///|
pub fn query_has_duplicate_dates(run : DecisionRun) -> Bool {
  run.quality.report.duplicate_date_count > 0
}

///|
pub fn query_has_missing_dates(run : DecisionRun) -> Bool {
  run.quality.report.missing_date_count > 0
}

///|
pub fn query_data_quality_label(run : DecisionRun) -> String {
  quality_band(run.quality.report.score)
}

///|
pub fn query_audit_checksum(run : DecisionRun) -> String {
  run.audit.final_checksum
}

///|
pub fn query_export_manifest(run : DecisionRun) -> String {
  export_bundle_manifest(decision_run_export(run))
}
