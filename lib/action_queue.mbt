///|
/// Prioritized action queue built from alerts, events, and interventions.
pub(all) struct ActionQueueItem {
  id : String
  date : String
  priority : RiskEventPriority
  category : String
  title : String
  action : String
  due_date : String
  status : InterventionStatus
  score : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ActionQueue {
  items : Array[ActionQueueItem]
  open_count : Int
  urgent_count : Int
  overdue_count : Int
  status : String
} derive(Debug, Eq, ToJson)

///|
fn action_item_from_alert(alert : MonitoringAlert) -> ActionQueueItem {
  let priority = match alert.severity {
    Info => Routine
    Watch => Important
    Action => Urgent
    Escalate => Critical
  }
  let score = match alert.severity {
    Info => 10.0
    Watch => 35.0
    Action => 70.0
    Escalate => 100.0
  }
  {
    id: alert.id,
    date: alert.date,
    priority,
    category: monitor_alert_kind_name(alert.kind),
    title: alert.title,
    action: alert.recommended_action,
    due_date: alert.date,
    status: Proposed,
    score,
  }
}

///|
fn action_item_from_intervention(item : Intervention) -> ActionQueueItem {
  let priority = match item.priority {
    Immediate => Critical
    Soon => Urgent
    Monitor => Important
    Positive => Routine
  }
  let score = match item.priority {
    Immediate => 100.0
    Soon => 70.0
    Monitor => 35.0
    Positive => 10.0
  }
  {
    id: item.id,
    date: item.date,
    priority,
    category: intervention_kind_name(item.kind),
    title: item.title,
    action: item.steps.join(";"),
    due_date: plan_review_date(item.date, item.review_after_days),
    status: item.status,
    score,
  }
}

///|
fn action_queue_status(items : Array[ActionQueueItem]) -> String {
  if items.any(item => item.priority == Critical && item.status != Completed) {
    "critical"
  } else if items.any(item => {
      item.priority == Urgent && item.status != Completed
    }) {
    "urgent"
  } else if items.any(item => item.status != Completed) {
    "open"
  } else {
    "clear"
  }
}

///|
pub fn build_action_queue(run : DecisionRun) -> ActionQueue {
  let items = []
  for alert in monitoring_alerts(run.monitoring) {
    items.push(action_item_from_alert(alert))
  }
  match run.interventions {
    Some(plan) =>
      for item in pending_interventions(plan) {
        items.push(action_item_from_intervention(item))
      }
    None => ()
  }
  let unique : Array[ActionQueueItem] = []
  for item in items {
    if unique.filter(existing => existing.id == item.id).length() == 0 {
      unique.push(item)
    }
  }
  let open = unique.filter(item => {
    item.status != Completed && item.status != Cancelled
  })
  let urgent = open
    .filter(item => item.priority == Urgent || item.priority == Critical)
    .length()
  {
    items: unique,
    open_count: open.length(),
    urgent_count: urgent,
    overdue_count: 0,
    status: action_queue_status(unique),
  }
}

///|
pub fn queue_open(queue : ActionQueue) -> Array[ActionQueueItem] {
  queue.items.filter(item => {
    item.status != Completed && item.status != Cancelled
  })
}

///|
pub fn queue_completed(queue : ActionQueue) -> Array[ActionQueueItem] {
  queue.items.filter(item => item.status == Completed)
}

///|
pub fn queue_by_priority(
  queue : ActionQueue,
  priority : RiskEventPriority,
) -> Array[ActionQueueItem] {
  queue_open(queue).filter(item => item.priority == priority)
}

///|
pub fn queue_by_category(
  queue : ActionQueue,
  category : String,
) -> Array[ActionQueueItem] {
  queue.items.filter(item => item.category == category)
}

///|
pub fn queue_top(queue : ActionQueue, limit : Int) -> Array[ActionQueueItem] {
  let sorted = queue_open(queue)
  let output = []
  let count = limit.max(0).min(sorted.length())
  for index in 0..<count {
    output.push(sorted[index])
  }
  output
}

///|
pub fn queue_find(queue : ActionQueue, id : String) -> ActionQueueItem? {
  for item in queue.items {
    if item.id == id {
      return Some(item)
    }
  }
  None
}

///|
fn action_item_status(
  item : ActionQueueItem,
  status : InterventionStatus,
) -> ActionQueueItem {
  {
    id: item.id,
    date: item.date,
    priority: item.priority,
    category: item.category,
    title: item.title,
    action: item.action,
    due_date: item.due_date,
    status,
    score: item.score,
  }
}

///|
pub fn queue_update_status(
  queue : ActionQueue,
  id : String,
  status : InterventionStatus,
) -> ActionQueue {
  let items = queue.items.map(item => {
    if item.id == id {
      action_item_status(item, status)
    } else {
      item
    }
  })
  let open = items.filter(item => {
    item.status != Completed && item.status != Cancelled
  })
  {
    items,
    open_count: open.length(),
    urgent_count: open
    .filter(item => item.priority == Urgent || item.priority == Critical)
    .length(),
    overdue_count: queue.overdue_count,
    status: action_queue_status(items),
  }
}

///|
pub fn queue_complete(queue : ActionQueue, id : String) -> ActionQueue {
  queue_update_status(queue, id, Completed)
}

///|
pub fn queue_defer(queue : ActionQueue, id : String) -> ActionQueue {
  queue_update_status(queue, id, Deferred)
}

///|
pub fn queue_action_count(queue : ActionQueue) -> Int {
  queue_open(queue)
  .filter(item => item.priority == Urgent || item.priority == Critical)
  .length()
}

///|
pub fn queue_score(queue : ActionQueue) -> Double {
  mean_load_values(queue_open(queue).map(item => item.score))
}

///|
pub fn queue_is_clear(queue : ActionQueue) -> Bool {
  queue_open(queue).length() == 0
}

///|
pub fn queue_requires_review(queue : ActionQueue) -> Bool {
  queue.urgent_count > 0 || queue.overdue_count > 0
}

///|
pub fn queue_next_action(queue : ActionQueue) -> String {
  let top = queue_top(queue, 1)
  if top.length() == 0 {
    "no open action"
  } else {
    top[0].action
  }
}

///|
pub fn queue_category_names(queue : ActionQueue) -> Array[String] {
  let names = []
  for item in queue.items {
    if !names.contains(item.category) {
      names.push(item.category)
    }
  }
  names
}

///|
pub fn action_queue_text(queue : ActionQueue) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "status=" +
    queue.status +
    " items=" +
    queue.items.length().to_string() +
    " open=" +
    queue.open_count.to_string() +
    " urgent=" +
    queue.urgent_count.to_string() +
    " score=" +
    queue_score(queue).to_string() +
    " next=" +
    queue_next_action(queue),
  )
  for item in queue_open(queue) {
    builder.write_string(
      "\n" +
      item.date +
      " " +
      risk_event_priority_name(item.priority) +
      " " +
      item.category +
      " " +
      item.title +
      " action=" +
      item.action,
    )
  }
  builder.to_string()
}

///|
pub fn action_queue_csv_header() -> String {
  "id,date,priority,category,title,action,due_date,status,score"
}

///|
pub fn action_queue_csv(item : ActionQueueItem) -> String {
  item.id +
  "," +
  item.date +
  "," +
  risk_event_priority_name(item.priority) +
  "," +
  item.category +
  "," +
  item.title +
  "," +
  item.action +
  "," +
  item.due_date +
  "," +
  intervention_status_name(item.status) +
  "," +
  item.score.to_string()
}

///|
pub fn action_queue_csv_text(queue : ActionQueue) -> String {
  let builder = StringBuilder()
  builder.write_string(action_queue_csv_header())
  for item in queue.items {
    builder.write_string("\n")
    builder.write_string(action_queue_csv(item))
  }
  builder.to_string()
}

///|
pub fn action_queue_valid(queue : ActionQueue) -> Bool {
  queue.open_count >= 0 &&
  queue.urgent_count >= 0 &&
  queue.overdue_count >= 0 &&
  queue.items.all(item => {
    item.id != "" && item.title != "" && item.action != "" && item.score >= 0.0
  })
}
