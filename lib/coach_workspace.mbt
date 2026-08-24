///|
/// A compact operational workspace for a coach or team reviewer.
pub(all) struct CoachKpi {
  name : String
  value : Double
  unit : String
  status : String
  target : Double
  action : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct CoachQueueItem {
  id : String
  date : String
  category : String
  priority : RiskEventPriority
  title : String
  evidence : String
  action : String
  acknowledged : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct CoachWorkspace {
  latest : ComprehensiveAssessment?
  kpis : Array[CoachKpi]
  queue : Array[CoachQueueItem]
  monitoring : MonitoringSummary
  events : EventLog
  interventions : InterventionPlan?
  status : String
  generated_for : String
} derive(Debug, Eq, ToJson)

///|
fn kpi_status(
  value : Double,
  target : Double,
  lower_is_better : Bool,
) -> String {
  if lower_is_better {
    if value <= target {
      "good"
    } else if value <= target * 1.25 {
      "watch"
    } else {
      "action"
    }
  } else if value >= target {
    "good"
  } else if value >= target * 0.75 {
    "watch"
  } else {
    "action"
  }
}

///|
fn kpi(
  name : String,
  value : Double,
  unit : String,
  target : Double,
  lower_is_better : Bool,
  action : String,
) -> CoachKpi {
  {
    name,
    value,
    unit,
    status: kpi_status(value, target, lower_is_better),
    target,
    action,
  }
}

///|
fn workspace_kpis(
  assessment : ComprehensiveAssessment?,
  monitoring : MonitoringSummary,
  events : EventLog,
) -> Array[CoachKpi] {
  match assessment {
    Some(assessment) =>
      [
        kpi(
          "risk_score",
          assessment.risk_score,
          "points",
          40.0,
          true,
          "inspect current signals",
        ),
        kpi(
          "readiness",
          assessment.readiness_score,
          "points",
          70.0,
          false,
          "protect recovery",
        ),
        kpi(
          "acute_chronic_ratio",
          assessment.load.acwr,
          "ratio",
          1.5,
          true,
          "hold load progression",
        ),
        kpi(
          "recovery_score",
          assessment.recovery.recovery_score,
          "points",
          70.0,
          false,
          "complete recovery routine",
        ),
        kpi(
          "quality_score",
          assessment.quality.score,
          "points",
          80.0,
          false,
          "repair telemetry",
        ),
        kpi(
          "open_events",
          unresolved_events(events).length().to_double(),
          "events",
          0.0,
          true,
          "review event queue",
        ),
        kpi(
          "action_days",
          monitoring.actionable_day_count.to_double(),
          "days",
          0.0,
          true,
          "review intervention plan",
        ),
      ]
    None =>
      [
        kpi(
          "risk_score", 0.0, "points", 40.0, true, "collect a valid assessment",
        ),
        kpi("readiness", 0.0, "points", 70.0, false, "collect recovery data"),
      ]
  }
}

///|
fn queue_priority(alert : MonitoringAlert) -> RiskEventPriority {
  match alert.severity {
    Info => Routine
    Watch => Important
    Action => Urgent
    Escalate => Critical
  }
}

///|
fn queue_from_monitoring(run : MonitoringRun) -> Array[CoachQueueItem] {
  let queue = []
  for alert in monitoring_alerts(run) {
    queue.push({
      id: alert.id,
      date: alert.date,
      category: monitor_alert_kind_name(alert.kind),
      priority: queue_priority(alert),
      title: alert.title,
      evidence: alert.explanation,
      action: alert.recommended_action,
      acknowledged: false,
    })
  }
  queue
}

///|
fn queue_from_events(log : EventLog) -> Array[CoachQueueItem] {
  unresolved_events(log).map(event => {
    id: event.id,
    date: event.date,
    category: risk_event_kind_name(event.kind),
    priority: event.priority,
    title: event.subject,
    evidence: event.evidence,
    action: event.action,
    acknowledged: false,
  })
}

///|
fn unique_queue(queue : Array[CoachQueueItem]) -> Array[CoachQueueItem] {
  let output : Array[CoachQueueItem] = []
  for item in queue {
    if output.filter(existing => existing.id == item.id).length() == 0 {
      output.push(item)
    }
  }
  output
}

///|
fn workspace_status(
  queue : Array[CoachQueueItem],
  assessment : ComprehensiveAssessment?,
) -> String {
  if queue.any(item => item.priority == Critical) {
    "critical"
  } else if queue.any(item => item.priority == Urgent) {
    "urgent"
  } else if assessment is Some(value) && value.risk_level == Medium {
    "watch"
  } else if assessment is Some(value) && value.risk_level == Low {
    "stable"
  } else {
    "needs_data"
  }
}

///|
pub fn build_coach_workspace(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  thresholds : MonitoringThresholds,
) -> CoachWorkspace {
  let assessment = assess_latest(records, policy)
  let monitoring = run_monitoring(records, policy, thresholds)
  let events = event_log_from_records(records, policy, thresholds)
  let queue = unique_queue(
    queue_from_monitoring(monitoring) + queue_from_events(events),
  )
  {
    latest: assessment,
    kpis: workspace_kpis(assessment, monitoring.summary, events),
    queue,
    monitoring: monitoring.summary,
    events,
    interventions: match assessment {
      Some(value) => Some(build_intervention_plan(value))
      None => None
    },
    status: workspace_status(queue, assessment),
    generated_for: if records.length() == 0 {
      ""
    } else {
      sort_records_by_date(records)[records.length() - 1].date
    },
  }
}

///|
pub fn workspace_queue(
  workspace : CoachWorkspace,
  priority : RiskEventPriority,
) -> Array[CoachQueueItem] {
  workspace.queue.filter(item => item.priority == priority)
}

///|
pub fn workspace_open_queue(
  workspace : CoachWorkspace,
) -> Array[CoachQueueItem] {
  workspace.queue.filter(item => !item.acknowledged)
}

///|
pub fn workspace_acknowledge(
  workspace : CoachWorkspace,
  id : String,
) -> CoachWorkspace {
  let queue = workspace.queue.map(item => {
    if item.id == id {
      {
        id: item.id,
        date: item.date,
        category: item.category,
        priority: item.priority,
        title: item.title,
        evidence: item.evidence,
        action: item.action,
        acknowledged: true,
      }
    } else {
      item
    }
  })
  {
    latest: workspace.latest,
    kpis: workspace.kpis,
    queue,
    monitoring: workspace.monitoring,
    events: workspace.events,
    interventions: workspace.interventions,
    status: workspace.status,
    generated_for: workspace.generated_for,
  }
}

///|
pub fn workspace_kpi(workspace : CoachWorkspace, name : String) -> CoachKpi? {
  for item in workspace.kpis {
    if item.name == name {
      return Some(item)
    }
  }
  None
}

///|
pub fn workspace_action_count(workspace : CoachWorkspace) -> Int {
  workspace.queue
  .filter(item => item.priority == Urgent || item.priority == Critical)
  .length()
}

///|
pub fn workspace_ready_for_progression(workspace : CoachWorkspace) -> Bool {
  workspace.status == "stable" && workspace_open_queue(workspace).length() == 0
}

///|
pub fn workspace_recommended_action(workspace : CoachWorkspace) -> String {
  if workspace.status == "critical" {
    "pause progression and route the critical queue"
  } else if workspace.status == "urgent" {
    "apply the highest priority intervention"
  } else if workspace.status == "watch" {
    "hold progression and collect another check-in"
  } else if workspace.status == "needs_data" {
    "collect enough valid telemetry"
  } else {
    "continue planned progression"
  }
}

///|
pub fn coach_kpi_text(kpi : CoachKpi) -> String {
  kpi.name +
  "=" +
  kpi.value.to_string() +
  kpi.unit +
  " target=" +
  kpi.target.to_string() +
  " status=" +
  kpi.status +
  " action=" +
  kpi.action
}

///|
pub fn queue_item_text(item : CoachQueueItem) -> String {
  item.date +
  " " +
  risk_event_priority_name(item.priority) +
  " " +
  item.category +
  " " +
  item.title +
  " action=" +
  item.action
}

///|
pub fn workspace_text(workspace : CoachWorkspace) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "status=" +
    workspace.status +
    " generated_for=" +
    workspace.generated_for +
    " queue=" +
    workspace.queue.length().to_string(),
  )
  builder.write_string(" action=" + workspace_recommended_action(workspace))
  builder.write_string("\nKPIs")
  for kpi in workspace.kpis {
    builder.write_string("\n" + coach_kpi_text(kpi))
  }
  builder.write_string("\nQueue")
  for item in workspace_open_queue(workspace) {
    builder.write_string("\n" + queue_item_text(item))
  }
  builder.to_string()
}

