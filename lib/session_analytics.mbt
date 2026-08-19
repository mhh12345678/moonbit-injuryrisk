///|
/// Session-level analytics for intensity distribution and load composition.
pub(all) struct SessionDaySummary {
  date : String
  session_count : Int
  duration_minutes : Double
  total_load : Double
  average_intensity : Double
  high_intensity_count : Int
  kind_diversity : Int
  distance_km : Double
  recovery_session : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct SessionAnalytics {
  days : Array[SessionDaySummary]
  session_count : Int
  training_days : Int
  rest_days : Int
  total_duration : Double
  total_load : Double
  average_intensity : Double
  high_intensity_percent : Double
  distance_total : Double
  kind_shares : Array[Double]
  status : String
} derive(Debug, Eq, ToJson)

///|
fn session_dates(sessions : Array[TrainingSession]) -> Array[String] {
  let dates = []
  for session in sessions {
    if !dates.contains(session.date) {
      dates.push(session.date)
    }
  }
  dates
}

///|
fn session_kind_diversity(sessions : Array[TrainingSession]) -> Int {
  let names = []
  for session in sessions {
    let name = session_kind_name(session.kind)
    if !names.contains(name) {
      names.push(name)
    }
  }
  names.length()
}

///|
fn session_day_summary(
  sessions : Array[TrainingSession],
  date : String,
  high_threshold : Double,
) -> SessionDaySummary {
  let day = sessions_on_date(sessions, date)
  {
    date,
    session_count: day.length(),
    duration_minutes: total_session_duration(day),
    total_load: total_session_load(day),
    average_intensity: average_session_intensity(day),
    high_intensity_count: high_intensity_sessions(day, high_threshold).length(),
    kind_diversity: session_kind_diversity(day),
    distance_km: session_distance_total(day),
    recovery_session: day.any(session => session.kind == SessionKind::Recovery),
  }
}

///|
pub fn build_session_day_summaries(
  sessions : Array[TrainingSession],
  high_threshold : Double,
) -> Array[SessionDaySummary] {
  session_dates(sessions).map(date => {
    session_day_summary(sessions, date, high_threshold)
  })
}

///|
fn session_analytics_status(days : Array[SessionDaySummary]) -> String {
  if days.length() == 0 {
    "empty"
  } else if days.any(day => day.high_intensity_count >= 2) {
    "intensity_review"
  } else if days.any(day => day.total_load > 900.0) {
    "load_review"
  } else {
    "stable"
  }
}

///|
pub fn analyze_sessions(
  sessions : Array[TrainingSession],
  high_threshold : Double,
) -> SessionAnalytics {
  let days = build_session_day_summaries(sessions, high_threshold)
  let high_count = sessions
    .filter(session => session.intensity >= high_threshold)
    .length()
  {
    days,
    session_count: sessions.length(),
    training_days: days.filter(day => day.total_load > 0.0).length(),
    rest_days: days.filter(day => day.total_load == 0.0).length(),
    total_duration: total_session_duration(sessions),
    total_load: total_session_load(sessions),
    average_intensity: average_session_intensity(sessions),
    high_intensity_percent: if sessions.length() == 0 {
      0.0
    } else {
      high_count.to_double() / sessions.length().to_double() * 100.0
    },
    distance_total: session_distance_total(sessions),
    kind_shares: [
      session_load_share(sessions, Endurance),
      session_load_share(sessions, Strength),
      session_load_share(sessions, Speed),
      session_load_share(sessions, Recovery),
      session_load_share(sessions, Competition),
    ],
    status: session_analytics_status(days),
  }
}

///|
pub fn session_day_for_date(
  analytics : SessionAnalytics,
  date : String,
) -> SessionDaySummary? {
  for day in analytics.days {
    if day.date == date {
      return Some(day)
    }
  }
  None
}

///|
pub fn session_high_intensity_days(
  analytics : SessionAnalytics,
) -> Array[String] {
  analytics.days
  .filter(day => day.high_intensity_count > 0)
  .map(day => day.date)
}

///|
pub fn session_heavy_days(
  analytics : SessionAnalytics,
  threshold : Double,
) -> Array[String] {
  analytics.days.filter(day => day.total_load >= threshold).map(day => day.date)
}

///|
pub fn session_recovery_days(analytics : SessionAnalytics) -> Array[String] {
  analytics.days.filter(day => day.recovery_session).map(day => day.date)
}

///|
pub fn session_density_by_day(analytics : SessionAnalytics) -> Array[Double] {
  analytics.days.map(day => {
    if day.duration_minutes == 0.0 {
      0.0
    } else {
      day.total_load / day.duration_minutes
    }
  })
}

///|
pub fn session_load_trend(analytics : SessionAnalytics) -> LoadTrend {
  load_trend(analytics.days.map(day => day.total_load), 0.1)
}

///|
pub fn session_intensity_trend(analytics : SessionAnalytics) -> LoadTrend {
  load_trend(analytics.days.map(day => day.average_intensity), 0.1)
}

///|
pub fn session_kind_share(analytics : SessionAnalytics, index : Int) -> Double {
  if index < 0 || index >= analytics.kind_shares.length() {
    0.0
  } else {
    analytics.kind_shares[index]
  }
}

///|
pub fn session_balance_score(analytics : SessionAnalytics) -> Double {
  let recovery = if analytics.days.length() == 0 {
    0.0
  } else {
    analytics.rest_days.to_double() /
    analytics.days.length().to_double() *
    100.0
  }
  let high_penalty = analytics.high_intensity_percent.min(100.0)
  (recovery * 0.5 + (100.0 - high_penalty) * 0.5).min(100.0)
}

///|
pub fn session_needs_review(analytics : SessionAnalytics) -> Bool {
  analytics.status != "stable" || session_balance_score(analytics) < 50.0
}

///|
pub fn session_next_action(analytics : SessionAnalytics) -> String {
  if analytics.status == "intensity_review" {
    "separate high-intensity sessions"
  } else if analytics.status == "load_review" {
    "reduce the next daily load"
  } else if analytics.rest_days == 0 && analytics.session_count > 0 {
    "insert a recovery day"
  } else {
    "continue session distribution monitoring"
  }
}

///|
pub fn session_analytics_text(analytics : SessionAnalytics) -> String {
  "status=" +
  analytics.status +
  " sessions=" +
  analytics.session_count.to_string() +
  " training_days=" +
  analytics.training_days.to_string() +
  " rest_days=" +
  analytics.rest_days.to_string() +
  " duration=" +
  analytics.total_duration.to_string() +
  " load=" +
  analytics.total_load.to_string() +
  " high_intensity=" +
  analytics.high_intensity_percent.to_string() +
  "% balance=" +
  session_balance_score(analytics).to_string() +
  " action=" +
  session_next_action(analytics)
}

///|
pub fn session_day_csv_header() -> String {
  "date,session_count,duration_minutes,total_load,average_intensity,high_intensity_count,kind_diversity,distance_km,recovery_session"
}

///|
pub fn session_day_csv(day : SessionDaySummary) -> String {
  day.date +
  "," +
  day.session_count.to_string() +
  "," +
  day.duration_minutes.to_string() +
  "," +
  day.total_load.to_string() +
  "," +
  day.average_intensity.to_string() +
  "," +
  day.high_intensity_count.to_string() +
  "," +
  day.kind_diversity.to_string() +
  "," +
  day.distance_km.to_string() +
  "," +
  day.recovery_session.to_string()
}

///|
pub fn session_analytics_csv(analytics : SessionAnalytics) -> String {
  let builder = StringBuilder::new()
  builder.write_string(session_day_csv_header())
  for day in analytics.days {
    builder.write_string("\n")
    builder.write_string(session_day_csv(day))
  }
  builder.to_string()
}

///|
pub fn session_analytics_valid(analytics : SessionAnalytics) -> Bool {
  analytics.session_count >= 0 &&
  analytics.training_days >= 0 &&
  analytics.rest_days >= 0 &&
  analytics.total_duration >= 0.0 &&
  analytics.total_load >= 0.0 &&
  analytics.average_intensity >= 0.0 &&
  analytics.average_intensity <= 10.0 &&
  analytics.days.all(day => day.date != "" && day.total_load >= 0.0)
}
