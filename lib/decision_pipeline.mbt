///|
/// One-call orchestration for applications that need an auditable decision run.
pub(all) struct DecisionRunConfig {
  risk_policy : RiskPolicy
  monitor_thresholds : MonitoringThresholds
  quality_gate : QualityGateConfig
  load_model : LoadModelConfig
  athlete_label : String
  run_id : String
  include_sessions : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct DecisionRun {
  config : DecisionRunConfig
  quality : QualityGateResult
  latest : ComprehensiveAssessment?
  monitoring : MonitoringRun
  events : EventLog
  interventions : InterventionPlan?
  baseline : BaselineReport
  workspace : CoachWorkspace
  audit : DecisionAuditTrail
  accepted : Bool
  status : String
} derive(Debug, Eq, ToJson)

///|
pub fn default_decision_run_config() -> DecisionRunConfig {
  {
    risk_policy: default_risk_policy(),
    monitor_thresholds: default_monitoring_thresholds(),
    quality_gate: default_quality_gate_config(),
    load_model: default_load_model_config(),
    athlete_label: "athlete",
    run_id: "local-run",
    include_sessions: true,
  }
}

///|
fn decision_run_status(
  quality : QualityGateResult,
  workspace : CoachWorkspace,
  accepted : Bool,
) -> String {
  if !quality.passed {
    "quality_rejected"
  } else if workspace.status == "critical" {
    "critical"
  } else if workspace.status == "urgent" {
    "action_required"
  } else if accepted {
    "accepted"
  } else {
    "review"
  }
}

///|
fn decision_run_audit(
  config : DecisionRunConfig,
  records : Array[DailyRecord],
  quality : QualityGateResult,
  latest : ComprehensiveAssessment?,
  monitoring : MonitoringRun,
  interventions : InterventionPlan?,
) -> DecisionAuditTrail {
  let trail = audit_input(new_decision_audit(config.run_id), records)
  let trail = audit_quality(trail, quality.report)
  let trail = match latest {
    Some(value) => audit_assessment(trail, value)
    None => trail
  }
  let trail = audit_monitoring(trail, monitoring)
  let trail = match interventions {
    Some(value) => audit_intervention_plan(trail, value)
    None => trail
  }
  audit_review(
    trail,
    "decision_run",
    if quality.passed {
      "accepted"
    } else {
      "quality_rejected"
    },
    "deterministic pipeline",
  )
}

///|
pub fn run_decision_pipeline(
  records : Array[DailyRecord],
  config : DecisionRunConfig,
) -> DecisionRun {
  let quality = evaluate_quality_gate(records, config.quality_gate)
  let latest = assess_latest(records, config.risk_policy)
  let monitoring = run_monitoring(
    records,
    config.risk_policy,
    config.monitor_thresholds,
  )
  let events = event_log_from_records(
    records,
    config.risk_policy,
    config.monitor_thresholds,
  )
  let interventions = match latest {
    Some(value) => Some(build_intervention_plan(value))
    None => None
  }
  let baseline = build_baseline_report(
    records,
    config.risk_policy,
    config.athlete_label,
  )
  let workspace = build_coach_workspace(
    records,
    config.risk_policy,
    config.monitor_thresholds,
  )
  let accepted = quality.passed && workspace.status != "critical"
  {
    config,
    quality,
    latest,
    monitoring,
    events,
    interventions,
    baseline,
    workspace,
    audit: decision_run_audit(
      config, records, quality, latest, monitoring, interventions,
    ),
    accepted,
    status: decision_run_status(quality, workspace, accepted),
  }
}

///|
pub fn decision_run_export(run : DecisionRun) -> ExportBundle {
  build_export_bundle(
    run.config.run_id,
    run.monitoring.generated_for,
    run.latest,
    run.monitoring,
    run.events,
    run.interventions,
    Some(run.baseline),
    None,
    Some(run.audit),
  )
}

///|
pub fn decision_run_requires_action(run : DecisionRun) -> Bool {
  let intervention_action = match run.interventions {
    Some(plan) => !intervention_plan_is_safe(plan)
    None => false
  }
  !run.accepted ||
  monitoring_requires_review(run.monitoring) ||
  intervention_action
}

///|
pub fn decision_run_is_reproducible(
  left : DecisionRun,
  right : DecisionRun,
) -> Bool {
  decision_audit_text(left.audit) == decision_audit_text(right.audit) &&
  monitoring_run_text(left.monitoring) == monitoring_run_text(right.monitoring) &&
  left.status == right.status
}

///|
pub fn decision_run_latest_risk(run : DecisionRun) -> Double {
  match run.latest {
    Some(value) => value.risk_score
    None => 0.0
  }
}

///|
pub fn decision_run_latest_readiness(run : DecisionRun) -> Double {
  match run.latest {
    Some(value) => value.readiness_score
    None => 0.0
  }
}

///|
pub fn decision_run_action_count(run : DecisionRun) -> Int {
  workspace_action_count(run.workspace)
}

///|
pub fn decision_run_alert_count(run : DecisionRun) -> Int {
  run.monitoring.summary.alert_count
}

///|
pub fn decision_run_event_count(run : DecisionRun) -> Int {
  run.events.events.length()
}

///|
pub fn decision_run_audit_valid(run : DecisionRun) -> Bool {
  verify_decision_audit(run.audit)
}

///|
pub fn decision_run_quality_valid(run : DecisionRun) -> Bool {
  quality_gate_passes(run.quality)
}

///|
pub fn decision_run_intervention_count(run : DecisionRun) -> Int {
  match run.interventions {
    Some(plan) => plan.interventions.length()
    None => 0
  }
}

///|
pub fn decision_run_recommendation(run : DecisionRun) -> String {
  workspace_recommended_action(run.workspace)
}

///|
pub fn decision_run_summary(run : DecisionRun) -> String {
  "run=" +
  run.config.run_id +
  " status=" +
  run.status +
  " accepted=" +
  run.accepted.to_string() +
  " risk=" +
  decision_run_latest_risk(run).to_string() +
  " readiness=" +
  decision_run_latest_readiness(run).to_string() +
  " alerts=" +
  decision_run_alert_count(run).to_string() +
  " events=" +
  decision_run_event_count(run).to_string() +
  " actions=" +
  decision_run_action_count(run).to_string() +
  " audit_valid=" +
  decision_run_audit_valid(run).to_string()
}

///|
pub fn decision_run_text(run : DecisionRun) -> String {
  let builder = StringBuilder::new()
  builder.write_string(decision_run_summary(run))
  builder.write_string("\nquality=" + quality_gate_summary(run.quality))
  builder.write_string(
    "\nmonitoring=" + monitoring_summary_text(run.monitoring.summary),
  )
  builder.write_string(
    "\nworkspace=" + workspace_recommended_action(run.workspace),
  )
  builder.write_string("\nbaseline=" + run.baseline.note)
  builder.write_string(
    "\naudit=" + verify_decision_audit(run.audit).to_string(),
  )
  builder.to_string()
}

///|
pub fn decision_run_csv(run : DecisionRun) -> String {
  let builder = StringBuilder::new()
  builder.write_string("field,value")
  builder.write_string("\nstatus," + run.status)
  builder.write_string("\naccepted," + run.accepted.to_string())
  builder.write_string("\nrisk," + decision_run_latest_risk(run).to_string())
  builder.write_string(
    "\nreadiness," + decision_run_latest_readiness(run).to_string(),
  )
  builder.write_string("\nalerts," + decision_run_alert_count(run).to_string())
  builder.write_string("\nevents," + decision_run_event_count(run).to_string())
  builder.write_string(
    "\nactions," + decision_run_action_count(run).to_string(),
  )
  builder.to_string()
}

///|
pub fn decision_run_config_valid(config : DecisionRunConfig) -> Bool {
  config.run_id != "" &&
  config.athlete_label != "" &&
  monitoring_config_valid(config.monitor_thresholds) &&
  load_model_config_valid(config.load_model) &&
  quality_gate_config_valid(config.quality_gate)
}

///|
pub fn decision_run_valid(run : DecisionRun) -> Bool {
  decision_run_config_valid(run.config) &&
  quality_gate_result_valid(run.quality) &&
  decision_run_audit_valid(run) &&
  workspace_valid(run.workspace) &&
  run.status != ""
}
