///|
/// Event timeline views keep risk events useful for triage and follow-up.
pub(all) struct EventTimelinePoint {
  date : String
  event_count : Int
  total_score : Double
  critical_count : Int
  urgent_count : Int
  unresolved_count : Int
  dominant_kind : String
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct EventTimeline {
  points : Array[EventTimelinePoint]
  total_events : Int
  total_score : Double
  critical_days : Int
  urgent_days : Int
  unresolved_days : Int
  peak_date : String
  peak_score : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct EventTimelineComparison {
  left_date : String
  right_date : String
  score_change : Double
  event_change : Int
  unresolved_change : Int
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
fn event_timeline_point(
  events : Array[RiskEvent],
  date : String,
) -> EventTimelinePoint {
  let values = events.filter(event => event.date == date)
  let critical = values.filter(event => event.priority == Critical).length()
  let urgent = values.filter(event => event.priority == Urgent).length()
  let unresolved = values.filter(event => !event.resolved).length()
  let kinds = values.map(event => risk_event_kind_name(event.kind))
  let dominant = if kinds.length() == 0 { "none" } else { kinds[0] }
  {
    date,
    event_count: values.length(),
    total_score: values.fold(init=0.0, (total, event) => total + event.score),
    critical_count: critical,
    urgent_count: urgent,
    unresolved_count: unresolved,
    dominant_kind: dominant,
    status: if critical > 0 {
      "critical"
    } else if urgent > 0 {
      "urgent"
    } else if values.length() > 0 {
      "open"
    } else {
      "clear"
    },
  }
}

///|
pub fn build_event_timeline(events : Array[RiskEvent]) -> EventTimeline {
  let dates = []
  for event in events {
    if !dates.contains(event.date) {
      dates.push(event.date)
    }
  }
  let points = dates.map(date => event_timeline_point(events, date))
  let mut peak_date = ""
  let mut peak_score = 0.0
  for point in points {
    if point.total_score > peak_score {
      peak_date = point.date
      peak_score = point.total_score
    }
  }
  {
    points,
    total_events: events.length(),
    total_score: events.fold(init=0.0, (total, event) => total + event.score),
    critical_days: points.filter(point => point.critical_count > 0).length(),
    urgent_days: points.filter(point => point.urgent_count > 0).length(),
    unresolved_days: points.filter(point => point.unresolved_count > 0).length(),
    peak_date,
    peak_score,
    status: if points.any(point => point.status == "critical") {
      "critical"
    } else if points.any(point => point.status == "urgent") {
      "urgent"
    } else if points.length() > 0 {
      "open"
    } else {
      "clear"
    },
  }
}

///|
pub fn event_timeline_from_log(log : EventLog) -> EventTimeline {
  build_event_timeline(log.events)
}

///|
pub fn event_timeline_points(
  timeline : EventTimeline,
) -> Array[EventTimelinePoint] {
  timeline.points
}

///|
pub fn event_timeline_point_by_date(
  timeline : EventTimeline,
  date : String,
) -> EventTimelinePoint? {
  for point in timeline.points {
    if point.date == date {
      return Some(point)
    }
  }
  None
}

///|
pub fn event_timeline_dates(timeline : EventTimeline) -> Array[String] {
  timeline.points.map(point => point.date)
}

///|
pub fn event_timeline_counts(timeline : EventTimeline) -> Array[Int] {
  timeline.points.map(point => point.event_count)
}

///|
pub fn event_timeline_scores(timeline : EventTimeline) -> Array[Double] {
  timeline.points.map(point => point.total_score)
}

///|
pub fn event_timeline_unresolved(timeline : EventTimeline) -> Array[Int] {
  timeline.points.map(point => point.unresolved_count)
}

///|
pub fn event_timeline_critical_points(
  timeline : EventTimeline,
) -> Array[EventTimelinePoint] {
  timeline.points.filter(point => point.critical_count > 0)
}

///|
pub fn event_timeline_urgent_points(
  timeline : EventTimeline,
) -> Array[EventTimelinePoint] {
  timeline.points.filter(point => point.urgent_count > 0)
}

///|
pub fn event_timeline_open_points(
  timeline : EventTimeline,
) -> Array[EventTimelinePoint] {
  timeline.points.filter(point => point.unresolved_count > 0)
}

///|
pub fn event_timeline_clear_points(
  timeline : EventTimeline,
) -> Array[EventTimelinePoint] {
  timeline.points.filter(point => point.event_count == 0)
}

///|
pub fn event_timeline_count(timeline : EventTimeline) -> Int {
  timeline.points.length()
}

///|
pub fn event_timeline_event_count(timeline : EventTimeline) -> Int {
  timeline.total_events
}

///|
pub fn event_timeline_score(timeline : EventTimeline) -> Double {
  timeline.total_score
}

///|
pub fn event_timeline_average_score(timeline : EventTimeline) -> Double {
  mean_load_values(event_timeline_scores(timeline))
}

///|
pub fn event_timeline_peak_date(timeline : EventTimeline) -> String {
  timeline.peak_date
}

///|
pub fn event_timeline_peak_score(timeline : EventTimeline) -> Double {
  timeline.peak_score
}

///|
pub fn event_timeline_status(timeline : EventTimeline) -> String {
  timeline.status
}

///|
pub fn event_timeline_actionable(timeline : EventTimeline) -> Bool {
  timeline.status == "critical" ||
  timeline.status == "urgent" ||
  timeline.unresolved_days > 0
}

///|
pub fn event_timeline_requires_review(timeline : EventTimeline) -> Bool {
  timeline.critical_days > 0 ||
  timeline.urgent_days > 0 ||
  timeline.unresolved_days > 0
}

///|
pub fn event_timeline_priority(timeline : EventTimeline) -> Int {
  if timeline.status == "critical" {
    3
  } else if timeline.status == "urgent" {
    2
  } else if timeline.status == "open" {
    1
  } else {
    0
  }
}

///|
pub fn event_timeline_review_days(timeline : EventTimeline) -> Int {
  if timeline.status == "critical" {
    0
  } else if timeline.status == "urgent" {
    1
  } else if timeline.status == "open" {
    3
  } else {
    7
  }
}

///|
pub fn event_timeline_review_label(timeline : EventTimeline) -> String {
  "review_in_" + event_timeline_review_days(timeline).to_string() + "_days"
}

///|
pub fn event_timeline_kind_counts(events : Array[RiskEvent]) -> Array[Int] {
  event_timeline_kinds().map(kind => {
    events.filter(event => event.kind == kind).length()
  })
}

///|
pub fn event_timeline_kinds() -> Array[RiskEventKind] {
  [
    LoadSpikeEvent,
    RecoveryDeclineEvent,
    PainEscalationEvent,
    RiskEscalationEvent,
    RiskImprovementEvent,
    QualityIncidentEvent,
    MissingDataEvent,
    TrainingStreakEvent,
    ManualReviewEvent,
  ]
}

///|
pub fn event_timeline_kind_names() -> Array[String] {
  event_timeline_kinds().map(kind => risk_event_kind_name(kind))
}

///|
pub fn event_timeline_priority_counts(events : Array[RiskEvent]) -> Array[Int] {
  [
    events.filter(event => event.priority == Routine).length(),
    events.filter(event => event.priority == Important).length(),
    events.filter(event => event.priority == Urgent).length(),
    events.filter(event => event.priority == Critical).length(),
  ]
}

///|
pub fn event_timeline_unresolved_events(
  events : Array[RiskEvent],
) -> Array[RiskEvent] {
  events.filter(event => !event.resolved)
}

///|
pub fn event_timeline_resolved_events(
  events : Array[RiskEvent],
) -> Array[RiskEvent] {
  events.filter(event => event.resolved)
}

///|
pub fn event_timeline_resolution_rate(events : Array[RiskEvent]) -> Double {
  if events.length() == 0 {
    0.0
  } else {
    event_timeline_resolved_events(events).length().to_double() /
    events.length().to_double() *
    100.0
  }
}

///|
pub fn event_timeline_event_rate(timeline : EventTimeline) -> Double {
  if timeline.points.length() == 0 {
    0.0
  } else {
    timeline.total_events.to_double() / timeline.points.length().to_double()
  }
}

///|
pub fn event_timeline_unresolved_rate(timeline : EventTimeline) -> Double {
  if timeline.total_events == 0 {
    0.0
  } else {
    timeline.unresolved_days.to_double() /
    timeline.total_events.to_double() *
    100.0
  }
}

///|
pub fn event_timeline_trend(timeline : EventTimeline) -> LoadTrend {
  load_trend(event_timeline_scores(timeline), 0.1)
}

///|
pub fn event_timeline_valid_point(point : EventTimelinePoint) -> Bool {
  point.date != "" &&
  point.event_count >= 0 &&
  point.total_score >= 0.0 &&
  point.critical_count >= 0 &&
  point.urgent_count >= 0 &&
  point.unresolved_count >= 0 &&
  point.critical_count + point.urgent_count <= point.event_count
}

///|
pub fn event_timeline_valid(timeline : EventTimeline) -> Bool {
  timeline.total_events >= 0 &&
  timeline.total_score >= 0.0 &&
  timeline.critical_days >= 0 &&
  timeline.urgent_days >= 0 &&
  timeline.unresolved_days >= 0 &&
  timeline.points.all(point => event_timeline_valid_point(point))
}

///|
pub fn event_timeline_text(timeline : EventTimeline) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "status=" +
    timeline.status +
    " points=" +
    timeline.points.length().to_string() +
    " events=" +
    timeline.total_events.to_string() +
    " total_score=" +
    timeline.total_score.to_string() +
    " critical_days=" +
    timeline.critical_days.to_string() +
    " urgent_days=" +
    timeline.urgent_days.to_string() +
    " unresolved_days=" +
    timeline.unresolved_days.to_string() +
    " peak=" +
    timeline.peak_date +
    ":" +
    timeline.peak_score.to_string(),
  )
  for point in timeline.points {
    builder.write_string(
      "\n" +
      point.date +
      " events=" +
      point.event_count.to_string() +
      " score=" +
      point.total_score.to_string() +
      " critical=" +
      point.critical_count.to_string() +
      " urgent=" +
      point.urgent_count.to_string() +
      " unresolved=" +
      point.unresolved_count.to_string() +
      " dominant=" +
      point.dominant_kind,
    )
  }
  builder.to_string()
}

///|
pub fn event_timeline_point_text(point : EventTimelinePoint) -> String {
  point.date +
  " events=" +
  point.event_count.to_string() +
  " score=" +
  point.total_score.to_string() +
  " critical=" +
  point.critical_count.to_string() +
  " urgent=" +
  point.urgent_count.to_string() +
  " unresolved=" +
  point.unresolved_count.to_string() +
  " status=" +
  point.status
}

///|
pub fn event_timeline_csv_header() -> String {
  "date,event_count,total_score,critical_count,urgent_count,unresolved_count,dominant_kind,status"
}

///|
pub fn event_timeline_point_csv(point : EventTimelinePoint) -> String {
  point.date +
  "," +
  point.event_count.to_string() +
  "," +
  point.total_score.to_string() +
  "," +
  point.critical_count.to_string() +
  "," +
  point.urgent_count.to_string() +
  "," +
  point.unresolved_count.to_string() +
  "," +
  point.dominant_kind +
  "," +
  point.status
}

///|
pub fn event_timeline_csv(timeline : EventTimeline) -> String {
  let builder = StringBuilder()
  builder.write_string(event_timeline_csv_header())
  for point in timeline.points {
    builder.write_string("\n" + event_timeline_point_csv(point))
  }
  builder.to_string()
}

///|
pub fn event_timeline_compare(
  left : EventTimelinePoint,
  right : EventTimelinePoint,
) -> EventTimelineComparison {
  {
    left_date: left.date,
    right_date: right.date,
    score_change: right.total_score - left.total_score,
    event_change: right.event_count - left.event_count,
    unresolved_change: right.unresolved_count - left.unresolved_count,
    conclusion: if right.total_score < left.total_score &&
      right.unresolved_count <= left.unresolved_count {
      "event burden improved"
    } else if right.total_score > left.total_score ||
      right.unresolved_count > left.unresolved_count {
      "event burden increased"
    } else {
      "event burden is stable"
    },
  }
}

///|
pub fn event_timeline_compare_latest(
  timeline : EventTimeline,
) -> EventTimelineComparison? {
  if timeline.points.length() < 2 {
    None
  } else {
    Some(
      event_timeline_compare(
        timeline.points[timeline.points.length() - 2],
        timeline.points[timeline.points.length() - 1],
      ),
    )
  }
}

///|
pub fn event_timeline_comparison_text(
  comparison : EventTimelineComparison,
) -> String {
  comparison.left_date +
  " -> " +
  comparison.right_date +
  " score_change=" +
  comparison.score_change.to_string() +
  " event_change=" +
  comparison.event_change.to_string() +
  " unresolved_change=" +
  comparison.unresolved_change.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn event_timeline_checksum(timeline : EventTimeline) -> String {
  let mut value = timeline.total_events + timeline.points.length()
  for character in event_timeline_text(timeline) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn event_timeline_reproducible(
  left : EventTimeline,
  right : EventTimeline,
) -> Bool {
  event_timeline_checksum(left) == event_timeline_checksum(right)
}

///|
pub fn event_timeline_recommendation(timeline : EventTimeline) -> String {
  if timeline.status == "critical" {
    "route critical events for immediate review"
  } else if timeline.status == "urgent" {
    "complete urgent event follow-up before progression"
  } else if timeline.status == "open" {
    "close unresolved events in the next review"
  } else {
    "continue event monitoring"
  }
}

///|
pub fn event_timeline_contract(timeline : EventTimeline) -> Array[String] {
  [
    timeline.status,
    timeline.total_events.to_string(),
    timeline.peak_date,
    timeline.peak_score.to_string(),
    event_timeline_review_label(timeline),
    event_timeline_recommendation(timeline),
    event_timeline_valid(timeline).to_string(),
    event_timeline_checksum(timeline),
  ]
}
