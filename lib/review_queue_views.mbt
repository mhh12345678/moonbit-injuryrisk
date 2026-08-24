///|
/// Review queues give operators a deterministic view of work that needs attention.
pub(all) struct ReviewQueueRow {
  id : String
  date : String
  category : String
  title : String
  priority : RiskEventPriority
  score : Double
  status : String
  due_date : String
  overdue : Bool
  action : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ReviewQueueView {
  rows : Array[ReviewQueueRow]
  open_count : Int
  critical_count : Int
  urgent_count : Int
  overdue_count : Int
  average_score : Double
  status : String
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ReviewQueueComparison {
  left_open : Int
  right_open : Int
  open_change : Int
  left_critical : Int
  right_critical : Int
  critical_change : Int
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
fn review_queue_row(
  item : ActionQueueItem,
  reference_date : String,
) -> ReviewQueueRow {
  {
    id: item.id,
    date: item.date,
    category: item.category,
    title: item.title,
    priority: item.priority,
    score: item.score,
    status: intervention_status_name(item.status),
    due_date: item.due_date,
    overdue: item.due_date < reference_date &&
    item.status != Completed &&
    item.status != Cancelled,
    action: item.action,
  }
}

///|
fn review_queue_status_value(rows : Array[ReviewQueueRow]) -> String {
  if rows.any(row => {
      row.priority == Critical &&
      row.status != "completed" &&
      row.status != "cancelled"
    }) {
    "critical"
  } else if rows.any(row => {
      row.priority == Urgent &&
      row.status != "completed" &&
      row.status != "cancelled"
    }) {
    "urgent"
  } else if rows.any(row => {
      row.status != "completed" && row.status != "cancelled"
    }) {
    "open"
  } else {
    "clear"
  }
}

///|
pub fn build_review_queue(
  queue : ActionQueue,
  reference_date : String,
) -> ReviewQueueView {
  let rows = queue.items.map(item => review_queue_row(item, reference_date))
  let open = rows.filter(row => {
    row.status != "completed" && row.status != "cancelled"
  })
  let critical = open.filter(row => row.priority == Critical).length()
  let urgent = open.filter(row => row.priority == Urgent).length()
  let overdue = open.filter(row => row.overdue).length()
  {
    rows,
    open_count: open.length(),
    critical_count: critical,
    urgent_count: urgent,
    overdue_count: overdue,
    average_score: mean_load_values(open.map(row => row.score)),
    status: review_queue_status_value(rows),
    recommendation: if critical > 0 {
      "resolve critical work before progression"
    } else if urgent > 0 {
      "complete urgent follow-up in the next review"
    } else if overdue > 0 {
      "clear overdue items"
    } else {
      "continue routine monitoring"
    },
  }
}

///|
pub fn review_queue_for_run(
  run : DecisionRun,
  reference_date : String,
) -> ReviewQueueView {
  build_review_queue(build_action_queue(run), reference_date)
}

///|
pub fn review_queue_rows(view : ReviewQueueView) -> Array[ReviewQueueRow] {
  view.rows
}

///|
pub fn review_queue_open(view : ReviewQueueView) -> Array[ReviewQueueRow] {
  view.rows.filter(row => row.status != "completed" && row.status != "cancelled")
}

///|
pub fn review_queue_completed(view : ReviewQueueView) -> Array[ReviewQueueRow] {
  view.rows.filter(row => row.status == "completed")
}

///|
pub fn review_queue_overdue(view : ReviewQueueView) -> Array[ReviewQueueRow] {
  view.rows.filter(row => {
    row.overdue && row.status != "completed" && row.status != "cancelled"
  })
}

///|
pub fn review_queue_critical(view : ReviewQueueView) -> Array[ReviewQueueRow] {
  review_queue_open(view).filter(row => row.priority == Critical)
}

///|
pub fn review_queue_urgent(view : ReviewQueueView) -> Array[ReviewQueueRow] {
  review_queue_open(view).filter(row => row.priority == Urgent)
}

///|
pub fn review_queue_watch(view : ReviewQueueView) -> Array[ReviewQueueRow] {
  review_queue_open(view).filter(row => row.priority == Important)
}

///|
pub fn review_queue_by_id(
  view : ReviewQueueView,
  id : String,
) -> ReviewQueueRow? {
  for row in view.rows {
    if row.id == id {
      return Some(row)
    }
  }
  None
}

///|
pub fn review_queue_by_category(
  view : ReviewQueueView,
  category : String,
) -> Array[ReviewQueueRow] {
  view.rows.filter(row => row.category == category)
}

///|
pub fn review_queue_by_date(
  view : ReviewQueueView,
  date : String,
) -> Array[ReviewQueueRow] {
  view.rows.filter(row => row.date == date)
}

///|
pub fn review_queue_categories(view : ReviewQueueView) -> Array[String] {
  let values = []
  for row in view.rows {
    if !values.contains(row.category) {
      values.push(row.category)
    }
  }
  values
}

///|
pub fn review_queue_category_counts(view : ReviewQueueView) -> Array[Int] {
  review_queue_categories(view).map(category => {
    review_queue_by_category(view, category).length()
  })
}

///|
pub fn review_queue_priority_counts(view : ReviewQueueView) -> Array[Int] {
  [
    review_queue_open(view).filter(row => row.priority == Routine).length(),
    review_queue_open(view).filter(row => row.priority == Important).length(),
    review_queue_open(view).filter(row => row.priority == Urgent).length(),
    review_queue_open(view).filter(row => row.priority == Critical).length(),
  ]
}

///|
pub fn review_queue_status_counts(view : ReviewQueueView) -> Array[Int] {
  [
    view.rows.filter(row => row.status == "proposed").length(),
    view.rows.filter(row => row.status == "in_progress").length(),
    view.rows.filter(row => row.status == "completed").length(),
    view.rows.filter(row => row.status == "cancelled").length(),
  ]
}

///|
pub fn review_queue_count(view : ReviewQueueView) -> Int {
  view.rows.length()
}

///|
pub fn review_queue_open_count(view : ReviewQueueView) -> Int {
  view.open_count
}

///|
pub fn review_queue_critical_count(view : ReviewQueueView) -> Int {
  view.critical_count
}

///|
pub fn review_queue_urgent_count(view : ReviewQueueView) -> Int {
  view.urgent_count
}

///|
pub fn review_queue_overdue_count(view : ReviewQueueView) -> Int {
  view.overdue_count
}

///|
pub fn review_queue_average_score(view : ReviewQueueView) -> Double {
  view.average_score
}

///|
pub fn review_queue_status(view : ReviewQueueView) -> String {
  view.status
}

///|
pub fn review_queue_actionable(view : ReviewQueueView) -> Bool {
  view.open_count > 0
}

///|
pub fn review_queue_requires_escalation(view : ReviewQueueView) -> Bool {
  view.critical_count > 0
}

///|
pub fn review_queue_requires_review(view : ReviewQueueView) -> Bool {
  view.open_count > 0 || view.overdue_count > 0
}

///|
pub fn review_queue_valid_row(row : ReviewQueueRow) -> Bool {
  row.id != "" &&
  row.date != "" &&
  row.category != "" &&
  row.title != "" &&
  row.score >= 0.0 &&
  row.score <= 100.0 &&
  row.status != "" &&
  row.due_date != "" &&
  row.action != ""
}

///|
pub fn review_queue_valid(view : ReviewQueueView) -> Bool {
  view.rows.all(row => review_queue_valid_row(row)) &&
  view.open_count >= 0 &&
  view.critical_count >= 0 &&
  view.urgent_count >= 0 &&
  view.overdue_count >= 0 &&
  view.open_count <= view.rows.length() &&
  view.average_score >= 0.0 &&
  view.average_score <= 100.0
}

///|
pub fn review_queue_row_metric(row : ReviewQueueRow, name : String) -> Double {
  match name {
    "score" => row.score
    "priority" => risk_event_priority_rank_for_view(row.priority).to_double()
    "overdue" => if row.overdue { 1.0 } else { 0.0 }
    _ => 0.0
  }
}

///|
fn risk_event_priority_rank_for_view(priority : RiskEventPriority) -> Int {
  match priority {
    Routine => 0
    Important => 1
    Urgent => 2
    Critical => 3
  }
}

///|
pub fn review_queue_projection(
  view : ReviewQueueView,
  name : String,
) -> Array[Double] {
  view.rows.map(row => review_queue_row_metric(row, name))
}

///|
pub fn review_queue_projection_average(
  view : ReviewQueueView,
  name : String,
) -> Double {
  mean_load_values(review_queue_projection(view, name))
}

///|
pub fn review_queue_projection_maximum(
  view : ReviewQueueView,
  name : String,
) -> Double {
  maximum_load_values(review_queue_projection(view, name))
}

///|
pub fn review_queue_projection_minimum(
  view : ReviewQueueView,
  name : String,
) -> Double {
  minimum_load_values(review_queue_projection(view, name))
}

///|
pub fn review_queue_projection_deviation(
  view : ReviewQueueView,
  name : String,
) -> Double {
  standard_deviation_values(review_queue_projection(view, name))
}

///|
pub fn review_queue_priority_names() -> Array[String] {
  ["routine", "important", "urgent", "critical"]
}

///|
pub fn review_queue_row_action(row : ReviewQueueRow) -> String {
  row.action
}

///|
pub fn review_queue_row_status(row : ReviewQueueRow) -> String {
  row.status
}

///|
pub fn review_queue_row_priority(row : ReviewQueueRow) -> String {
  risk_event_priority_name(row.priority)
}

///|
pub fn review_queue_row_text(row : ReviewQueueRow) -> String {
  row.date +
  " " +
  row.category +
  " " +
  row.title +
  " priority=" +
  risk_event_priority_name(row.priority) +
  " score=" +
  row.score.to_string() +
  " status=" +
  row.status +
  " due=" +
  row.due_date +
  " overdue=" +
  row.overdue.to_string() +
  " action=" +
  row.action
}

///|
pub fn review_queue_text(view : ReviewQueueView) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "status=" +
    view.status +
    " rows=" +
    view.rows.length().to_string() +
    " open=" +
    view.open_count.to_string() +
    " critical=" +
    view.critical_count.to_string() +
    " urgent=" +
    view.urgent_count.to_string() +
    " overdue=" +
    view.overdue_count.to_string() +
    " average_score=" +
    view.average_score.to_string(),
  )
  builder.write_string("\nrecommendation=" + view.recommendation)
  for row in view.rows {
    builder.write_string("\n" + review_queue_row_text(row))
  }
  builder.to_string()
}

///|
pub fn review_queue_csv_header() -> String {
  "id,date,category,title,priority,score,status,due_date,overdue,action"
}

///|
pub fn review_queue_row_csv(row : ReviewQueueRow) -> String {
  row.id +
  "," +
  row.date +
  "," +
  row.category +
  "," +
  row.title +
  "," +
  risk_event_priority_name(row.priority) +
  "," +
  row.score.to_string() +
  "," +
  row.status +
  "," +
  row.due_date +
  "," +
  row.overdue.to_string() +
  "," +
  row.action
}

///|
pub fn review_queue_csv(view : ReviewQueueView) -> String {
  let builder = StringBuilder()
  builder.write_string(review_queue_csv_header())
  for row in view.rows {
    builder.write_string("\n" + review_queue_row_csv(row))
  }
  builder.to_string()
}

///|
pub fn review_queue_summary_header() -> Array[String] {
  [
    "status", "rows", "open", "critical", "urgent", "overdue", "average_score", "recommendation",
  ]
}

///|
pub fn review_queue_summary(view : ReviewQueueView) -> Array[String] {
  [
    view.status,
    view.rows.length().to_string(),
    view.open_count.to_string(),
    view.critical_count.to_string(),
    view.urgent_count.to_string(),
    view.overdue_count.to_string(),
    view.average_score.to_string(),
    view.recommendation,
  ]
}

///|
pub fn review_queue_summary_csv(view : ReviewQueueView) -> String {
  review_queue_summary_header().join(",") +
  "\n" +
  review_queue_summary(view).join(",")
}

///|
pub fn review_queue_compare(
  left : ReviewQueueView,
  right : ReviewQueueView,
) -> ReviewQueueComparison {
  {
    left_open: left.open_count,
    right_open: right.open_count,
    open_change: right.open_count - left.open_count,
    left_critical: left.critical_count,
    right_critical: right.critical_count,
    critical_change: right.critical_count - left.critical_count,
    conclusion: if right.critical_count < left.critical_count &&
      right.open_count <= left.open_count {
      "queue burden improved"
    } else if right.critical_count > left.critical_count ||
      right.open_count > left.open_count {
      "queue burden increased"
    } else {
      "queue burden is stable"
    },
  }
}

///|
pub fn review_queue_comparison_text(
  comparison : ReviewQueueComparison,
) -> String {
  "open=" +
  comparison.left_open.to_string() +
  " -> " +
  comparison.right_open.to_string() +
  " critical=" +
  comparison.left_critical.to_string() +
  " -> " +
  comparison.right_critical.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn review_queue_checksum(view : ReviewQueueView) -> String {
  let mut value = view.rows.length() + view.open_count
  for character in review_queue_text(view) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn review_queue_reproducible(
  left : ReviewQueueView,
  right : ReviewQueueView,
) -> Bool {
  review_queue_checksum(left) == review_queue_checksum(right)
}

///|
pub fn review_queue_contract(view : ReviewQueueView) -> Array[String] {
  [
    view.status,
    view.open_count.to_string(),
    view.critical_count.to_string(),
    view.urgent_count.to_string(),
    view.overdue_count.to_string(),
    review_queue_requires_review(view).to_string(),
    view.recommendation,
    review_queue_valid(view).to_string(),
    review_queue_checksum(view),
  ]
}
