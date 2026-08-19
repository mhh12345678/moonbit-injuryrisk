///|
/// Outcome window views complement intervention outcome tracking with trend metrics.
pub(all) struct OutcomeWindowViewPoint {
  date : String
  risk : Double
  readiness : Double
  quality : Double
  load : Double
  recovery : Double
  pain : Double
  fatigue : Double
  action_required : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct OutcomeWindowView {
  start_date : String
  end_date : String
  points : Array[OutcomeWindowViewPoint]
  average_risk : Double
  average_readiness : Double
  average_quality : Double
  average_load : Double
  average_recovery : Double
  average_pain : Double
  improvement_score : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct OutcomeWindowViewDelta {
  left_date : String
  right_date : String
  risk_change : Double
  readiness_change : Double
  quality_change : Double
  load_change : Double
  recovery_change : Double
  pain_change : Double
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
fn outcome_window_view_point(
  assessment : ComprehensiveAssessment,
) -> OutcomeWindowViewPoint {
  {
    date: assessment.date,
    risk: assessment.risk_score,
    readiness: assessment.readiness_score,
    quality: assessment.quality.score,
    load: assessment.load.average_load,
    recovery: assessment.recovery.recovery_score,
    pain: assessment.recovery.average_pain,
    fatigue: assessment.recovery.average_fatigue,
    action_required: assessment_is_actionable(assessment),
  }
}

///|
pub fn outcome_window_view_points(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> Array[OutcomeWindowViewPoint] {
  let points = []
  for record in sort_records_by_date(records) {
    match assess_comprehensive(records, record.date, policy) {
      Some(assessment) => points.push(outcome_window_view_point(assessment))
      None => ()
    }
  }
  points
}

///|
fn outcome_window_view_improvement(
  points : Array[OutcomeWindowViewPoint],
) -> Double {
  if points.length() < 2 {
    0.0
  } else {
    let first = points[0]
    let last = points[points.length() - 1]
    (
      first.risk -
      last.risk +
      (last.readiness - first.readiness) +
      (last.recovery - first.recovery) +
      (first.pain - last.pain) * 2.0
    ) /
    5.0
  }
}

///|
pub fn build_outcome_window_view(
  points : Array[OutcomeWindowViewPoint],
) -> OutcomeWindowView {
  let start = if points.length() == 0 { "" } else { points[0].date }
  let end = if points.length() == 0 {
    ""
  } else {
    points[points.length() - 1].date
  }
  let improvement = outcome_window_view_improvement(points)
  {
    start_date: start,
    end_date: end,
    points,
    average_risk: mean_load_values(points.map(point => point.risk)),
    average_readiness: mean_load_values(points.map(point => point.readiness)),
    average_quality: mean_load_values(points.map(point => point.quality)),
    average_load: mean_load_values(points.map(point => point.load)),
    average_recovery: mean_load_values(points.map(point => point.recovery)),
    average_pain: mean_load_values(points.map(point => point.pain)),
    improvement_score: improvement,
    status: if points.length() == 0 {
      "empty"
    } else if improvement >= 10.0 {
      "improving"
    } else if improvement <= -10.0 {
      "worsening"
    } else {
      "stable"
    },
  }
}

///|
pub fn outcome_window_view_for_records(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> OutcomeWindowView {
  build_outcome_window_view(outcome_window_view_points(records, policy))
}

///|
pub fn outcome_window_view_point_by_date(
  view : OutcomeWindowView,
  date : String,
) -> OutcomeWindowViewPoint? {
  for point in view.points {
    if point.date == date {
      return Some(point)
    }
  }
  None
}

///|
pub fn outcome_window_view_points_all(
  view : OutcomeWindowView,
) -> Array[OutcomeWindowViewPoint] {
  view.points
}

///|
pub fn outcome_window_view_dates(view : OutcomeWindowView) -> Array[String] {
  view.points.map(point => point.date)
}

///|
pub fn outcome_window_view_risks(view : OutcomeWindowView) -> Array[Double] {
  view.points.map(point => point.risk)
}

///|
pub fn outcome_window_view_readiness(view : OutcomeWindowView) -> Array[Double] {
  view.points.map(point => point.readiness)
}

///|
pub fn outcome_window_view_quality(view : OutcomeWindowView) -> Array[Double] {
  view.points.map(point => point.quality)
}

///|
pub fn outcome_window_view_loads(view : OutcomeWindowView) -> Array[Double] {
  view.points.map(point => point.load)
}

///|
pub fn outcome_window_view_recovery(view : OutcomeWindowView) -> Array[Double] {
  view.points.map(point => point.recovery)
}

///|
pub fn outcome_window_view_pain(view : OutcomeWindowView) -> Array[Double] {
  view.points.map(point => point.pain)
}

///|
pub fn outcome_window_view_fatigue(view : OutcomeWindowView) -> Array[Double] {
  view.points.map(point => point.fatigue)
}

///|
pub fn outcome_window_view_action_dates(
  view : OutcomeWindowView,
) -> Array[String] {
  view.points.filter(point => point.action_required).map(point => point.date)
}

///|
pub fn outcome_window_view_count(view : OutcomeWindowView) -> Int {
  view.points.length()
}

///|
pub fn outcome_window_view_action_count(view : OutcomeWindowView) -> Int {
  view.points.filter(point => point.action_required).length()
}

///|
pub fn outcome_window_view_action_percent(view : OutcomeWindowView) -> Double {
  if view.points.length() == 0 {
    0.0
  } else {
    outcome_window_view_action_count(view).to_double() /
    view.points.length().to_double() *
    100.0
  }
}

///|
pub fn outcome_window_view_risk_trend(view : OutcomeWindowView) -> LoadTrend {
  load_trend(outcome_window_view_risks(view), 0.1)
}

///|
pub fn outcome_window_view_readiness_trend(
  view : OutcomeWindowView,
) -> LoadTrend {
  load_trend(outcome_window_view_readiness(view), 0.1)
}

///|
pub fn outcome_window_view_recovery_trend(
  view : OutcomeWindowView,
) -> LoadTrend {
  load_trend(outcome_window_view_recovery(view), 0.1)
}

///|
pub fn outcome_window_view_quality_trend(view : OutcomeWindowView) -> LoadTrend {
  load_trend(outcome_window_view_quality(view), 0.1)
}

///|
pub fn outcome_window_view_latest(
  view : OutcomeWindowView,
) -> OutcomeWindowViewPoint? {
  if view.points.length() == 0 {
    None
  } else {
    Some(view.points[view.points.length() - 1])
  }
}

///|
pub fn outcome_window_view_first(
  view : OutcomeWindowView,
) -> OutcomeWindowViewPoint? {
  if view.points.length() == 0 {
    None
  } else {
    Some(view.points[0])
  }
}

///|
pub fn outcome_window_view_latest_risk(view : OutcomeWindowView) -> Double {
  match outcome_window_view_latest(view) {
    Some(point) => point.risk
    None => 0.0
  }
}

///|
pub fn outcome_window_view_latest_readiness(view : OutcomeWindowView) -> Double {
  match outcome_window_view_latest(view) {
    Some(point) => point.readiness
    None => 0.0
  }
}

///|
pub fn outcome_window_view_latest_recovery(view : OutcomeWindowView) -> Double {
  match outcome_window_view_latest(view) {
    Some(point) => point.recovery
    None => 0.0
  }
}

///|
pub fn outcome_window_view_latest_quality(view : OutcomeWindowView) -> Double {
  match outcome_window_view_latest(view) {
    Some(point) => point.quality
    None => 0.0
  }
}

///|
pub fn outcome_window_view_status(view : OutcomeWindowView) -> String {
  view.status
}

///|
pub fn outcome_window_view_improving(view : OutcomeWindowView) -> Bool {
  view.status == "improving"
}

///|
pub fn outcome_window_view_worsening(view : OutcomeWindowView) -> Bool {
  view.status == "worsening"
}

///|
pub fn outcome_window_view_requires_review(view : OutcomeWindowView) -> Bool {
  view.status == "worsening" ||
  outcome_window_view_action_count(view) > view.points.length() / 2
}

///|
pub fn outcome_window_view_recommendation(view : OutcomeWindowView) -> String {
  if view.status == "worsening" {
    "reduce exposure and review outcomes"
  } else if outcome_window_view_requires_review(view) {
    "keep the next review close"
  } else if view.status == "improving" {
    "continue the current progression cautiously"
  } else if view.status == "stable" {
    "continue monitoring"
  } else {
    "collect more observations"
  }
}

///|
pub fn outcome_window_view_point_valid(point : OutcomeWindowViewPoint) -> Bool {
  point.date != "" &&
  point.risk >= 0.0 &&
  point.risk <= 100.0 &&
  point.readiness >= 0.0 &&
  point.readiness <= 100.0 &&
  point.quality >= 0.0 &&
  point.quality <= 100.0 &&
  point.load >= 0.0 &&
  point.recovery >= 0.0 &&
  point.recovery <= 100.0 &&
  point.pain >= 0.0 &&
  point.pain <= 10.0 &&
  point.fatigue >= 0.0 &&
  point.fatigue <= 10.0
}

///|
pub fn outcome_window_view_valid(view : OutcomeWindowView) -> Bool {
  (view.points.length() == 0 && view.start_date == "" && view.end_date == "") ||
  (
    view.points.length() > 0 &&
    view.start_date != "" &&
    view.end_date != "" &&
    view.points.all(point => outcome_window_view_point_valid(point)) &&
    view.average_risk >= 0.0 &&
    view.average_risk <= 100.0 &&
    view.average_readiness >= 0.0 &&
    view.average_readiness <= 100.0 &&
    view.average_quality >= 0.0 &&
    view.average_quality <= 100.0 &&
    view.average_load >= 0.0 &&
    view.average_recovery >= 0.0 &&
    view.average_recovery <= 100.0
  )
}

///|
pub fn outcome_window_view_metric(
  view : OutcomeWindowView,
  name : String,
) -> Double {
  match name {
    "risk" => view.average_risk
    "readiness" => view.average_readiness
    "quality" => view.average_quality
    "load" => view.average_load
    "recovery" => view.average_recovery
    "pain" => view.average_pain
    "improvement" => view.improvement_score
    _ => 0.0
  }
}

///|
pub fn outcome_window_view_metric_names() -> Array[String] {
  ["risk", "readiness", "quality", "load", "recovery", "pain", "improvement"]
}

///|
pub fn outcome_window_view_projection(
  view : OutcomeWindowView,
  name : String,
) -> Array[Double] {
  view.points.map(point => {
    match name {
      "risk" => point.risk
      "readiness" => point.readiness
      "quality" => point.quality
      "load" => point.load
      "recovery" => point.recovery
      "pain" => point.pain
      "fatigue" => point.fatigue
      _ => 0.0
    }
  })
}

///|
pub fn outcome_window_view_projection_average(
  view : OutcomeWindowView,
  name : String,
) -> Double {
  mean_load_values(outcome_window_view_projection(view, name))
}

///|
pub fn outcome_window_view_projection_minimum(
  view : OutcomeWindowView,
  name : String,
) -> Double {
  minimum_load_values(outcome_window_view_projection(view, name))
}

///|
pub fn outcome_window_view_projection_maximum(
  view : OutcomeWindowView,
  name : String,
) -> Double {
  maximum_load_values(outcome_window_view_projection(view, name))
}

///|
pub fn outcome_window_view_projection_deviation(
  view : OutcomeWindowView,
  name : String,
) -> Double {
  standard_deviation_values(outcome_window_view_projection(view, name))
}

///|
pub fn outcome_window_view_compare(
  left : OutcomeWindowView,
  right : OutcomeWindowView,
) -> OutcomeWindowViewDelta {
  {
    left_date: left.end_date,
    right_date: right.end_date,
    risk_change: right.average_risk - left.average_risk,
    readiness_change: right.average_readiness - left.average_readiness,
    quality_change: right.average_quality - left.average_quality,
    load_change: right.average_load - left.average_load,
    recovery_change: right.average_recovery - left.average_recovery,
    pain_change: right.average_pain - left.average_pain,
    conclusion: if right.average_risk < left.average_risk &&
      right.average_readiness > left.average_readiness {
      "outcomes improved"
    } else if right.average_risk > left.average_risk ||
      right.average_readiness < left.average_readiness {
      "outcomes worsened"
    } else {
      "outcomes are stable"
    },
  }
}

///|
pub fn outcome_window_view_delta_text(delta : OutcomeWindowViewDelta) -> String {
  delta.left_date +
  " -> " +
  delta.right_date +
  " risk=" +
  delta.risk_change.to_string() +
  " readiness=" +
  delta.readiness_change.to_string() +
  " quality=" +
  delta.quality_change.to_string() +
  " load=" +
  delta.load_change.to_string() +
  " recovery=" +
  delta.recovery_change.to_string() +
  " pain=" +
  delta.pain_change.to_string() +
  " conclusion=" +
  delta.conclusion
}

///|
pub fn outcome_window_view_text(view : OutcomeWindowView) -> String {
  "window=" +
  view.start_date +
  ".." +
  view.end_date +
  " points=" +
  view.points.length().to_string() +
  " status=" +
  view.status +
  " risk=" +
  view.average_risk.to_string() +
  " readiness=" +
  view.average_readiness.to_string() +
  " quality=" +
  view.average_quality.to_string() +
  " recovery=" +
  view.average_recovery.to_string() +
  " improvement=" +
  view.improvement_score.to_string() +
  " recommendation=" +
  outcome_window_view_recommendation(view)
}

///|
pub fn outcome_window_view_point_text(point : OutcomeWindowViewPoint) -> String {
  point.date +
  " risk=" +
  point.risk.to_string() +
  " readiness=" +
  point.readiness.to_string() +
  " quality=" +
  point.quality.to_string() +
  " load=" +
  point.load.to_string() +
  " recovery=" +
  point.recovery.to_string() +
  " pain=" +
  point.pain.to_string() +
  " fatigue=" +
  point.fatigue.to_string() +
  " action=" +
  point.action_required.to_string()
}

///|
pub fn outcome_window_view_csv_header() -> String {
  "date,risk,readiness,quality,load,recovery,pain,fatigue,action_required"
}

///|
pub fn outcome_window_view_point_csv(point : OutcomeWindowViewPoint) -> String {
  point.date +
  "," +
  point.risk.to_string() +
  "," +
  point.readiness.to_string() +
  "," +
  point.quality.to_string() +
  "," +
  point.load.to_string() +
  "," +
  point.recovery.to_string() +
  "," +
  point.pain.to_string() +
  "," +
  point.fatigue.to_string() +
  "," +
  point.action_required.to_string()
}

///|
pub fn outcome_window_view_csv(view : OutcomeWindowView) -> String {
  let builder = StringBuilder::new()
  builder.write_string(outcome_window_view_csv_header())
  for point in view.points {
    builder.write_string("\n" + outcome_window_view_point_csv(point))
  }
  builder.to_string()
}

///|
pub fn outcome_window_view_checksum(view : OutcomeWindowView) -> String {
  let mut value = view.points.length()
  for character in outcome_window_view_text(view) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn outcome_window_view_reproducible(
  left : OutcomeWindowView,
  right : OutcomeWindowView,
) -> Bool {
  outcome_window_view_checksum(left) == outcome_window_view_checksum(right)
}

///|
pub fn outcome_window_view_exportable(view : OutcomeWindowView) -> Bool {
  outcome_window_view_valid(view)
}

///|
pub fn outcome_window_view_export_status(view : OutcomeWindowView) -> String {
  if outcome_window_view_exportable(view) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn outcome_window_view_contract(view : OutcomeWindowView) -> Array[String] {
  [
    view.status,
    view.points.length().to_string(),
    view.average_risk.to_string(),
    view.average_readiness.to_string(),
    view.improvement_score.to_string(),
    outcome_window_view_recommendation(view),
    outcome_window_view_export_status(view),
    outcome_window_view_checksum(view),
  ]
}
