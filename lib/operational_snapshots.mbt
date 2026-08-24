///|
/// A single operational snapshot joins quality, risk, performance, governance, and handoff.
pub(all) struct OperationalSnapshot {
  snapshot_id : String
  run_id : String
  athlete_label : String
  generated_for : String
  decision_status : String
  governance_status : String
  performance_status : String
  report_status : String
  handoff_priority : String
  risk_score : Double
  readiness_score : Double
  quality_score : Double
  coverage_percent : Double
  alert_count : Int
  event_count : Int
  action_count : Int
  recommendation : String
  checksum : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct OperationalSnapshotWindow {
  snapshots : Array[OperationalSnapshot]
  average_risk : Double
  average_readiness : Double
  average_quality : Double
  average_coverage : Double
  action_days : Int
  critical_days : Int
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct OperationalSnapshotDelta {
  left_id : String
  right_id : String
  risk_change : Double
  readiness_change : Double
  quality_change : Double
  coverage_change : Double
  alert_change : Int
  action_change : Int
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
fn operational_snapshot_checksum(snapshot : OperationalSnapshot) -> String {
  let mut value = snapshot.snapshot_id.length() +
    snapshot.alert_count +
    snapshot.event_count
  for character in operational_snapshot_text(snapshot) {
    value = (value * 33 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn build_operational_snapshot(
  run : DecisionRun,
  performance : PerformanceSnapshot,
  athlete_label : String,
) -> OperationalSnapshot {
  let governance = govern_records([], default_data_retention_policy())
  let report = build_athlete_report(run, performance, athlete_label)
  let handoff = build_clinical_handoff(run, athlete_label)
  let base = {
    snapshot_id: "snapshot-" + run.config.run_id,
    run_id: run.config.run_id,
    athlete_label,
    generated_for: run.monitoring.generated_for,
    decision_status: run.status,
    governance_status: governance_status_name(governance.status),
    performance_status: performance.status,
    report_status: report.status,
    handoff_priority: handoff_priority_name(handoff.priority),
    risk_score: decision_run_latest_risk(run),
    readiness_score: decision_run_latest_readiness(run),
    quality_score: performance.quality_score,
    coverage_percent: performance.coverage_percent,
    alert_count: performance.alert_count,
    event_count: performance.event_count,
    action_count: performance.processing_units - performance.record_count,
    recommendation: report.recommendation,
    checksum: "",
  }
  {
    snapshot_id: base.snapshot_id,
    run_id: base.run_id,
    athlete_label: base.athlete_label,
    generated_for: base.generated_for,
    decision_status: base.decision_status,
    governance_status: base.governance_status,
    performance_status: base.performance_status,
    report_status: base.report_status,
    handoff_priority: base.handoff_priority,
    risk_score: base.risk_score,
    readiness_score: base.readiness_score,
    quality_score: base.quality_score,
    coverage_percent: base.coverage_percent,
    alert_count: base.alert_count,
    event_count: base.event_count,
    action_count: base.action_count,
    recommendation: base.recommendation,
    checksum: operational_snapshot_checksum(base),
  }
}

///|
pub fn operational_snapshot_for_run(
  run : DecisionRun,
  athlete_label : String,
) -> OperationalSnapshot {
  build_operational_snapshot(
    run,
    performance_snapshot([], [], run),
    athlete_label,
  )
}

///|
pub fn operational_snapshot_window(
  snapshots : Array[OperationalSnapshot],
) -> OperationalSnapshotWindow {
  let action_days = snapshots
    .filter(snapshot => snapshot.action_count > 0 || snapshot.alert_count > 0)
    .length()
  let critical_days = snapshots
    .filter(snapshot => snapshot.decision_status == "critical")
    .length()
  {
    snapshots,
    average_risk: mean_load_values(
      snapshots.map(snapshot => snapshot.risk_score),
    ),
    average_readiness: mean_load_values(
      snapshots.map(snapshot => snapshot.readiness_score),
    ),
    average_quality: mean_load_values(
      snapshots.map(snapshot => snapshot.quality_score),
    ),
    average_coverage: mean_load_values(
      snapshots.map(snapshot => snapshot.coverage_percent),
    ),
    action_days,
    critical_days,
    status: if critical_days > 0 {
      "critical"
    } else if action_days > 0 {
      "review"
    } else if snapshots.length() > 0 {
      "stable"
    } else {
      "empty"
    },
  }
}

///|
pub fn operational_snapshot_latest(
  window : OperationalSnapshotWindow,
) -> OperationalSnapshot? {
  if window.snapshots.length() == 0 {
    None
  } else {
    Some(window.snapshots[window.snapshots.length() - 1])
  }
}

///|
pub fn operational_snapshot_first(
  window : OperationalSnapshotWindow,
) -> OperationalSnapshot? {
  if window.snapshots.length() == 0 {
    None
  } else {
    Some(window.snapshots[0])
  }
}

///|
pub fn operational_snapshot_count(window : OperationalSnapshotWindow) -> Int {
  window.snapshots.length()
}

///|
pub fn operational_snapshot_ids(
  window : OperationalSnapshotWindow,
) -> Array[String] {
  window.snapshots.map(snapshot => snapshot.snapshot_id)
}

///|
pub fn operational_snapshot_dates(
  window : OperationalSnapshotWindow,
) -> Array[String] {
  window.snapshots.map(snapshot => snapshot.generated_for)
}

///|
pub fn operational_snapshot_risks(
  window : OperationalSnapshotWindow,
) -> Array[Double] {
  window.snapshots.map(snapshot => snapshot.risk_score)
}

///|
pub fn operational_snapshot_readiness(
  window : OperationalSnapshotWindow,
) -> Array[Double] {
  window.snapshots.map(snapshot => snapshot.readiness_score)
}

///|
pub fn operational_snapshot_quality(
  window : OperationalSnapshotWindow,
) -> Array[Double] {
  window.snapshots.map(snapshot => snapshot.quality_score)
}

///|
pub fn operational_snapshot_coverage(
  window : OperationalSnapshotWindow,
) -> Array[Double] {
  window.snapshots.map(snapshot => snapshot.coverage_percent)
}

///|
pub fn operational_snapshot_alerts(
  window : OperationalSnapshotWindow,
) -> Array[Int] {
  window.snapshots.map(snapshot => snapshot.alert_count)
}

///|
pub fn operational_snapshot_events(
  window : OperationalSnapshotWindow,
) -> Array[Int] {
  window.snapshots.map(snapshot => snapshot.event_count)
}

///|
pub fn operational_snapshot_actions(
  window : OperationalSnapshotWindow,
) -> Array[Int] {
  window.snapshots.map(snapshot => snapshot.action_count)
}

///|
pub fn operational_snapshot_by_id(
  window : OperationalSnapshotWindow,
  id : String,
) -> OperationalSnapshot? {
  for snapshot in window.snapshots {
    if snapshot.snapshot_id == id {
      return Some(snapshot)
    }
  }
  None
}

///|
pub fn operational_snapshot_by_date(
  window : OperationalSnapshotWindow,
  date : String,
) -> OperationalSnapshot? {
  for snapshot in window.snapshots {
    if snapshot.generated_for == date {
      return Some(snapshot)
    }
  }
  None
}

///|
pub fn operational_snapshot_critical(
  window : OperationalSnapshotWindow,
) -> Array[OperationalSnapshot] {
  window.snapshots.filter(snapshot => snapshot.decision_status == "critical")
}

///|
pub fn operational_snapshot_review(
  window : OperationalSnapshotWindow,
) -> Array[OperationalSnapshot] {
  window.snapshots.filter(snapshot => snapshot.decision_status != "accepted")
}

///|
pub fn operational_snapshot_accepted(
  window : OperationalSnapshotWindow,
) -> Array[OperationalSnapshot] {
  window.snapshots.filter(snapshot => snapshot.decision_status == "accepted")
}

///|
pub fn operational_snapshot_latest_status(
  window : OperationalSnapshotWindow,
) -> String {
  match operational_snapshot_latest(window) {
    Some(snapshot) => snapshot.decision_status
    None => "empty"
  }
}

///|
pub fn operational_snapshot_latest_risk(
  window : OperationalSnapshotWindow,
) -> Double {
  match operational_snapshot_latest(window) {
    Some(snapshot) => snapshot.risk_score
    None => 0.0
  }
}

///|
pub fn operational_snapshot_latest_readiness(
  window : OperationalSnapshotWindow,
) -> Double {
  match operational_snapshot_latest(window) {
    Some(snapshot) => snapshot.readiness_score
    None => 0.0
  }
}

///|
pub fn operational_snapshot_latest_quality(
  window : OperationalSnapshotWindow,
) -> Double {
  match operational_snapshot_latest(window) {
    Some(snapshot) => snapshot.quality_score
    None => 0.0
  }
}

///|
pub fn operational_snapshot_action_rate(
  window : OperationalSnapshotWindow,
) -> Double {
  if window.snapshots.length() == 0 {
    0.0
  } else {
    window.action_days.to_double() /
    window.snapshots.length().to_double() *
    100.0
  }
}

///|
pub fn operational_snapshot_critical_rate(
  window : OperationalSnapshotWindow,
) -> Double {
  if window.snapshots.length() == 0 {
    0.0
  } else {
    window.critical_days.to_double() /
    window.snapshots.length().to_double() *
    100.0
  }
}

///|
pub fn operational_snapshot_risk_trend(
  window : OperationalSnapshotWindow,
) -> LoadTrend {
  load_trend(operational_snapshot_risks(window), 0.1)
}

///|
pub fn operational_snapshot_readiness_trend(
  window : OperationalSnapshotWindow,
) -> LoadTrend {
  load_trend(operational_snapshot_readiness(window), 0.1)
}

///|
pub fn operational_snapshot_quality_trend(
  window : OperationalSnapshotWindow,
) -> LoadTrend {
  load_trend(operational_snapshot_quality(window), 0.1)
}

///|
pub fn operational_snapshot_window_valid(
  window : OperationalSnapshotWindow,
) -> Bool {
  window.snapshots.all(snapshot => operational_snapshot_valid(snapshot)) &&
  window.average_risk >= 0.0 &&
  window.average_readiness >= 0.0 &&
  window.average_quality >= 0.0 &&
  window.average_coverage >= 0.0
}

///|
pub fn operational_snapshot_valid(snapshot : OperationalSnapshot) -> Bool {
  snapshot.snapshot_id != "" &&
  snapshot.run_id != "" &&
  snapshot.athlete_label != "" &&
  snapshot.generated_for != "" &&
  snapshot.decision_status != "" &&
  snapshot.risk_score >= 0.0 &&
  snapshot.risk_score <= 100.0 &&
  snapshot.readiness_score >= 0.0 &&
  snapshot.readiness_score <= 100.0 &&
  snapshot.quality_score >= 0.0 &&
  snapshot.quality_score <= 100.0 &&
  snapshot.coverage_percent >= 0.0 &&
  snapshot.coverage_percent <= 100.0 &&
  snapshot.alert_count >= 0 &&
  snapshot.event_count >= 0 &&
  snapshot.action_count >= 0 &&
  snapshot.checksum == operational_snapshot_checksum(snapshot)
}

///|
pub fn operational_snapshot_checksum_valid(
  snapshot : OperationalSnapshot,
) -> Bool {
  snapshot.checksum == operational_snapshot_checksum(snapshot)
}

///|
pub fn operational_snapshot_requires_action(
  snapshot : OperationalSnapshot,
) -> Bool {
  snapshot.decision_status != "accepted" ||
  snapshot.action_count > 0 ||
  snapshot.alert_count > 0
}

///|
pub fn operational_snapshot_is_critical(snapshot : OperationalSnapshot) -> Bool {
  snapshot.decision_status == "critical"
}

///|
pub fn operational_snapshot_is_accepted(snapshot : OperationalSnapshot) -> Bool {
  snapshot.decision_status == "accepted"
}

///|
pub fn operational_snapshot_metric(
  snapshot : OperationalSnapshot,
  name : String,
) -> Double {
  match name {
    "risk" => snapshot.risk_score
    "readiness" => snapshot.readiness_score
    "quality" => snapshot.quality_score
    "coverage" => snapshot.coverage_percent
    "alerts" => snapshot.alert_count.to_double()
    "events" => snapshot.event_count.to_double()
    "actions" => snapshot.action_count.to_double()
    _ => 0.0
  }
}

///|
pub fn operational_snapshot_metric_names() -> Array[String] {
  ["risk", "readiness", "quality", "coverage", "alerts", "events", "actions"]
}

///|
pub fn operational_snapshot_projection(
  window : OperationalSnapshotWindow,
  name : String,
) -> Array[Double] {
  window.snapshots.map(snapshot => operational_snapshot_metric(snapshot, name))
}

///|
pub fn operational_snapshot_projection_average(
  window : OperationalSnapshotWindow,
  name : String,
) -> Double {
  mean_load_values(operational_snapshot_projection(window, name))
}

///|
pub fn operational_snapshot_projection_minimum(
  window : OperationalSnapshotWindow,
  name : String,
) -> Double {
  minimum_load_values(operational_snapshot_projection(window, name))
}

///|
pub fn operational_snapshot_projection_maximum(
  window : OperationalSnapshotWindow,
  name : String,
) -> Double {
  maximum_load_values(operational_snapshot_projection(window, name))
}

///|
pub fn operational_snapshot_projection_deviation(
  window : OperationalSnapshotWindow,
  name : String,
) -> Double {
  standard_deviation_values(operational_snapshot_projection(window, name))
}

///|
pub fn operational_snapshot_threshold_count(
  window : OperationalSnapshotWindow,
  name : String,
  threshold : Double,
) -> Int {
  window.snapshots
  .filter(snapshot => operational_snapshot_metric(snapshot, name) >= threshold)
  .length()
}

///|
pub fn operational_snapshot_threshold_percent(
  window : OperationalSnapshotWindow,
  name : String,
  threshold : Double,
) -> Double {
  if window.snapshots.length() == 0 {
    0.0
  } else {
    operational_snapshot_threshold_count(window, name, threshold).to_double() /
    window.snapshots.length().to_double() *
    100.0
  }
}

///|
pub fn operational_snapshot_compare(
  left : OperationalSnapshot,
  right : OperationalSnapshot,
) -> OperationalSnapshotDelta {
  {
    left_id: left.snapshot_id,
    right_id: right.snapshot_id,
    risk_change: right.risk_score - left.risk_score,
    readiness_change: right.readiness_score - left.readiness_score,
    quality_change: right.quality_score - left.quality_score,
    coverage_change: right.coverage_percent - left.coverage_percent,
    alert_change: right.alert_count - left.alert_count,
    action_change: right.action_count - left.action_count,
    conclusion: if right.risk_score < left.risk_score &&
      right.readiness_score > left.readiness_score {
      "operational state improved"
    } else if right.risk_score > left.risk_score ||
      right.readiness_score < left.readiness_score {
      "operational state worsened"
    } else {
      "operational state is stable"
    },
  }
}

///|
pub fn operational_snapshot_compare_latest(
  window : OperationalSnapshotWindow,
) -> OperationalSnapshotDelta? {
  if window.snapshots.length() < 2 {
    None
  } else {
    Some(
      operational_snapshot_compare(
        window.snapshots[window.snapshots.length() - 2],
        window.snapshots[window.snapshots.length() - 1],
      ),
    )
  }
}

///|
pub fn operational_snapshot_delta_text(
  delta : OperationalSnapshotDelta,
) -> String {
  delta.left_id +
  " -> " +
  delta.right_id +
  " risk=" +
  delta.risk_change.to_string() +
  " readiness=" +
  delta.readiness_change.to_string() +
  " quality=" +
  delta.quality_change.to_string() +
  " coverage=" +
  delta.coverage_change.to_string() +
  " alerts=" +
  delta.alert_change.to_string() +
  " actions=" +
  delta.action_change.to_string() +
  " conclusion=" +
  delta.conclusion
}

///|
pub fn operational_snapshot_text(snapshot : OperationalSnapshot) -> String {
  "id=" +
  snapshot.snapshot_id +
  " run=" +
  snapshot.run_id +
  " athlete=" +
  snapshot.athlete_label +
  " date=" +
  snapshot.generated_for +
  " decision=" +
  snapshot.decision_status +
  " governance=" +
  snapshot.governance_status +
  " performance=" +
  snapshot.performance_status +
  " report=" +
  snapshot.report_status +
  " handoff=" +
  snapshot.handoff_priority +
  " risk=" +
  snapshot.risk_score.to_string() +
  " readiness=" +
  snapshot.readiness_score.to_string() +
  " quality=" +
  snapshot.quality_score.to_string() +
  " coverage=" +
  snapshot.coverage_percent.to_string() +
  " alerts=" +
  snapshot.alert_count.to_string() +
  " events=" +
  snapshot.event_count.to_string() +
  " actions=" +
  snapshot.action_count.to_string() +
  " recommendation=" +
  snapshot.recommendation
}

///|
pub fn operational_snapshot_window_text(
  window : OperationalSnapshotWindow,
) -> String {
  "count=" +
  window.snapshots.length().to_string() +
  " status=" +
  window.status +
  " risk=" +
  window.average_risk.to_string() +
  " readiness=" +
  window.average_readiness.to_string() +
  " quality=" +
  window.average_quality.to_string() +
  " coverage=" +
  window.average_coverage.to_string() +
  " action_days=" +
  window.action_days.to_string() +
  " critical_days=" +
  window.critical_days.to_string()
}

///|
pub fn operational_snapshot_csv_header() -> String {
  "snapshot_id,run_id,athlete_label,generated_for,decision_status,governance_status,performance_status,report_status,handoff_priority,risk_score,readiness_score,quality_score,coverage_percent,alert_count,event_count,action_count,recommendation,checksum"
}

///|
pub fn operational_snapshot_csv(snapshot : OperationalSnapshot) -> String {
  snapshot.snapshot_id +
  "," +
  snapshot.run_id +
  "," +
  snapshot.athlete_label +
  "," +
  snapshot.generated_for +
  "," +
  snapshot.decision_status +
  "," +
  snapshot.governance_status +
  "," +
  snapshot.performance_status +
  "," +
  snapshot.report_status +
  "," +
  snapshot.handoff_priority +
  "," +
  snapshot.risk_score.to_string() +
  "," +
  snapshot.readiness_score.to_string() +
  "," +
  snapshot.quality_score.to_string() +
  "," +
  snapshot.coverage_percent.to_string() +
  "," +
  snapshot.alert_count.to_string() +
  "," +
  snapshot.event_count.to_string() +
  "," +
  snapshot.action_count.to_string() +
  "," +
  snapshot.recommendation +
  "," +
  snapshot.checksum
}

///|
pub fn operational_snapshot_window_csv(
  window : OperationalSnapshotWindow,
) -> String {
  let builder = StringBuilder()
  builder.write_string(operational_snapshot_csv_header())
  for snapshot in window.snapshots {
    builder.write_string("\n" + operational_snapshot_csv(snapshot))
  }
  builder.to_string()
}

///|
pub fn operational_snapshot_summary_header() -> Array[String] {
  [
    "count", "status", "average_risk", "average_readiness", "average_quality", "average_coverage",
    "action_days", "critical_days",
  ]
}

///|
pub fn operational_snapshot_summary(
  window : OperationalSnapshotWindow,
) -> Array[String] {
  [
    window.snapshots.length().to_string(),
    window.status,
    window.average_risk.to_string(),
    window.average_readiness.to_string(),
    window.average_quality.to_string(),
    window.average_coverage.to_string(),
    window.action_days.to_string(),
    window.critical_days.to_string(),
  ]
}

///|
pub fn operational_snapshot_summary_csv(
  window : OperationalSnapshotWindow,
) -> String {
  operational_snapshot_summary_header().join(",") +
  "\n" +
  operational_snapshot_summary(window).join(",")
}

///|
pub fn operational_snapshot_recommendation(
  window : OperationalSnapshotWindow,
) -> String {
  if window.status == "critical" {
    "route repeated critical snapshots for review"
  } else if window.status == "review" {
    "review action snapshots before progression"
  } else if window.status == "stable" {
    "continue the monitoring cadence"
  } else {
    "collect telemetry"
  }
}

///|
pub fn operational_snapshot_window_checksum(
  window : OperationalSnapshotWindow,
) -> String {
  let mut value = window.snapshots.length()
  for character in operational_snapshot_window_text(window) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn operational_snapshot_window_reproducible(
  left : OperationalSnapshotWindow,
  right : OperationalSnapshotWindow,
) -> Bool {
  operational_snapshot_window_checksum(left) ==
  operational_snapshot_window_checksum(right)
}

///|
pub fn operational_snapshot_window_contract(
  window : OperationalSnapshotWindow,
) -> Array[String] {
  [
    window.status,
    window.snapshots.length().to_string(),
    operational_snapshot_action_rate(window).to_string(),
    operational_snapshot_critical_rate(window).to_string(),
    operational_snapshot_recommendation(window),
    operational_snapshot_window_checksum(window),
  ]
}
