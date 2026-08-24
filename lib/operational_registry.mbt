///|
/// Registry of named operational artifacts for application integration.
pub(all) enum RegistryArtifactKind {
  RegistryAssessment
  RegistryMonitoring
  RegistryEventLog
  RegistryInterventionPlan
  RegistryBaseline
  RegistrySchedule
  RegistryAudit
  RegistryBrief
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RegistryArtifact {
  id : String
  kind : RegistryArtifactKind
  date : String
  label : String
  status : String
  version : Int
  checksum : String
  content : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct OperationalRegistry {
  name : String
  artifacts : Array[RegistryArtifact]
  active_id : String?
  next_version : Int
  valid : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn registry_artifact_name(kind : RegistryArtifactKind) -> String {
  match kind {
    RegistryAssessment => "assessment"
    RegistryMonitoring => "monitoring"
    RegistryEventLog => "event_log"
    RegistryInterventionPlan => "intervention_plan"
    RegistryBaseline => "baseline"
    RegistrySchedule => "schedule"
    RegistryAudit => "audit"
    RegistryBrief => "brief"
  }
}

///|
fn registry_checksum(
  id : String,
  kind : RegistryArtifactKind,
  version : Int,
  content : String,
) -> String {
  let mut value = id.length() + version
  for character in content {
    value = (value * 33 + character.to_int()) % 2147483647
  }
  value.to_string() + "-" + registry_artifact_name(kind)
}

///|
fn registry_artifact(
  id : String,
  kind : RegistryArtifactKind,
  date : String,
  label : String,
  status : String,
  version : Int,
  content : String,
) -> RegistryArtifact {
  {
    id,
    kind,
    date,
    label,
    status,
    version,
    checksum: registry_checksum(id, kind, version, content),
    content,
  }
}

///|
pub fn new_operational_registry(name : String) -> OperationalRegistry {
  { name, artifacts: [], active_id: None, next_version: 1, valid: true }
}

///|
pub fn register_artifact(
  registry : OperationalRegistry,
  artifact : RegistryArtifact,
) -> OperationalRegistry {
  let artifacts = registry.artifacts.filter(item => item.id != artifact.id) +
    [artifact]
  {
    name: registry.name,
    artifacts,
    active_id: Some(artifact.id),
    next_version: artifact.version + 1,
    valid: registry.valid && artifact.id != "" && artifact.checksum != "",
  }
}

///|
pub fn register_assessment(
  registry : OperationalRegistry,
  assessment : ComprehensiveAssessment,
) -> OperationalRegistry {
  register_artifact(
    registry,
    registry_artifact(
      "assessment-" + assessment.date,
      RegistryAssessment,
      assessment.date,
      "assessment",
      risk_level_name(assessment.risk_level),
      registry.next_version,
      assessment_text(assessment),
    ),
  )
}

///|
pub fn register_monitoring(
  registry : OperationalRegistry,
  run : MonitoringRun,
) -> OperationalRegistry {
  register_artifact(
    registry,
    registry_artifact(
      "monitoring-" + run.generated_for,
      RegistryMonitoring,
      run.generated_for,
      "monitoring",
      run.summary.status,
      registry.next_version,
      monitoring_run_text(run),
    ),
  )
}

///|
pub fn register_event_log(
  registry : OperationalRegistry,
  log : EventLog,
  date : String,
) -> OperationalRegistry {
  register_artifact(
    registry,
    registry_artifact(
      "events-" + date,
      RegistryEventLog,
      date,
      "events",
      log.status,
      registry.next_version,
      event_log_text(log),
    ),
  )
}

///|
pub fn register_intervention_plan(
  registry : OperationalRegistry,
  plan : InterventionPlan,
) -> OperationalRegistry {
  register_artifact(
    registry,
    registry_artifact(
      "interventions-" + plan.anchor_date,
      RegistryInterventionPlan,
      plan.anchor_date,
      "interventions",
      plan.status,
      registry.next_version,
      intervention_plan_text(plan),
    ),
  )
}

///|
pub fn register_baseline(
  registry : OperationalRegistry,
  report : BaselineReport,
) -> OperationalRegistry {
  register_artifact(
    registry,
    registry_artifact(
      "baseline-" + report.profile.label,
      RegistryBaseline,
      "",
      report.profile.label,
      report.note,
      registry.next_version,
      baseline_report_text(report),
    ),
  )
}

///|
pub fn register_schedule(
  registry : OperationalRegistry,
  summary : ScheduleSummary,
) -> OperationalRegistry {
  register_artifact(
    registry,
    registry_artifact(
      "schedule-" + summary.start_date,
      RegistrySchedule,
      summary.start_date,
      "schedule",
      summary.status,
      registry.next_version,
      schedule_summary_text(summary),
    ),
  )
}

///|
pub fn register_audit(
  registry : OperationalRegistry,
  trail : DecisionAuditTrail,
) -> OperationalRegistry {
  register_artifact(
    registry,
    registry_artifact(
      "audit-" + trail.run_id,
      RegistryAudit,
      "",
      trail.run_id,
      verify_decision_audit(trail).to_string(),
      registry.next_version,
      decision_audit_text(trail),
    ),
  )
}

///|
pub fn register_brief(
  registry : OperationalRegistry,
  brief : DailyBrief,
) -> OperationalRegistry {
  register_artifact(
    registry,
    registry_artifact(
      "brief-" + brief.date,
      RegistryBrief,
      brief.date,
      "brief",
      risk_level_name(brief.risk_level),
      registry.next_version,
      brief_text(brief),
    ),
  )
}

///|
pub fn registry_artifact_by_id(
  registry : OperationalRegistry,
  id : String,
) -> RegistryArtifact? {
  for artifact in registry.artifacts {
    if artifact.id == id {
      return Some(artifact)
    }
  }
  None
}

///|
pub fn registry_artifacts_by_kind(
  registry : OperationalRegistry,
  kind : RegistryArtifactKind,
) -> Array[RegistryArtifact] {
  registry.artifacts.filter(artifact => artifact.kind == kind)
}

///|
pub fn registry_artifacts_by_date(
  registry : OperationalRegistry,
  date : String,
) -> Array[RegistryArtifact] {
  registry.artifacts.filter(artifact => artifact.date == date)
}

///|
pub fn registry_latest(
  registry : OperationalRegistry,
  kind : RegistryArtifactKind,
) -> RegistryArtifact? {
  let artifacts = registry_artifacts_by_kind(registry, kind)
  if artifacts.length() == 0 {
    None
  } else {
    Some(artifacts[artifacts.length() - 1])
  }
}

///|
pub fn registry_artifact_count(
  registry : OperationalRegistry,
  kind : RegistryArtifactKind,
) -> Int {
  registry_artifacts_by_kind(registry, kind).length()
}

///|
pub fn registry_total_count(registry : OperationalRegistry) -> Int {
  registry.artifacts.length()
}

///|
pub fn registry_kind_counts(registry : OperationalRegistry) -> Array[Int] {
  registry_artifact_kinds().map(kind => registry_artifact_count(registry, kind))
}

///|
pub fn registry_artifact_kinds() -> Array[RegistryArtifactKind] {
  [
    RegistryAssessment,
    RegistryMonitoring,
    RegistryEventLog,
    RegistryInterventionPlan,
    RegistryBaseline,
    RegistrySchedule,
    RegistryAudit,
    RegistryBrief,
  ]
}

///|
pub fn registry_activate(
  registry : OperationalRegistry,
  id : String,
) -> OperationalRegistry {
  if registry_artifact_by_id(registry, id) is None {
    registry
  } else {
    {
      name: registry.name,
      artifacts: registry.artifacts,
      active_id: Some(id),
      next_version: registry.next_version,
      valid: registry.valid,
    }
  }
}

///|
pub fn registry_active(registry : OperationalRegistry) -> RegistryArtifact? {
  match registry.active_id {
    Some(id) => registry_artifact_by_id(registry, id)
    None => None
  }
}

///|
pub fn registry_remove(
  registry : OperationalRegistry,
  id : String,
) -> OperationalRegistry {
  let artifacts = registry.artifacts.filter(artifact => artifact.id != id)
  let active = match registry.active_id {
    Some(value) => if value == id { None } else { Some(value) }
    None => None
  }
  {
    name: registry.name,
    artifacts,
    active_id: active,
    next_version: registry.next_version,
    valid: registry.valid,
  }
}

///|
pub fn registry_status(registry : OperationalRegistry) -> String {
  if !registry.valid {
    "invalid"
  } else if registry.artifacts.length() == 0 {
    "empty"
  } else if registry.active_id is Some(_) {
    "active"
  } else {
    "stored"
  }
}

///|
pub fn registry_has_all_core(registry : OperationalRegistry) -> Bool {
  registry_artifact_by_kind_present(registry, RegistryAssessment) &&
  registry_artifact_by_kind_present(registry, RegistryMonitoring) &&
  registry_artifact_by_kind_present(registry, RegistryEventLog) &&
  registry_artifact_by_kind_present(registry, RegistryAudit)
}

///|
fn registry_artifact_by_kind_present(
  registry : OperationalRegistry,
  kind : RegistryArtifactKind,
) -> Bool {
  registry_artifact_count(registry, kind) > 0
}

///|
pub fn registry_checksum_valid(artifact : RegistryArtifact) -> Bool {
  artifact.checksum ==
  registry_checksum(
    artifact.id,
    artifact.kind,
    artifact.version,
    artifact.content,
  )
}

///|
pub fn registry_invalid_artifacts(
  registry : OperationalRegistry,
) -> Array[String] {
  registry.artifacts
  .filter(artifact => !registry_checksum_valid(artifact))
  .map(artifact => artifact.id)
}

///|
pub fn registry_repair(registry : OperationalRegistry) -> OperationalRegistry {
  let artifacts = registry.artifacts.map(artifact => {
    registry_artifact(
      artifact.id,
      artifact.kind,
      artifact.date,
      artifact.label,
      artifact.status,
      artifact.version,
      artifact.content,
    )
  })
  {
    name: registry.name,
    artifacts,
    active_id: registry.active_id,
    next_version: registry.next_version,
    valid: true,
  }
}

///|
pub fn registry_labels(registry : OperationalRegistry) -> Array[String] {
  let labels = []
  for artifact in registry.artifacts {
    if !labels.contains(artifact.label) {
      labels.push(artifact.label)
    }
  }
  labels
}

///|
pub fn registry_statuses(registry : OperationalRegistry) -> Array[String] {
  let statuses = []
  for artifact in registry.artifacts {
    if !statuses.contains(artifact.status) {
      statuses.push(artifact.status)
    }
  }
  statuses
}

///|
pub fn registry_content(registry : OperationalRegistry, id : String) -> String {
  match registry_artifact_by_id(registry, id) {
    Some(artifact) => artifact.content
    None => ""
  }
}

///|
pub fn registry_text(registry : OperationalRegistry) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "name=" +
    registry.name +
    " status=" +
    registry_status(registry) +
    " artifacts=" +
    registry.artifacts.length().to_string() +
    " next_version=" +
    registry.next_version.to_string(),
  )
  for artifact in registry.artifacts {
    builder.write_string(
      "\n" +
      artifact.id +
      " kind=" +
      registry_artifact_name(artifact.kind) +
      " version=" +
      artifact.version.to_string() +
      " status=" +
      artifact.status +
      " checksum=" +
      artifact.checksum,
    )
  }
  builder.to_string()
}

///|
pub fn registry_csv_header() -> String {
  "id,kind,date,label,status,version,checksum"
}

///|
pub fn registry_csv(artifact : RegistryArtifact) -> String {
  artifact.id +
  "," +
  registry_artifact_name(artifact.kind) +
  "," +
  artifact.date +
  "," +
  artifact.label +
  "," +
  artifact.status +
  "," +
  artifact.version.to_string() +
  "," +
  artifact.checksum
}

///|
pub fn registry_csv_text(registry : OperationalRegistry) -> String {
  let builder = StringBuilder()
  builder.write_string(registry_csv_header())
  for artifact in registry.artifacts {
    builder.write_string("\n")
    builder.write_string(registry_csv(artifact))
  }
  builder.to_string()
}

///|
pub fn registry_artifact_valid(artifact : RegistryArtifact) -> Bool {
  artifact.id != "" &&
  artifact.label != "" &&
  artifact.version > 0 &&
  artifact.content != "" &&
  registry_checksum_valid(artifact)
}

///|
pub fn registry_valid(registry : OperationalRegistry) -> Bool {
  registry.name != "" &&
  registry.next_version > 0 &&
  registry.artifacts.all(artifact => registry_artifact_valid(artifact)) &&
  registry_invalid_artifacts(registry).length() == 0
}