///|
pub fn coach_kpi_csv_header() -> String {
  "name,value,unit,status,target,action"
}

///|
pub fn coach_kpi_csv(kpi : CoachKpi) -> String {
  kpi.name +
  "," +
  kpi.value.to_string() +
  "," +
  kpi.unit +
  "," +
  kpi.status +
  "," +
  kpi.target.to_string() +
  "," +
  kpi.action
}

///|
pub fn workspace_queue_csv_header() -> String {
  "id,date,category,priority,title,acknowledged,action"
}

///|
pub fn workspace_queue_csv(item : CoachQueueItem) -> String {
  item.id +
  "," +
  item.date +
  "," +
  item.category +
  "," +
  risk_event_priority_name(item.priority) +
  "," +
  item.title +
  "," +
  item.acknowledged.to_string() +
  "," +
  item.action
}

///|
pub fn workspace_csv(workspace : CoachWorkspace) -> String {
  let builder = StringBuilder()
  builder.write_string(workspace_queue_csv_header())
  for item in workspace.queue {
    builder.write_string("\n")
    builder.write_string(workspace_queue_csv(item))
  }
  builder.to_string()
}

///|
pub fn workspace_valid(workspace : CoachWorkspace) -> Bool {
  workspace.generated_for != "" &&
  workspace.queue.all(item => item.id != "" && item.title != "") &&
  workspace.kpis.all(item => item.name != "" && item.value >= 0.0)
}
