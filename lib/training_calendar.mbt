///|
/// Calendar objects used to compare planned and completed sessions.
pub(all) struct ScheduleItem {
  id : String
  date : String
  title : String
  kind : SessionKind
  planned_duration : Double
  planned_intensity : Double
  planned_load : Double
  actual_duration : Double
  actual_load : Double
  completed : Bool
  recovery_day : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) enum ScheduleConflictKind {
  OverloadedDay
  MissingRecovery
  ExcessiveIntensity
  DuplicatePlan
  ActualOverTarget
  UnplannedSession
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ScheduleConflict {
  date : String
  kind : ScheduleConflictKind
  severity : RiskLevel
  value : Double
  threshold : Double
  message : String
  action : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ScheduleDay {
  date : String
  items : Array[ScheduleItem]
  planned_load : Double
  actual_load : Double
  recovery_day : Bool
  completed_percent : Double
  conflicts : Array[ScheduleConflict]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ScheduleSummary {
  start_date : String
  end_date : String
  days : Array[ScheduleDay]
  planned_load : Double
  actual_load : Double
  completion_percent : Double
  conflict_count : Int
  recovery_day_count : Int
  monotony : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
pub fn schedule_conflict_name(kind : ScheduleConflictKind) -> String {
  match kind {
    OverloadedDay => "overloaded_day"
    MissingRecovery => "missing_recovery"
    ExcessiveIntensity => "excessive_intensity"
    DuplicatePlan => "duplicate_plan"
    ActualOverTarget => "actual_over_target"
    UnplannedSession => "unplanned_session"
  }
}

///|
pub fn schedule_item(
  id : String,
  date : String,
  title : String,
  kind : SessionKind,
  duration : Double,
  intensity : Double,
) -> ScheduleItem {
  {
    id,
    date,
    title,
    kind,
    planned_duration: duration.max(0.0),
    planned_intensity: intensity.max(0.0).min(10.0),
    planned_load: duration.max(0.0) * intensity.max(0.0).min(10.0),
    actual_duration: 0.0,
    actual_load: 0.0,
    completed: false,
    recovery_day: kind == Recovery,
  }
}

///|
fn schedule_with_actual(
  item : ScheduleItem,
  session : TrainingSession?,
) -> ScheduleItem {
  match session {
    Some(session) =>
      {
        id: item.id,
        date: item.date,
        title: item.title,
        kind: item.kind,
        planned_duration: item.planned_duration,
        planned_intensity: item.planned_intensity,
        planned_load: item.planned_load,
        actual_duration: session.duration_minutes,
        actual_load: session_load(session),
        completed: true,
        recovery_day: item.recovery_day,
      }
    None => item
  }
}

///|
fn session_for_schedule(
  sessions : Array[TrainingSession],
  date : String,
  kind : SessionKind,
) -> TrainingSession? {
  for session in sessions_on_date(sessions, date) {
    if kind == Mixed || session.kind == kind {
      return Some(session)
    }
  }
  None
}

///|
pub fn attach_sessions_to_schedule(
  items : Array[ScheduleItem],
  sessions : Array[TrainingSession],
) -> Array[ScheduleItem] {
  items.map(item => {
    schedule_with_actual(
      item,
      session_for_schedule(sessions, item.date, item.kind),
    )
  })
}

///|
pub fn schedule_from_targets(
  targets : Array[TrainingTarget],
) -> Array[ScheduleItem] {
  targets.map(target => {
    schedule_item(
      "target-" + target.date,
      target.date,
      "planned training",
      target.target_kind,
      target.target_duration,
      target.target_intensity,
    )
  })
}

///|
pub fn schedule_from_plan(plan : TrainingPlan) -> Array[ScheduleItem] {
  let items = []
  for day in plan.days {
    let kind = if day.rest { SessionKind::Recovery } else { SessionKind::Mixed }
    let duration = if day.target_intensity == 0.0 {
      0.0
    } else {
      day.target_load / day.target_intensity
    }
    items.push(
      schedule_item(
        "plan-" + day.date,
        day.date,
        "planned training",
        kind,
        duration,
        day.target_intensity,
      ),
    )
  }
  items
}

///|
fn day_schedule_conflicts(
  date : String,
  items : Array[ScheduleItem],
  sessions : Array[TrainingSession],
) -> Array[ScheduleConflict] {
  let conflicts = []
  let planned = total_load_values(items.map(item => item.planned_load))
  let actual = total_session_load(sessions_on_date(sessions, date))
  let high_count = items.filter(item => item.planned_intensity >= 8.0).length()
  if planned > 900.0 {
    conflicts.push({
      date,
      kind: OverloadedDay,
      severity: High,
      value: planned,
      threshold: 900.0,
      message: "planned daily load is high",
      action: "split or reduce the planned load",
    })
  }
  if items.filter(item => item.recovery_day).length() == 0 && high_count >= 2 {
    conflicts.push({
      date,
      kind: MissingRecovery,
      severity: Medium,
      value: high_count.to_double(),
      threshold: 2.0,
      message: "multiple high-intensity items lack a recovery marker",
      action: "insert a recovery day in the block",
    })
  }
  if high_count > 1 {
    conflicts.push({
      date,
      kind: ExcessiveIntensity,
      severity: Medium,
      value: high_count.to_double(),
      threshold: 1.0,
      message: "more than one high-intensity session is planned",
      action: "separate high-intensity sessions",
    })
  }
  if actual > planned * 1.30 && planned > 0.0 {
    conflicts.push({
      date,
      kind: ActualOverTarget,
      severity: Medium,
      value: actual,
      threshold: planned * 1.30,
      message: "actual load exceeded the planned cap",
      action: "review the next session before progression",
    })
  }
  conflicts
}

///|
fn schedule_dates(
  items : Array[ScheduleItem],
  sessions : Array[TrainingSession],
) -> Array[String] {
  let dates = []
  for item in items {
    if !dates.contains(item.date) {
      dates.push(item.date)
    }
  }
  for session in sessions {
    if !dates.contains(session.date) {
      dates.push(session.date)
    }
  }
  let parsed = dates.filter(date => parse_date(date) is Some(_))
  let output = parsed.copy()
  for i in 1..<output.length() {
    let current = output[i]
    let mut cursor = i
    while cursor > 0 &&
          compare_dates(
            parse_date(output[cursor - 1]).unwrap(),
            parse_date(current).unwrap(),
          )
          is After {
      output[cursor] = output[cursor - 1]
      cursor -= 1
    }
    output[cursor] = current
  }
  output
}

///|
fn schedule_items_on_date(
  items : Array[ScheduleItem],
  date : String,
) -> Array[ScheduleItem] {
  items.filter(item => item.date == date)
}

///|
fn schedule_day(
  date : String,
  items : Array[ScheduleItem],
  sessions : Array[TrainingSession],
) -> ScheduleDay {
  let day_items = schedule_items_on_date(items, date)
  let conflicts = day_schedule_conflicts(date, day_items, sessions)
  let completed = day_items.filter(item => item.completed).length()
  {
    date,
    items: day_items,
    planned_load: total_load_values(day_items.map(item => item.planned_load)),
    actual_load: total_session_load(sessions_on_date(sessions, date)),
    recovery_day: day_items.any(item => item.recovery_day),
    completed_percent: if day_items.length() == 0 {
      0.0
    } else {
      completed.to_double() / day_items.length().to_double() * 100.0
    },
    conflicts,
  }
}

///|
fn schedule_status(days : Array[ScheduleDay]) -> String {
  if days.any(day => day.conflicts.any(conflict => conflict.severity == High)) {
    "high_conflict"
  } else if days.any(day => day.conflicts.length() > 0) {
    "review"
  } else if days.any(day => day.completed_percent < 100.0) {
    "in_progress"
  } else {
    "complete"
  }
}

///|
pub fn build_training_schedule(
  items : Array[ScheduleItem],
  sessions : Array[TrainingSession],
) -> ScheduleSummary {
  let attached = attach_sessions_to_schedule(items, sessions)
  let dates = schedule_dates(attached, sessions)
  let days = dates.map(date => schedule_day(date, attached, sessions))
  let planned = total_load_values(days.map(day => day.planned_load))
  let actual = total_load_values(days.map(day => day.actual_load))
  let completed = days.fold(init=0.0, (total, day) => {
    total + day.completed_percent
  })
  {
    start_date: if dates.length() == 0 {
      ""
    } else {
      dates[0]
    },
    end_date: if dates.length() == 0 {
      ""
    } else {
      dates[dates.length() - 1]
    },
    days,
    planned_load: planned,
    actual_load: actual,
    completion_percent: if days.length() == 0 {
      0.0
    } else {
      completed / days.length().to_double()
    },
    conflict_count: days.fold(init=0, (total, day) => {
      total + day.conflicts.length()
    }),
    recovery_day_count: days.filter(day => day.recovery_day).length(),
    monotony: workload_monotony(days.map(day => day.planned_load)),
    status: schedule_status(days),
  }
}

///|
pub fn schedule_day_for_date(
  summary : ScheduleSummary,
  date : String,
) -> ScheduleDay? {
  for day in summary.days {
    if day.date == date {
      return Some(day)
    }
  }
  None
}

///|
pub fn schedule_conflicts(summary : ScheduleSummary) -> Array[ScheduleConflict] {
  let output = []
  for day in summary.days {
    for conflict in day.conflicts {
      output.push(conflict)
    }
  }
  output
}

///|
pub fn schedule_conflict_dates(summary : ScheduleSummary) -> Array[String] {
  schedule_conflicts(summary).map(conflict => conflict.date)
}

///|
pub fn schedule_recovery_ratio(summary : ScheduleSummary) -> Double {
  if summary.days.length() == 0 {
    0.0
  } else {
    summary.recovery_day_count.to_double() / summary.days.length().to_double()
  }
}

///|
pub fn schedule_load_gap(summary : ScheduleSummary) -> Double {
  summary.actual_load - summary.planned_load
}

///|
pub fn schedule_over_target_percent(summary : ScheduleSummary) -> Double {
  percentage_change(summary.planned_load, summary.actual_load)
}

///|
pub fn schedule_is_balanced(summary : ScheduleSummary) -> Bool {
  summary.conflict_count == 0 &&
  summary.recovery_day_count > 0 &&
  summary.monotony < 2.0
}

///|
pub fn schedule_items(summary : ScheduleSummary) -> Array[ScheduleItem] {
  let output = []
  for day in summary.days {
    for item in day.items {
      output.push(item)
    }
  }
  output
}

///|
pub fn schedule_items_by_kind(
  summary : ScheduleSummary,
  kind : SessionKind,
) -> Array[ScheduleItem] {
  schedule_items(summary).filter(item => item.kind == kind)
}

///|
pub fn schedule_completed_items(
  summary : ScheduleSummary,
) -> Array[ScheduleItem] {
  schedule_items(summary).filter(item => item.completed)
}

///|
pub fn schedule_uncompleted_items(
  summary : ScheduleSummary,
) -> Array[ScheduleItem] {
  schedule_items(summary).filter(item => !item.completed)
}

///|
pub fn schedule_item_completion(summary : ScheduleSummary, id : String) -> Bool {
  for item in schedule_items(summary) {
    if item.id == id {
      return item.completed
    }
  }
  false
}

///|
pub fn schedule_conflict_kind_count(
  summary : ScheduleSummary,
  kind : ScheduleConflictKind,
) -> Int {
  schedule_conflicts(summary).filter(conflict => conflict.kind == kind).length()
}

///|
pub fn schedule_first_conflict(summary : ScheduleSummary) -> ScheduleConflict? {
  let conflicts = schedule_conflicts(summary)
  if conflicts.length() == 0 {
    None
  } else {
    Some(conflicts[0])
  }
}

///|
pub fn schedule_summary_text(summary : ScheduleSummary) -> String {
  "status=" +
  summary.status +
  " dates=" +
  summary.start_date +
  ".." +
  summary.end_date +
  " planned=" +
  summary.planned_load.to_string() +
  " actual=" +
  summary.actual_load.to_string() +
  " completion=" +
  summary.completion_percent.to_string() +
  "% conflicts=" +
  summary.conflict_count.to_string() +
  " recovery_days=" +
  summary.recovery_day_count.to_string() +
  " monotony=" +
  summary.monotony.to_string()
}

///|
pub fn schedule_day_csv_header() -> String {
  "date,planned_load,actual_load,recovery_day,completed_percent,conflict_count"
}

///|
pub fn schedule_day_csv(day : ScheduleDay) -> String {
  day.date +
  "," +
  day.planned_load.to_string() +
  "," +
  day.actual_load.to_string() +
  "," +
  day.recovery_day.to_string() +
  "," +
  day.completed_percent.to_string() +
  "," +
  day.conflicts.length().to_string()
}

///|
pub fn schedule_csv(summary : ScheduleSummary) -> String {
  let builder = StringBuilder::new()
  builder.write_string(schedule_day_csv_header())
  for day in summary.days {
    builder.write_string("\n")
    builder.write_string(schedule_day_csv(day))
  }
  builder.to_string()
}

///|
pub fn schedule_valid(summary : ScheduleSummary) -> Bool {
  summary.planned_load >= 0.0 &&
  summary.actual_load >= 0.0 &&
  summary.completion_percent >= 0.0 &&
  summary.completion_percent <= 100.0 &&
  summary.days.all(day => day.date != "" && day.planned_load >= 0.0)
}
