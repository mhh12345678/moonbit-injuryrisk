///|
/// Batch run views support multi-athlete operations without losing row-level evidence.
pub(all) struct RunBatchRow {
  run_id : String
  athlete_label : String
  generated_for : String
  status : String
  accepted : Bool
  risk : Double
  readiness : Double
  quality : Double
  coverage : Double
  alerts : Int
  events : Int
  actions : Int
  priority : Int
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RunBatchView {
  rows : Array[RunBatchRow]
  accepted_count : Int
  action_count : Int
  critical_count : Int
  average_risk : Double
  average_readiness : Double
  average_quality : Double
  average_coverage : Double
  status : String
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RunBatchComparison {
  left_count : Int
  right_count : Int
  accepted_change : Int
  action_change : Int
  risk_change : Double
  readiness_change : Double
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
fn run_batch_row(
  run : DecisionRun,
  performance : PerformanceSnapshot,
) -> RunBatchRow {
  {
    run_id: run.config.run_id,
    athlete_label: run.config.athlete_label,
    generated_for: run.monitoring.generated_for,
    status: run.status,
    accepted: run.accepted,
    risk: decision_run_latest_risk(run),
    readiness: decision_run_latest_readiness(run),
    quality: performance.quality_score,
    coverage: performance.coverage_percent,
    alerts: performance.alert_count,
    events: performance.event_count,
    actions: decision_run_action_count(run),
    priority: if run.status == "critical" {
      3
    } else if decision_run_requires_action(run) {
      2
    } else if run.status == "review" {
      1
    } else {
      0
    },
    recommendation: decision_run_recommendation(run),
  }
}

///|
pub fn build_run_batch_view(
  runs : Array[DecisionRun],
  performances : Array[PerformanceSnapshot],
) -> RunBatchView {
  let rows = []
  let count = runs.length().min(performances.length())
  for index in 0..<count {
    rows.push(run_batch_row(runs[index], performances[index]))
  }
  let accepted = rows.filter(row => row.accepted).length()
  let actions = rows.filter(row => row.actions > 0 || !row.accepted).length()
  let critical = rows.filter(row => row.priority >= 3).length()
  {
    rows,
    accepted_count: accepted,
    action_count: actions,
    critical_count: critical,
    average_risk: mean_load_values(rows.map(row => row.risk)),
    average_readiness: mean_load_values(rows.map(row => row.readiness)),
    average_quality: mean_load_values(rows.map(row => row.quality)),
    average_coverage: mean_load_values(rows.map(row => row.coverage)),
    status: if critical > 0 {
      "critical"
    } else if actions > 0 {
      "review"
    } else if rows.length() > 0 {
      "accepted"
    } else {
      "empty"
    },
    recommendation: if critical > 0 {
      "route critical rows for review"
    } else if actions > 0 {
      "complete row-level actions"
    } else {
      "continue batch processing"
    },
  }
}

///|
pub fn run_batch_rows(view : RunBatchView) -> Array[RunBatchRow] {
  view.rows
}

///|
pub fn run_batch_row_by_id(view : RunBatchView, id : String) -> RunBatchRow? {
  for row in view.rows {
    if row.run_id == id {
      return Some(row)
    }
  }
  None
}

///|
pub fn run_batch_accepted(view : RunBatchView) -> Array[RunBatchRow] {
  view.rows.filter(row => row.accepted)
}

///|
pub fn run_batch_actionable(view : RunBatchView) -> Array[RunBatchRow] {
  view.rows.filter(row => row.actions > 0 || !row.accepted)
}

///|
pub fn run_batch_critical(view : RunBatchView) -> Array[RunBatchRow] {
  view.rows.filter(row => row.priority >= 3)
}

///|
pub fn run_batch_review(view : RunBatchView) -> Array[RunBatchRow] {
  view.rows.filter(row => row.priority > 0)
}

///|
pub fn run_batch_count(view : RunBatchView) -> Int {
  view.rows.length()
}

///|
pub fn run_batch_accepted_count(view : RunBatchView) -> Int {
  view.accepted_count
}

///|
pub fn run_batch_action_count(view : RunBatchView) -> Int {
  view.action_count
}

///|
pub fn run_batch_critical_count(view : RunBatchView) -> Int {
  view.critical_count
}

///|
pub fn run_batch_accepted_percent(view : RunBatchView) -> Double {
  if view.rows.length() == 0 {
    0.0
  } else {
    view.accepted_count.to_double() / view.rows.length().to_double() * 100.0
  }
}

///|
pub fn run_batch_action_percent(view : RunBatchView) -> Double {
  if view.rows.length() == 0 {
    0.0
  } else {
    view.action_count.to_double() / view.rows.length().to_double() * 100.0
  }
}

///|
pub fn run_batch_critical_percent(view : RunBatchView) -> Double {
  if view.rows.length() == 0 {
    0.0
  } else {
    view.critical_count.to_double() / view.rows.length().to_double() * 100.0
  }
}

///|
pub fn run_batch_risks(view : RunBatchView) -> Array[Double] {
  view.rows.map(row => row.risk)
}

///|
pub fn run_batch_readiness(view : RunBatchView) -> Array[Double] {
  view.rows.map(row => row.readiness)
}

///|
pub fn run_batch_quality(view : RunBatchView) -> Array[Double] {
  view.rows.map(row => row.quality)
}

///|
pub fn run_batch_coverage(view : RunBatchView) -> Array[Double] {
  view.rows.map(row => row.coverage)
}

///|
pub fn run_batch_average_risk(view : RunBatchView) -> Double {
  view.average_risk
}

///|
pub fn run_batch_average_readiness(view : RunBatchView) -> Double {
  view.average_readiness
}

///|
pub fn run_batch_average_quality(view : RunBatchView) -> Double {
  view.average_quality
}

///|
pub fn run_batch_average_coverage(view : RunBatchView) -> Double {
  view.average_coverage
}

///|
pub fn run_batch_risk_trend(view : RunBatchView) -> LoadTrend {
  load_trend(run_batch_risks(view), 0.1)
}

///|
pub fn run_batch_readiness_trend(view : RunBatchView) -> LoadTrend {
  load_trend(run_batch_readiness(view), 0.1)
}

///|
pub fn run_batch_quality_trend(view : RunBatchView) -> LoadTrend {
  load_trend(run_batch_quality(view), 0.1)
}

///|
pub fn run_batch_status(view : RunBatchView) -> String {
  view.status
}

///|
pub fn run_batch_recommendation(view : RunBatchView) -> String {
  view.recommendation
}

///|
pub fn run_batch_requires_review(view : RunBatchView) -> Bool {
  view.status == "critical" || view.status == "review"
}

///|
pub fn run_batch_valid_row(row : RunBatchRow) -> Bool {
  row.run_id != "" &&
  row.athlete_label != "" &&
  row.generated_for != "" &&
  row.status != "" &&
  row.risk >= 0.0 &&
  row.risk <= 100.0 &&
  row.readiness >= 0.0 &&
  row.readiness <= 100.0 &&
  row.quality >= 0.0 &&
  row.quality <= 100.0 &&
  row.coverage >= 0.0 &&
  row.coverage <= 100.0 &&
  row.alerts >= 0 &&
  row.events >= 0 &&
  row.actions >= 0 &&
  row.priority >= 0
}

///|
pub fn run_batch_valid(view : RunBatchView) -> Bool {
  view.rows.all(row => run_batch_valid_row(row)) &&
  view.accepted_count >= 0 &&
  view.action_count >= 0 &&
  view.critical_count >= 0 &&
  view.accepted_count <= view.rows.length() &&
  view.average_risk >= 0.0 &&
  view.average_risk <= 100.0 &&
  view.average_readiness >= 0.0 &&
  view.average_readiness <= 100.0 &&
  view.average_quality >= 0.0 &&
  view.average_quality <= 100.0 &&
  view.average_coverage >= 0.0 &&
  view.average_coverage <= 100.0
}

///|
pub fn run_batch_metric(row : RunBatchRow, name : String) -> Double {
  match name {
    "risk" => row.risk
    "readiness" => row.readiness
    "quality" => row.quality
    "coverage" => row.coverage
    "alerts" => row.alerts.to_double()
    "events" => row.events.to_double()
    "actions" => row.actions.to_double()
    "priority" => row.priority.to_double()
    _ => 0.0
  }
}

///|
pub fn run_batch_projection(
  view : RunBatchView,
  name : String,
) -> Array[Double] {
  view.rows.map(row => run_batch_metric(row, name))
}

///|
pub fn run_batch_projection_average(
  view : RunBatchView,
  name : String,
) -> Double {
  mean_load_values(run_batch_projection(view, name))
}

///|
pub fn run_batch_projection_minimum(
  view : RunBatchView,
  name : String,
) -> Double {
  minimum_load_values(run_batch_projection(view, name))
}

///|
pub fn run_batch_projection_maximum(
  view : RunBatchView,
  name : String,
) -> Double {
  maximum_load_values(run_batch_projection(view, name))
}

///|
pub fn run_batch_projection_deviation(
  view : RunBatchView,
  name : String,
) -> Double {
  standard_deviation_values(run_batch_projection(view, name))
}

///|
pub fn run_batch_filter_status(
  view : RunBatchView,
  status : String,
) -> Array[RunBatchRow] {
  view.rows.filter(row => row.status == status)
}

///|
pub fn run_batch_filter_priority(
  view : RunBatchView,
  priority : Int,
) -> Array[RunBatchRow] {
  view.rows.filter(row => row.priority >= priority)
}

///|
pub fn run_batch_filter_risk(
  view : RunBatchView,
  threshold : Double,
) -> Array[RunBatchRow] {
  view.rows.filter(row => row.risk >= threshold)
}

///|
pub fn run_batch_filter_readiness(
  view : RunBatchView,
  threshold : Double,
) -> Array[RunBatchRow] {
  view.rows.filter(row => row.readiness < threshold)
}

///|
pub fn run_batch_row_text(row : RunBatchRow) -> String {
  row.run_id +
  " athlete=" +
  row.athlete_label +
  " date=" +
  row.generated_for +
  " status=" +
  row.status +
  " accepted=" +
  row.accepted.to_string() +
  " risk=" +
  row.risk.to_string() +
  " readiness=" +
  row.readiness.to_string() +
  " quality=" +
  row.quality.to_string() +
  " coverage=" +
  row.coverage.to_string() +
  " alerts=" +
  row.alerts.to_string() +
  " events=" +
  row.events.to_string() +
  " actions=" +
  row.actions.to_string() +
  " recommendation=" +
  row.recommendation
}

///|
pub fn run_batch_text(view : RunBatchView) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "status=" +
    view.status +
    " rows=" +
    view.rows.length().to_string() +
    " accepted=" +
    view.accepted_count.to_string() +
    " action=" +
    view.action_count.to_string() +
    " critical=" +
    view.critical_count.to_string() +
    " risk=" +
    view.average_risk.to_string() +
    " readiness=" +
    view.average_readiness.to_string() +
    " quality=" +
    view.average_quality.to_string() +
    " coverage=" +
    view.average_coverage.to_string(),
  )
  builder.write_string("\nrecommendation=" + view.recommendation)
  for row in view.rows {
    builder.write_string("\n" + run_batch_row_text(row))
  }
  builder.to_string()
}

///|
pub fn run_batch_csv_header() -> String {
  "run_id,athlete_label,generated_for,status,accepted,risk,readiness,quality,coverage,alerts,events,actions,priority,recommendation"
}

///|
pub fn run_batch_row_csv(row : RunBatchRow) -> String {
  row.run_id +
  "," +
  row.athlete_label +
  "," +
  row.generated_for +
  "," +
  row.status +
  "," +
  row.accepted.to_string() +
  "," +
  row.risk.to_string() +
  "," +
  row.readiness.to_string() +
  "," +
  row.quality.to_string() +
  "," +
  row.coverage.to_string() +
  "," +
  row.alerts.to_string() +
  "," +
  row.events.to_string() +
  "," +
  row.actions.to_string() +
  "," +
  row.priority.to_string() +
  "," +
  row.recommendation
}

///|
pub fn run_batch_csv(view : RunBatchView) -> String {
  let builder = StringBuilder::new()
  builder.write_string(run_batch_csv_header())
  for row in view.rows {
    builder.write_string("\n" + run_batch_row_csv(row))
  }
  builder.to_string()
}

///|
pub fn run_batch_compare(
  left : RunBatchView,
  right : RunBatchView,
) -> RunBatchComparison {
  {
    left_count: left.rows.length(),
    right_count: right.rows.length(),
    accepted_change: right.accepted_count - left.accepted_count,
    action_change: right.action_count - left.action_count,
    risk_change: right.average_risk - left.average_risk,
    readiness_change: right.average_readiness - left.average_readiness,
    conclusion: if right.average_risk < left.average_risk &&
      right.average_readiness > left.average_readiness {
      "batch outcomes improved"
    } else if right.average_risk > left.average_risk {
      "batch risk increased"
    } else {
      "batch outcomes are mixed"
    },
  }
}

///|
pub fn run_batch_comparison_text(comparison : RunBatchComparison) -> String {
  "rows=" +
  comparison.left_count.to_string() +
  " -> " +
  comparison.right_count.to_string() +
  " accepted_change=" +
  comparison.accepted_change.to_string() +
  " action_change=" +
  comparison.action_change.to_string() +
  " risk_change=" +
  comparison.risk_change.to_string() +
  " readiness_change=" +
  comparison.readiness_change.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn run_batch_checksum(view : RunBatchView) -> String {
  let mut value = view.rows.length()
  for character in run_batch_text(view) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn run_batch_reproducible(
  left : RunBatchView,
  right : RunBatchView,
) -> Bool {
  run_batch_checksum(left) == run_batch_checksum(right)
}

///|
pub fn run_batch_exportable(view : RunBatchView) -> Bool {
  run_batch_valid(view)
}

///|
pub fn run_batch_export_status(view : RunBatchView) -> String {
  if run_batch_exportable(view) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn run_batch_contract(view : RunBatchView) -> Array[String] {
  [
    view.status,
    view.rows.length().to_string(),
    run_batch_accepted_percent(view).to_string(),
    run_batch_action_percent(view).to_string(),
    run_batch_critical_percent(view).to_string(),
    run_batch_recommendation(view),
    run_batch_export_status(view),
    run_batch_checksum(view),
  ]
}
