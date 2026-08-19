///|
/// Longitudinal adherence analytics for planned training and recovery actions.
pub(all) struct AdherenceDay {
  date : String
  target_status : AdherenceStatus
  target_load : Double
  actual_load : Double
  load_delta_percent : Double
  sleep_ok : Bool
  pain_ok : Bool
  recovery_ok : Bool
  completed : Bool
  score : Double
  note : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct AdherenceStreaks {
  completed_current : Int
  completed_longest : Int
  recovery_current : Int
  recovery_longest : Int
  missed_current : Int
  missed_longest : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) struct AdherenceAnalytics {
  days : Array[AdherenceDay]
  streaks : AdherenceStreaks
  planned_days : Int
  completed_days : Int
  recovery_days : Int
  missed_days : Int
  not_recorded_days : Int
  average_score : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) enum AdherenceTrend {
  AdherenceImproving
  AdherenceStable
  AdherenceDeclining
  AdherenceUnknown
} derive(Debug, Eq, ToJson)

///|
fn adherence_day_score(
  row : AdherenceRow,
  record : DailyRecord?,
  recovery_threshold : Double,
) -> AdherenceDay {
  match record {
    Some(record) => {
      let sleep_ok = record.sleep_hours >= 7.0
      let pain_ok = record.pain_level <= 4.0
      let recovery = record_recovery_score(
        record,
        default_recovery_weights(),
        8.0,
      )
      let recovery_ok = recovery >= recovery_threshold
      let base = match row.status {
        Met => 100.0
        Partial => 70.0
        Missed => 20.0
        NotRecorded => 0.0
      }
      let bonus = (if sleep_ok { 5.0 } else { 0.0 }) +
        (if pain_ok { 5.0 } else { 0.0 }) +
        (if recovery_ok { 5.0 } else { 0.0 })
      {
        date: row.date,
        target_status: row.status,
        target_load: row.target_load,
        actual_load: row.actual_load,
        load_delta_percent: row.load_difference_percent,
        sleep_ok,
        pain_ok,
        recovery_ok,
        completed: row.status == Met || row.status == Partial,
        score: (base + bonus).min(100.0),
        note: row.explanation,
      }
    }
    None =>
      {
        date: row.date,
        target_status: NotRecorded,
        target_load: row.target_load,
        actual_load: 0.0,
        load_delta_percent: -100.0,
        sleep_ok: false,
        pain_ok: false,
        recovery_ok: false,
        completed: false,
        score: 0.0,
        note: "no record for target date",
      }
  }
}

///|
fn adherence_record(
  records : Array[DailyRecord],
  date : String,
) -> DailyRecord? {
  for record in records {
    if record.date == date {
      return Some(record)
    }
  }
  None
}

///|
fn build_adherence_days(
  targets : Array[TrainingTarget],
  records : Array[DailyRecord],
  recovery_threshold : Double,
) -> Array[AdherenceDay] {
  let report = adherence_report(targets, records, recovery_threshold)
  let days = []
  for row in report.rows {
    days.push(
      adherence_day_score(
        row,
        adherence_record(records, row.date),
        recovery_threshold,
      ),
    )
  }
  days
}

///|
fn longest_streak(values : Array[Bool]) -> Int {
  let mut current = 0
  let mut longest = 0
  for value in values {
    if value {
      current += 1
      if current > longest {
        longest = current
      }
    } else {
      current = 0
    }
  }
  longest
}

///|
fn current_streak(values : Array[Bool]) -> Int {
  let mut current = 0
  for index in 0..<values.length() {
    let value = values[values.length() - index - 1]
    if value {
      current += 1
    } else {
      return current
    }
  }
  current
}

///|
fn build_adherence_streaks(days : Array[AdherenceDay]) -> AdherenceStreaks {
  let completed = days.map(day => day.completed)
  let recovery = days.map(day => day.recovery_ok)
  let missed = days.map(day => {
    day.target_status == Missed || day.target_status == NotRecorded
  })
  {
    completed_current: current_streak(completed),
    completed_longest: longest_streak(completed),
    recovery_current: current_streak(recovery),
    recovery_longest: longest_streak(recovery),
    missed_current: current_streak(missed),
    missed_longest: longest_streak(missed),
  }
}

///|
fn adherence_analytics_status(days : Array[AdherenceDay]) -> String {
  if days.length() == 0 {
    "empty"
  } else if days.any(day => day.score < 30.0) {
    "action_required"
  } else if days.filter(day => day.completed).length().to_double() /
    days.length().to_double() <
    0.70 {
    "review"
  } else {
    "on_track"
  }
}

///|
pub fn analyze_adherence(
  targets : Array[TrainingTarget],
  records : Array[DailyRecord],
  recovery_threshold : Double,
) -> AdherenceAnalytics {
  let days = build_adherence_days(targets, records, recovery_threshold)
  let scores = days.map(day => day.score)
  {
    days,
    streaks: build_adherence_streaks(days),
    planned_days: targets.length(),
    completed_days: days.filter(day => day.completed).length(),
    recovery_days: days.filter(day => day.recovery_ok).length(),
    missed_days: days.filter(day => day.target_status == Missed).length(),
    not_recorded_days: days
    .filter(day => day.target_status == NotRecorded)
    .length(),
    average_score: mean_load_values(scores),
    status: adherence_analytics_status(days),
  }
}

///|
pub fn adherence_trend(
  analytics : AdherenceAnalytics,
  window : Int,
) -> AdherenceTrend {
  if analytics.days.length() < window.max(2) * 2 {
    return AdherenceUnknown
  }
  let midpoint = analytics.days.length() / 2
  let first : Array[Double] = []
  let second : Array[Double] = []
  for index in 0..<midpoint {
    first.push(analytics.days[index].score)
  }
  for index in midpoint..<analytics.days.length() {
    second.push(analytics.days[index].score)
  }
  let change = mean_load_values(second) - mean_load_values(first)
  if change > 5.0 {
    AdherenceImproving
  } else if change < -5.0 {
    AdherenceDeclining
  } else {
    AdherenceStable
  }
}

///|
pub fn adherence_trend_name(trend : AdherenceTrend) -> String {
  match trend {
    AdherenceImproving => "improving"
    AdherenceStable => "stable"
    AdherenceDeclining => "declining"
    AdherenceUnknown => "unknown"
  }
}

///|
pub fn adherence_action_dates(analytics : AdherenceAnalytics) -> Array[String] {
  analytics.days.filter(day => day.score < 50.0).map(day => day.date)
}

///|
pub fn adherence_partial_dates(analytics : AdherenceAnalytics) -> Array[String] {
  analytics.days
  .filter(day => day.target_status == Partial)
  .map(day => day.date)
}

///|
pub fn adherence_success_dates(analytics : AdherenceAnalytics) -> Array[String] {
  analytics.days.filter(day => day.score >= 85.0).map(day => day.date)
}

///|
pub fn adherence_sleep_failure_dates(
  analytics : AdherenceAnalytics,
) -> Array[String] {
  analytics.days.filter(day => !day.sleep_ok).map(day => day.date)
}

///|
pub fn adherence_pain_failure_dates(
  analytics : AdherenceAnalytics,
) -> Array[String] {
  analytics.days.filter(day => !day.pain_ok).map(day => day.date)
}

///|
pub fn adherence_average_load_delta(analytics : AdherenceAnalytics) -> Double {
  mean_load_values(analytics.days.map(day => day.load_delta_percent))
}

///|
pub fn adherence_score_percentile(
  analytics : AdherenceAnalytics,
  percentile : Double,
) -> Double {
  quantile(analytics.days.map(day => day.score), percentile)
}

///|
pub fn adherence_status_counts(analytics : AdherenceAnalytics) -> Array[Int] {
  [
    analytics.days.filter(day => day.target_status == Met).length(),
    analytics.days.filter(day => day.target_status == Partial).length(),
    analytics.days.filter(day => day.target_status == Missed).length(),
    analytics.days.filter(day => day.target_status == NotRecorded).length(),
  ]
}

///|
pub fn adherence_is_actionable(analytics : AdherenceAnalytics) -> Bool {
  analytics.status == "action_required" || analytics.streaks.missed_current >= 2
}

///|
pub fn adherence_next_action(analytics : AdherenceAnalytics) -> String {
  if analytics.not_recorded_days > 0 {
    "collect missing telemetry"
  } else if analytics.missed_days > 0 {
    "review missed targets before adding load"
  } else if analytics.recovery_days < analytics.planned_days / 2 {
    "protect recovery before progression"
  } else {
    "continue the current plan"
  }
}

///|
pub fn adherence_analytics_text(analytics : AdherenceAnalytics) -> String {
  "status=" +
  analytics.status +
  " planned=" +
  analytics.planned_days.to_string() +
  " completed=" +
  analytics.completed_days.to_string() +
  " missed=" +
  analytics.missed_days.to_string() +
  " not_recorded=" +
  analytics.not_recorded_days.to_string() +
  " score=" +
  analytics.average_score.to_string() +
  " action=" +
  adherence_next_action(analytics)
}

///|
pub fn adherence_day_csv_header() -> String {
  "date,target_status,target_load,actual_load,load_delta_percent,sleep_ok,pain_ok,recovery_ok,completed,score,note"
}

///|
pub fn adherence_day_csv(day : AdherenceDay) -> String {
  day.date +
  "," +
  adherence_status_name(day.target_status) +
  "," +
  day.target_load.to_string() +
  "," +
  day.actual_load.to_string() +
  "," +
  day.load_delta_percent.to_string() +
  "," +
  day.sleep_ok.to_string() +
  "," +
  day.pain_ok.to_string() +
  "," +
  day.recovery_ok.to_string() +
  "," +
  day.completed.to_string() +
  "," +
  day.score.to_string() +
  "," +
  day.note
}

///|
pub fn adherence_analytics_csv(analytics : AdherenceAnalytics) -> String {
  let builder = StringBuilder::new()
  builder.write_string(adherence_day_csv_header())
  for day in analytics.days {
    builder.write_string("\n")
    builder.write_string(adherence_day_csv(day))
  }
  builder.to_string()
}

///|
pub fn adherence_analytics_valid(analytics : AdherenceAnalytics) -> Bool {
  analytics.planned_days >= 0 &&
  analytics.completed_days >= 0 &&
  analytics.average_score >= 0.0 &&
  analytics.average_score <= 100.0 &&
  analytics.days.all(day => {
    day.date != "" && day.score >= 0.0 && day.score <= 100.0
  })
}
