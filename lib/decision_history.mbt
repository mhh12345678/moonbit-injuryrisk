///|
/// Immutable decision history for longitudinal review and audit comparison.
pub(all) struct DecisionHistoryEntry {
  sequence : Int
  run_id : String
  generated_for : String
  status : String
  accepted : Bool
  risk_score : Double
  readiness_score : Double
  quality_score : Double
  alert_count : Int
  event_count : Int
  action_count : Int
  checksum : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct DecisionHistory {
  entries : Array[DecisionHistoryEntry]
  accepted_count : Int
  review_count : Int
  critical_count : Int
  average_risk : Double
  average_readiness : Double
  latest_status : String
  valid : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct DecisionHistoryComparison {
  left : DecisionHistoryEntry
  right : DecisionHistoryEntry
  risk_change : Double
  readiness_change : Double
  quality_change : Double
  alert_change : Int
  direction : TrendDirection
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct DecisionHistorySummary {
  run_count : Int
  accepted_percent : Double
  review_percent : Double
  critical_percent : Double
  risk_minimum : Double
  risk_maximum : Double
  readiness_minimum : Double
  readiness_maximum : Double
  quality_average : Double
  trend : LoadTrend
  status : String
} derive(Debug, Eq, ToJson)

///|
fn decision_history_entry_checksum_value(
  entry : DecisionHistoryEntry,
) -> String {
  let mut value = entry.sequence + entry.run_id.length()
  for character in decision_history_entry_csv(entry) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
fn decision_history_entry(
  run : DecisionRun,
  sequence : Int,
) -> DecisionHistoryEntry {
  let entry = {
    sequence,
    run_id: run.config.run_id,
    generated_for: run.monitoring.generated_for,
    status: run.status,
    accepted: run.accepted,
    risk_score: decision_run_latest_risk(run),
    readiness_score: decision_run_latest_readiness(run),
    quality_score: run.quality.report.score,
    alert_count: decision_run_alert_count(run),
    event_count: decision_run_event_count(run),
    action_count: decision_run_action_count(run),
    checksum: "",
  }
  {
    sequence: entry.sequence,
    run_id: entry.run_id,
    generated_for: entry.generated_for,
    status: entry.status,
    accepted: entry.accepted,
    risk_score: entry.risk_score,
    readiness_score: entry.readiness_score,
    quality_score: entry.quality_score,
    alert_count: entry.alert_count,
    event_count: entry.event_count,
    action_count: entry.action_count,
    checksum: decision_history_entry_checksum_value(entry),
  }
}

///|
fn history_average(
  entries : Array[DecisionHistoryEntry],
  selector : (DecisionHistoryEntry) -> Double,
) -> Double {
  mean_load_values(entries.map(selector))
}

///|
fn decision_history_status_value(
  entries : Array[DecisionHistoryEntry],
) -> String {
  if entries.length() == 0 {
    "empty"
  } else if entries.any(entry => entry.status == "critical") {
    "critical"
  } else if entries.any(entry => !entry.accepted) {
    "review"
  } else {
    "accepted"
  }
}

///|
pub fn new_decision_history() -> DecisionHistory {
  {
    entries: [],
    accepted_count: 0,
    review_count: 0,
    critical_count: 0,
    average_risk: 0.0,
    average_readiness: 0.0,
    latest_status: "empty",
    valid: true,
  }
}

///|
pub fn decision_history_from_runs(runs : Array[DecisionRun]) -> DecisionHistory {
  let entries = []
  for index, run in runs {
    entries.push(decision_history_entry(run, index + 1))
  }
  decision_history_from_entries(entries)
}

///|
pub fn decision_history_from_entries(
  entries : Array[DecisionHistoryEntry],
) -> DecisionHistory {
  let accepted = entries.filter(entry => entry.accepted).length()
  let critical = entries.filter(entry => entry.status == "critical").length()
  let review = entries.length() - accepted
  {
    entries,
    accepted_count: accepted,
    review_count: review,
    critical_count: critical,
    average_risk: history_average(entries, entry => entry.risk_score),
    average_readiness: history_average(entries, entry => entry.readiness_score),
    latest_status: decision_history_status_value(entries),
    valid: entries.all(entry => decision_history_entry_valid(entry)),
  }
}

///|
pub fn decision_history_append(
  history : DecisionHistory,
  run : DecisionRun,
) -> DecisionHistory {
  let entries = history.entries.copy()
  entries.push(decision_history_entry(run, entries.length() + 1))
  decision_history_from_entries(entries)
}

///|
pub fn decision_history_append_entry(
  history : DecisionHistory,
  entry : DecisionHistoryEntry,
) -> DecisionHistory {
  let entries = history.entries.copy()
  entries.push(entry)
  decision_history_from_entries(entries)
}

///|
pub fn decision_history_entry_by_id(
  history : DecisionHistory,
  run_id : String,
) -> DecisionHistoryEntry? {
  for entry in history.entries {
    if entry.run_id == run_id {
      return Some(entry)
    }
  }
  None
}

///|
pub fn decision_history_entry_by_sequence(
  history : DecisionHistory,
  sequence : Int,
) -> DecisionHistoryEntry? {
  for entry in history.entries {
    if entry.sequence == sequence {
      return Some(entry)
    }
  }
  None
}

///|
pub fn decision_history_latest(
  history : DecisionHistory,
) -> DecisionHistoryEntry? {
  if history.entries.length() == 0 {
    None
  } else {
    Some(history.entries[history.entries.length() - 1])
  }
}

///|
pub fn decision_history_first(
  history : DecisionHistory,
) -> DecisionHistoryEntry? {
  if history.entries.length() == 0 {
    None
  } else {
    Some(history.entries[0])
  }
}

///|
pub fn decision_history_count(history : DecisionHistory) -> Int {
  history.entries.length()
}

///|
pub fn decision_history_run_ids(history : DecisionHistory) -> Array[String] {
  history.entries.map(entry => entry.run_id)
}

///|
pub fn decision_history_dates(history : DecisionHistory) -> Array[String] {
  history.entries.map(entry => entry.generated_for)
}

///|
pub fn decision_history_statuses(history : DecisionHistory) -> Array[String] {
  history.entries.map(entry => entry.status)
}

///|
pub fn decision_history_risk_values(history : DecisionHistory) -> Array[Double] {
  history.entries.map(entry => entry.risk_score)
}

///|
pub fn decision_history_readiness_values(
  history : DecisionHistory,
) -> Array[Double] {
  history.entries.map(entry => entry.readiness_score)
}

///|
pub fn decision_history_quality_values(
  history : DecisionHistory,
) -> Array[Double] {
  history.entries.map(entry => entry.quality_score)
}

///|
pub fn decision_history_alert_values(history : DecisionHistory) -> Array[Int] {
  history.entries.map(entry => entry.alert_count)
}

///|
pub fn decision_history_event_values(history : DecisionHistory) -> Array[Int] {
  history.entries.map(entry => entry.event_count)
}

///|
pub fn decision_history_action_values(history : DecisionHistory) -> Array[Int] {
  history.entries.map(entry => entry.action_count)
}

///|
pub fn decision_history_accepted(
  history : DecisionHistory,
) -> Array[DecisionHistoryEntry] {
  history.entries.filter(entry => entry.accepted)
}

///|
pub fn decision_history_reviews(
  history : DecisionHistory,
) -> Array[DecisionHistoryEntry] {
  history.entries.filter(entry => !entry.accepted)
}

///|
pub fn decision_history_critical(
  history : DecisionHistory,
) -> Array[DecisionHistoryEntry] {
  history.entries.filter(entry => entry.status == "critical")
}

///|
pub fn decision_history_actionable(
  history : DecisionHistory,
) -> Array[DecisionHistoryEntry] {
  history.entries.filter(entry => {
    entry.action_count > 0 || entry.alert_count > 0
  })
}

///|
pub fn decision_history_accepted_percent(history : DecisionHistory) -> Double {
  if history.entries.length() == 0 {
    0.0
  } else {
    history.accepted_count.to_double() /
    history.entries.length().to_double() *
    100.0
  }
}

///|
pub fn decision_history_review_percent(history : DecisionHistory) -> Double {
  if history.entries.length() == 0 {
    0.0
  } else {
    history.review_count.to_double() /
    history.entries.length().to_double() *
    100.0
  }
}

///|
pub fn decision_history_critical_percent(history : DecisionHistory) -> Double {
  if history.entries.length() == 0 {
    0.0
  } else {
    history.critical_count.to_double() /
    history.entries.length().to_double() *
    100.0
  }
}

///|
pub fn decision_history_average_alerts(history : DecisionHistory) -> Double {
  mean_load_values(
    decision_history_alert_values(history).map(value => value.to_double()),
  )
}

///|
pub fn decision_history_average_events(history : DecisionHistory) -> Double {
  mean_load_values(
    decision_history_event_values(history).map(value => value.to_double()),
  )
}

///|
pub fn decision_history_average_actions(history : DecisionHistory) -> Double {
  mean_load_values(
    decision_history_action_values(history).map(value => value.to_double()),
  )
}

///|
pub fn decision_history_risk_minimum(history : DecisionHistory) -> Double {
  minimum_load_values(decision_history_risk_values(history))
}

///|
pub fn decision_history_risk_maximum(history : DecisionHistory) -> Double {
  maximum_load_values(decision_history_risk_values(history))
}

///|
pub fn decision_history_readiness_minimum(history : DecisionHistory) -> Double {
  minimum_load_values(decision_history_readiness_values(history))
}

///|
pub fn decision_history_readiness_maximum(history : DecisionHistory) -> Double {
  maximum_load_values(decision_history_readiness_values(history))
}

///|
pub fn decision_history_quality_average(history : DecisionHistory) -> Double {
  mean_load_values(decision_history_quality_values(history))
}

///|
pub fn decision_history_trend(history : DecisionHistory) -> LoadTrend {
  load_trend(decision_history_risk_values(history), 0.1)
}

///|
pub fn decision_history_summary(
  history : DecisionHistory,
) -> DecisionHistorySummary {
  {
    run_count: history.entries.length(),
    accepted_percent: decision_history_accepted_percent(history),
    review_percent: decision_history_review_percent(history),
    critical_percent: decision_history_critical_percent(history),
    risk_minimum: decision_history_risk_minimum(history),
    risk_maximum: decision_history_risk_maximum(history),
    readiness_minimum: decision_history_readiness_minimum(history),
    readiness_maximum: decision_history_readiness_maximum(history),
    quality_average: decision_history_quality_average(history),
    trend: decision_history_trend(history),
    status: history.latest_status,
  }
}

///|
pub fn decision_history_status(history : DecisionHistory) -> String {
  history.latest_status
}

///|
pub fn decision_history_valid(history : DecisionHistory) -> Bool {
  history.valid &&
  history.entries.all(entry => decision_history_entry_valid(entry)) &&
  history.accepted_count + history.review_count == history.entries.length()
}

///|
pub fn decision_history_entry_valid(entry : DecisionHistoryEntry) -> Bool {
  entry.sequence > 0 &&
  entry.run_id != "" &&
  entry.generated_for != "" &&
  entry.status != "" &&
  entry.risk_score >= 0.0 &&
  entry.risk_score <= 100.0 &&
  entry.readiness_score >= 0.0 &&
  entry.readiness_score <= 100.0 &&
  entry.quality_score >= 0.0 &&
  entry.quality_score <= 100.0 &&
  entry.alert_count >= 0 &&
  entry.event_count >= 0 &&
  entry.action_count >= 0
}

///|
pub fn decision_history_summary_valid(summary : DecisionHistorySummary) -> Bool {
  summary.run_count >= 0 &&
  summary.accepted_percent >= 0.0 &&
  summary.accepted_percent <= 100.0 &&
  summary.review_percent >= 0.0 &&
  summary.review_percent <= 100.0 &&
  summary.critical_percent >= 0.0 &&
  summary.critical_percent <= 100.0 &&
  summary.risk_minimum >= 0.0 &&
  summary.risk_maximum >= summary.risk_minimum &&
  summary.quality_average >= 0.0 &&
  summary.quality_average <= 100.0
}

///|
pub fn decision_history_compare(
  left : DecisionHistoryEntry,
  right : DecisionHistoryEntry,
) -> DecisionHistoryComparison {
  let risk_change = right.risk_score - left.risk_score
  let readiness_change = right.readiness_score - left.readiness_score
  {
    left,
    right,
    risk_change,
    readiness_change,
    quality_change: right.quality_score - left.quality_score,
    alert_change: right.alert_count - left.alert_count,
    direction: if risk_change < -2.0 {
      Improving
    } else if risk_change > 2.0 {
      Worsening
    } else {
      Stable
    },
    conclusion: if risk_change < -2.0 && readiness_change > 2.0 {
      "decision quality improved"
    } else if risk_change > 2.0 || readiness_change < -2.0 {
      "decision conditions worsened"
    } else {
      "decision conditions are stable"
    },
  }
}

///|
pub fn decision_history_compare_latest(
  history : DecisionHistory,
) -> DecisionHistoryComparison? {
  if history.entries.length() < 2 {
    None
  } else {
    Some(
      decision_history_compare(
        history.entries[history.entries.length() - 2],
        history.entries[history.entries.length() - 1],
      ),
    )
  }
}

///|
pub fn decision_history_compare_first_latest(
  history : DecisionHistory,
) -> DecisionHistoryComparison? {
  if history.entries.length() < 2 {
    None
  } else {
    Some(
      decision_history_compare(
        history.entries[0],
        history.entries[history.entries.length() - 1],
      ),
    )
  }
}

///|
pub fn decision_history_improving(history : DecisionHistory) -> Bool {
  match decision_history_compare_first_latest(history) {
    Some(comparison) => comparison.direction == Improving
    None => false
  }
}

///|
pub fn decision_history_worsening(history : DecisionHistory) -> Bool {
  match decision_history_compare_first_latest(history) {
    Some(comparison) => comparison.direction == Worsening
    None => false
  }
}

///|
pub fn decision_history_stable(history : DecisionHistory) -> Bool {
  !decision_history_improving(history) && !decision_history_worsening(history)
}

///|
pub fn decision_history_repeated_status(
  history : DecisionHistory,
  status : String,
) -> Int {
  history.entries.filter(entry => entry.status == status).length()
}

///|
pub fn decision_history_repeated_reviews(history : DecisionHistory) -> Int {
  decision_history_repeated_status(history, "review") +
  decision_history_repeated_status(history, "action_required")
}

///|
pub fn decision_history_consecutive_reviews(history : DecisionHistory) -> Int {
  let mut current = 0
  let mut longest = 0
  for entry in history.entries {
    if !entry.accepted {
      current += 1
      longest = longest.max(current)
    } else {
      current = 0
    }
  }
  longest
}

///|
pub fn decision_history_consecutive_critical(history : DecisionHistory) -> Int {
  let mut current = 0
  let mut longest = 0
  for entry in history.entries {
    if entry.status == "critical" {
      current += 1
      longest = longest.max(current)
    } else {
      current = 0
    }
  }
  longest
}

///|
pub fn decision_history_latest_risk(history : DecisionHistory) -> Double {
  match decision_history_latest(history) {
    Some(entry) => entry.risk_score
    None => 0.0
  }
}

///|
pub fn decision_history_latest_readiness(history : DecisionHistory) -> Double {
  match decision_history_latest(history) {
    Some(entry) => entry.readiness_score
    None => 0.0
  }
}

///|
pub fn decision_history_latest_quality(history : DecisionHistory) -> Double {
  match decision_history_latest(history) {
    Some(entry) => entry.quality_score
    None => 0.0
  }
}

///|
pub fn decision_history_latest_requires_action(
  history : DecisionHistory,
) -> Bool {
  match decision_history_latest(history) {
    Some(entry) => !entry.accepted || entry.action_count > 0
    None => false
  }
}

///|
pub fn decision_history_metric(
  history : DecisionHistory,
  name : String,
) -> Double {
  match name {
    "risk" => history.average_risk
    "readiness" => history.average_readiness
    "quality" => decision_history_quality_average(history)
    "alerts" => decision_history_average_alerts(history)
    "events" => decision_history_average_events(history)
    "actions" => decision_history_average_actions(history)
    "accepted_percent" => decision_history_accepted_percent(history)
    "review_percent" => decision_history_review_percent(history)
    _ => 0.0
  }
}

///|
pub fn decision_history_metric_names() -> Array[String] {
  [
    "risk", "readiness", "quality", "alerts", "events", "actions", "accepted_percent",
    "review_percent",
  ]
}

///|
pub fn decision_history_entry_metric(
  entry : DecisionHistoryEntry,
  name : String,
) -> Double {
  match name {
    "risk" => entry.risk_score
    "readiness" => entry.readiness_score
    "quality" => entry.quality_score
    "alerts" => entry.alert_count.to_double()
    "events" => entry.event_count.to_double()
    "actions" => entry.action_count.to_double()
    "accepted" => if entry.accepted { 1.0 } else { 0.0 }
    _ => 0.0
  }
}

///|
pub fn decision_history_projection(
  history : DecisionHistory,
  name : String,
) -> Array[Double] {
  history.entries.map(entry => decision_history_entry_metric(entry, name))
}

///|
pub fn decision_history_projection_average(
  history : DecisionHistory,
  name : String,
) -> Double {
  mean_load_values(decision_history_projection(history, name))
}

///|
pub fn decision_history_projection_minimum(
  history : DecisionHistory,
  name : String,
) -> Double {
  minimum_load_values(decision_history_projection(history, name))
}

///|
pub fn decision_history_projection_maximum(
  history : DecisionHistory,
  name : String,
) -> Double {
  maximum_load_values(decision_history_projection(history, name))
}

///|
pub fn decision_history_projection_deviation(
  history : DecisionHistory,
  name : String,
) -> Double {
  standard_deviation_values(decision_history_projection(history, name))
}

///|
pub fn decision_history_threshold_count(
  history : DecisionHistory,
  name : String,
  threshold : Double,
) -> Int {
  history.entries
  .filter(entry => decision_history_entry_metric(entry, name) >= threshold)
  .length()
}

///|
pub fn decision_history_threshold_percent(
  history : DecisionHistory,
  name : String,
  threshold : Double,
) -> Double {
  if history.entries.length() == 0 {
    0.0
  } else {
    decision_history_threshold_count(history, name, threshold).to_double() /
    history.entries.length().to_double() *
    100.0
  }
}

///|
pub fn decision_history_entry_csv_header() -> String {
  "sequence,run_id,generated_for,status,accepted,risk_score,readiness_score,quality_score,alert_count,event_count,action_count,checksum"
}

///|
pub fn decision_history_entry_csv(entry : DecisionHistoryEntry) -> String {
  entry.sequence.to_string() +
  "," +
  entry.run_id +
  "," +
  entry.generated_for +
  "," +
  entry.status +
  "," +
  entry.accepted.to_string() +
  "," +
  entry.risk_score.to_string() +
  "," +
  entry.readiness_score.to_string() +
  "," +
  entry.quality_score.to_string() +
  "," +
  entry.alert_count.to_string() +
  "," +
  entry.event_count.to_string() +
  "," +
  entry.action_count.to_string() +
  "," +
  entry.checksum
}

///|
pub fn decision_history_csv(history : DecisionHistory) -> String {
  let builder = StringBuilder::new()
  builder.write_string(decision_history_entry_csv_header())
  for entry in history.entries {
    builder.write_string("\n" + decision_history_entry_csv(entry))
  }
  builder.to_string()
}

///|
pub fn decision_history_entry_text(entry : DecisionHistoryEntry) -> String {
  "#" +
  entry.sequence.to_string() +
  " " +
  entry.run_id +
  " " +
  entry.generated_for +
  " status=" +
  entry.status +
  " accepted=" +
  entry.accepted.to_string() +
  " risk=" +
  entry.risk_score.to_string() +
  " readiness=" +
  entry.readiness_score.to_string() +
  " quality=" +
  entry.quality_score.to_string()
}

///|
pub fn decision_history_text(history : DecisionHistory) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "runs=" +
    history.entries.length().to_string() +
    " status=" +
    history.latest_status +
    " accepted=" +
    decision_history_accepted_percent(history).to_string() +
    "% average_risk=" +
    history.average_risk.to_string(),
  )
  for entry in history.entries {
    builder.write_string("\n" + decision_history_entry_text(entry))
  }
  builder.to_string()
}

///|
pub fn decision_history_summary_text(
  summary : DecisionHistorySummary,
) -> String {
  "runs=" +
  summary.run_count.to_string() +
  " accepted=" +
  summary.accepted_percent.to_string() +
  "% review=" +
  summary.review_percent.to_string() +
  "% critical=" +
  summary.critical_percent.to_string() +
  "% risk=" +
  summary.risk_minimum.to_string() +
  ".." +
  summary.risk_maximum.to_string() +
  " status=" +
  summary.status
}

///|
pub fn decision_history_comparison_text(
  comparison : DecisionHistoryComparison,
) -> String {
  comparison.left.run_id +
  " -> " +
  comparison.right.run_id +
  " risk_change=" +
  comparison.risk_change.to_string() +
  " readiness_change=" +
  comparison.readiness_change.to_string() +
  " quality_change=" +
  comparison.quality_change.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn decision_history_checksums(history : DecisionHistory) -> Array[String] {
  history.entries.map(entry => entry.checksum)
}

///|
pub fn decision_history_checksum(history : DecisionHistory) -> String {
  let mut value = history.entries.length()
  for character in decision_history_csv(history) {
    value = (value * 33 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn decision_history_reproducible(
  left : DecisionHistory,
  right : DecisionHistory,
) -> Bool {
  decision_history_checksum(left) == decision_history_checksum(right)
}

///|
pub fn decision_history_entry_checksum_valid(
  entry : DecisionHistoryEntry,
) -> Bool {
  entry.checksum != ""
}

///|
pub fn decision_history_entries_checksum_valid(
  history : DecisionHistory,
) -> Bool {
  history.entries.all(entry => decision_history_entry_checksum_valid(entry))
}

///|
pub fn decision_history_integrity_report(
  history : DecisionHistory,
) -> Array[String] {
  let messages = []
  if !decision_history_valid(history) {
    messages.push("history fields are invalid")
  }
  if !decision_history_entries_checksum_valid(history) {
    messages.push("history checksums are missing")
  }
  if decision_history_consecutive_critical(history) > 2 {
    messages.push("critical decisions are repeated")
  }
  messages
}

///|
pub fn decision_history_needs_review(history : DecisionHistory) -> Bool {
  decision_history_integrity_report(history).length() > 0 ||
  decision_history_consecutive_reviews(history) > 2
}

///|
pub fn decision_history_recommendation(history : DecisionHistory) -> String {
  if !decision_history_valid(history) {
    "repair history integrity"
  } else if decision_history_consecutive_critical(history) > 2 {
    "route repeated critical decisions for review"
  } else if decision_history_consecutive_reviews(history) > 2 {
    "review repeated non-accepted decisions"
  } else if decision_history_worsening(history) {
    "reduce exposure and inspect recent evidence"
  } else {
    "continue the current review cadence"
  }
}

///|
pub fn decision_history_action_line(history : DecisionHistory) -> String {
  "status=" +
  decision_history_status(history) +
  " review=" +
  decision_history_needs_review(history).to_string() +
  " recommendation=" +
  decision_history_recommendation(history)
}
