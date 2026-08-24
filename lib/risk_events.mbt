///|
/// A normalized event emitted by the risk-monitoring pipeline.
pub(all) enum RiskEventKind {
  LoadSpikeEvent
  RecoveryDeclineEvent
  PainEscalationEvent
  RiskEscalationEvent
  RiskImprovementEvent
  QualityIncidentEvent
  MissingDataEvent
  TrainingStreakEvent
  ManualReviewEvent
} derive(Debug, Eq, ToJson)

///|
pub(all) enum RiskEventPriority {
  Routine
  Important
  Urgent
  Critical
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RiskEvent {
  id : String
  date : String
  kind : RiskEventKind
  priority : RiskEventPriority
  score : Double
  subject : String
  evidence : String
  action : String
  resolved : Bool
  source : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct EventWindow {
  start : String
  end : String
  events : Array[RiskEvent]
  critical_count : Int
  urgent_count : Int
  unresolved_count : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) struct EventLog {
  events : Array[RiskEvent]
  window : EventWindow?
  total_score : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
pub fn risk_event_kind_name(kind : RiskEventKind) -> String {
  match kind {
    LoadSpikeEvent => "load_spike"
    RecoveryDeclineEvent => "recovery_decline"
    PainEscalationEvent => "pain_escalation"
    RiskEscalationEvent => "risk_escalation"
    RiskImprovementEvent => "risk_improvement"
    QualityIncidentEvent => "quality_incident"
    MissingDataEvent => "missing_data"
    TrainingStreakEvent => "training_streak"
    ManualReviewEvent => "manual_review"
  }
}

///|
pub fn risk_event_priority_name(priority : RiskEventPriority) -> String {
  match priority {
    Routine => "routine"
    Important => "important"
    Urgent => "urgent"
    Critical => "critical"
  }
}

///|
fn event_priority_rank(priority : RiskEventPriority) -> Int {
  match priority {
    Routine => 0
    Important => 1
    Urgent => 2
    Critical => 3
  }
}

///|
fn event_priority_for_score(score : Double) -> RiskEventPriority {
  if score >= 85.0 {
    Critical
  } else if score >= 60.0 {
    Urgent
  } else if score >= 30.0 {
    Important
  } else {
    Routine
  }
}

///|
fn make_risk_event(
  date : String,
  kind : RiskEventKind,
  score : Double,
  subject : String,
  evidence : String,
  action : String,
  source : String,
) -> RiskEvent {
  {
    id: "event-" + date + "-" + risk_event_kind_name(kind),
    date,
    kind,
    priority: event_priority_for_score(score),
    score: score.max(0.0).min(100.0),
    subject,
    evidence,
    action,
    resolved: false,
    source,
  }
}

///|
fn event_from_alert(alert : MonitoringAlert) -> RiskEvent {
  let score = match alert.severity {
    Info => 10.0
    Watch => 35.0
    Action => 70.0
    Escalate => 100.0
  }
  let kind = match alert.kind {
    RiskScore => RiskEscalationEvent
    Readiness => RecoveryDeclineEvent
    Pain => PainEscalationEvent
    LoadRatio => LoadSpikeEvent
    Sleep | Fatigue => RecoveryDeclineEvent
    Quality | DataConflict => QualityIncidentEvent
    TrainingStreak => TrainingStreakEvent
    MissingTelemetry => MissingDataEvent
  }
  make_risk_event(
    alert.date,
    kind,
    score,
    alert.title,
    alert.explanation,
    alert.recommended_action,
    "daily-monitor",
  )
}

///|
fn event_from_point(
  previous : TimelinePoint?,
  point : TimelinePoint,
) -> RiskEvent? {
  match previous {
    Some(previous) => {
      let delta = point.risk_score - previous.risk_score
      if delta >= 20.0 {
        Some(
          make_risk_event(
            point.date,
            RiskEscalationEvent,
            delta.min(100.0),
            "risk score increased",
            "risk score changed by " + delta.to_string() + " points",
            "inspect the new signals before the next training decision",
            "risk-timeline",
          ),
        )
      } else if delta <= -20.0 {
        Some(
          make_risk_event(
            point.date,
            RiskImprovementEvent,
            (-delta).min(100.0),
            "risk score improved",
            "risk score changed by " + delta.to_string() + " points",
            "retain the current recovery behavior and progress gradually",
            "risk-timeline",
          ),
        )
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn timeline_events(timeline : RiskTimeline) -> Array[RiskEvent] {
  let events = []
  let mut previous : TimelinePoint? = None
  for point in timeline.points {
    match event_from_point(previous, point) {
      Some(event) => events.push(event)
      None => ()
    }
    previous = Some(point)
  }
  events
}

///|
fn event_sort_key(event : RiskEvent) -> Int {
  match parse_date(event.date) {
    Some(date) => date_ordinal(date)
    None => 0
  }
}

///|
fn sort_events(events : Array[RiskEvent]) -> Array[RiskEvent] {
  let sorted = events.copy()
  for i in 1..<sorted.length() {
    let current = sorted[i]
    let mut cursor = i
    while cursor > 0 &&
          event_sort_key(sorted[cursor - 1]) > event_sort_key(current) {
      sorted[cursor] = sorted[cursor - 1]
      cursor -= 1
    }
    sorted[cursor] = current
  }
  sorted
}

///|
fn deduplicate_events(events : Array[RiskEvent]) -> Array[RiskEvent] {
  let output : Array[RiskEvent] = []
  for event in sort_events(events) {
    let mut index = -1
    for i, existing in output {
      if existing.id == event.id {
        index = i
      }
    }
    if index < 0 {
      output.push(event)
    } else if event_priority_rank(event.priority) >
      event_priority_rank(output[index].priority) {
      output[index] = event
    }
  }
  output
}

///|
pub fn events_from_monitoring(run : MonitoringRun) -> Array[RiskEvent] {
  let events = []
  for alert in monitoring_alerts(run) {
    events.push(event_from_alert(alert))
  }
  deduplicate_events(events)
}

///|
pub fn events_from_timeline(timeline : RiskTimeline) -> Array[RiskEvent] {
  deduplicate_events(timeline_events(timeline))
}

///|
pub fn events_from_records(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  thresholds : MonitoringThresholds,
) -> Array[RiskEvent] {
  let monitor_events = events_from_monitoring(
    run_monitoring(records, policy, thresholds),
  )
  let timeline_events = events_from_timeline(build_timeline(records, policy))
  deduplicate_events(monitor_events + timeline_events)
}

///|
fn count_priority(
  events : Array[RiskEvent],
  priority : RiskEventPriority,
) -> Int {
  events.filter(event => event.priority == priority).length()
}

///|
fn event_log_status(events : Array[RiskEvent]) -> String {
  if count_priority(events, Critical) > 0 {
    "critical"
  } else if count_priority(events, Urgent) > 0 {
    "urgent"
  } else if count_priority(events, Important) > 0 {
    "important"
  } else if events.length() > 0 {
    "routine"
  } else {
    "clear"
  }
}

///|
pub fn new_event_log(events : Array[RiskEvent]) -> EventLog {
  let ordered = deduplicate_events(events)
  {
    events: ordered,
    window: None,
    total_score: ordered.fold(init=0.0, (total, event) => total + event.score),
    status: event_log_status(ordered),
  }
}

///|
pub fn event_log_from_records(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  thresholds : MonitoringThresholds,
) -> EventLog {
  new_event_log(events_from_records(records, policy, thresholds))
}

///|
pub fn unresolved_events(log : EventLog) -> Array[RiskEvent] {
  log.events.filter(event => !event.resolved)
}

///|
pub fn resolved_events(log : EventLog) -> Array[RiskEvent] {
  log.events.filter(event => event.resolved)
}

///|
pub fn events_by_kind(log : EventLog, kind : RiskEventKind) -> Array[RiskEvent] {
  log.events.filter(event => event.kind == kind)
}

///|
pub fn events_by_priority(
  log : EventLog,
  priority : RiskEventPriority,
) -> Array[RiskEvent] {
  log.events.filter(event => event.priority == priority)
}

///|
pub fn highest_priority_event(log : EventLog) -> RiskEvent? {
  if log.events.length() == 0 {
    return None
  }
  let mut highest = log.events[0]
  for event in log.events {
    if event_priority_rank(event.priority) >
      event_priority_rank(highest.priority) ||
      (event.priority == highest.priority && event.score > highest.score) {
      highest = event
    }
  }
  Some(highest)
}

///|
pub fn mark_event_resolved(log : EventLog, event_id : String) -> EventLog {
  let events = log.events.copy()
  for index, event in events {
    if event.id == event_id {
      events[index] = {
        id: event.id,
        date: event.date,
        kind: event.kind,
        priority: event.priority,
        score: event.score,
        subject: event.subject,
        evidence: event.evidence,
        action: event.action,
        resolved: true,
        source: event.source,
      }
    }
  }
  let output = new_event_log(events)
  {
    events: output.events,
    window: log.window,
    total_score: output.total_score,
    status: output.status,
  }
}

///|
fn events_in_range(
  events : Array[RiskEvent],
  range : DateRange,
) -> Array[RiskEvent] {
  events.filter(event => {
    match parse_date(event.date) {
      Some(date) => date_is_in_range(date, range)
      None => false
    }
  })
}

///|
pub fn event_window(
  log : EventLog,
  start : String,
  end : String,
) -> EventWindow {
  let events = match (parse_date(start), parse_date(end)) {
    (Some(start), Some(end)) =>
      match make_date_range(start, end) {
        Some(range) => events_in_range(log.events, range)
        None => []
      }
    _ => []
  }
  {
    start,
    end,
    events,
    critical_count: count_priority(events, Critical),
    urgent_count: count_priority(events, Urgent),
    unresolved_count: events.filter(event => !event.resolved).length(),
  }
}

///|
pub fn with_event_window(
  log : EventLog,
  start : String,
  end : String,
) -> EventLog {
  let window = event_window(log, start, end)
  {
    events: log.events,
    window: Some(window),
    total_score: log.total_score,
    status: log.status,
  }
}

///|
pub fn event_streak(log : EventLog, kind : RiskEventKind) -> Int {
  let ordered = sort_events(events_by_kind(log, kind))
  if ordered.length() == 0 {
    return 0
  }
  let mut longest = 1
  let mut current = 1
  for index in 1..<ordered.length() {
    let previous = parse_date(ordered[index - 1].date)
    let current_date = parse_date(ordered[index].date)
    if previous is Some(previous) &&
      current_date is Some(current_date) &&
      days_between(previous, current_date) <= 1 {
      current += 1
      if current > longest {
        longest = current
      }
    } else {
      current = 1
    }
  }
  longest
}

///|
pub fn event_density(log : EventLog, day_count : Int) -> Double {
  if day_count <= 0 {
    0.0
  } else {
    log.events.length().to_double() / day_count.to_double()
  }
}

///|
pub fn event_resolution_ratio(log : EventLog) -> Double {
  if log.events.length() == 0 {
    0.0
  } else {
    resolved_events(log).length().to_double() / log.events.length().to_double()
  }
}

///|
pub fn event_risk_score(log : EventLog) -> Double {
  let unresolved = unresolved_events(log)
  if unresolved.length() == 0 {
    0.0
  } else {
    unresolved.fold(init=0.0, (total, event) => total + event.score) /
    unresolved.length().to_double()
  }
}

///|
pub fn event_recommendation(log : EventLog) -> String {
  match highest_priority_event(log) {
    Some(event) => event.action
    None => "continue the normal monitoring cadence"
  }
}

///|
pub fn risk_event_text(event : RiskEvent) -> String {
  event.date +
  " " +
  risk_event_priority_name(event.priority) +
  " " +
  risk_event_kind_name(event.kind) +
  " score=" +
  event.score.to_string() +
  " subject=" +
  event.subject +
  " action=" +
  event.action
}

///|
pub fn event_log_text(log : EventLog) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "status=" +
    log.status +
    " events=" +
    log.events.length().to_string() +
    " score=" +
    log.total_score.to_string(),
  )
  for event in log.events {
    builder.write_string("\n")
    builder.write_string(risk_event_text(event))
  }
  builder.to_string()
}

///|
pub fn risk_event_csv_header() -> String {
  "id,date,kind,priority,score,subject,resolved,source"
}

///|
pub fn risk_event_csv(event : RiskEvent) -> String {
  event.id +
  "," +
  event.date +
  "," +
  risk_event_kind_name(event.kind) +
  "," +
  risk_event_priority_name(event.priority) +
  "," +
  event.score.to_string() +
  "," +
  event.subject +
  "," +
  event.resolved.to_string() +
  "," +
  event.source
}

///|
pub fn event_log_csv(log : EventLog) -> String {
  let builder = StringBuilder()
  builder.write_string(risk_event_csv_header())
  for event in log.events {
    builder.write_string("\n")
    builder.write_string(risk_event_csv(event))
  }
  builder.to_string()
}

///|
pub fn event_log_valid(log : EventLog) -> Bool {
  let mut valid = true
  for event in log.events {
    if event.id == "" ||
      event.date == "" ||
      event.subject == "" ||
      event.action == "" ||
      event.score.is_nan() {
      valid = false
    }
  }
  valid
}

///|
pub fn event_kind_catalog() -> Array[String] {
  [
    risk_event_kind_name(LoadSpikeEvent),
    risk_event_kind_name(RecoveryDeclineEvent),
    risk_event_kind_name(PainEscalationEvent),
    risk_event_kind_name(RiskEscalationEvent),
    risk_event_kind_name(RiskImprovementEvent),
    risk_event_kind_name(QualityIncidentEvent),
    risk_event_kind_name(MissingDataEvent),
    risk_event_kind_name(TrainingStreakEvent),
    risk_event_kind_name(ManualReviewEvent),
  ]
}
