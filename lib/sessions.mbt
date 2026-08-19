///|
/// Training session categories used for workload distribution.
pub(all) enum SessionKind {
  Endurance
  Strength
  Speed
  Skills
  Competition
  Recovery
  Mixed
  Unknown
} derive(Debug, Eq, ToJson)

///|
pub(all) struct TrainingSession {
  id : String
  date : String
  duration_minutes : Double
  intensity : Double
  kind : SessionKind
  distance_km : Double?
  notes : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct SessionSummary {
  session_count : Int
  total_duration_minutes : Double
  total_load : Double
  average_intensity : Double
  high_intensity_count : Int
  recovery_session_count : Int
  endurance_load : Double
  strength_load : Double
  competition_load : Double
} derive(Debug, Eq, ToJson)

///|
pub fn new_session(
  id : String,
  date : String,
  duration_minutes : Double,
  intensity : Double,
  kind : SessionKind,
  distance_km : Double?,
  notes : String,
) -> TrainingSession {
  { id, date, duration_minutes, intensity, kind, distance_km, notes }
}

///|
pub fn session_load(session : TrainingSession) -> Double {
  session.duration_minutes * session.intensity
}

///|
pub fn session_is_valid(session : TrainingSession) -> Bool {
  let distance_valid = match session.distance_km {
    Some(distance) => distance >= 0.0
    None => true
  }
  parse_date(session.date) is Some(_) &&
  session.duration_minutes >= 0.0 &&
  session.intensity >= 0.0 &&
  session.intensity <= 10.0 &&
  distance_valid
}

///|
pub fn session_is_high_intensity(
  session : TrainingSession,
  threshold : Double,
) -> Bool {
  session.intensity >= threshold
}

///|
pub fn session_kind_name(kind : SessionKind) -> String {
  match kind {
    Endurance => "endurance"
    Strength => "strength"
    Speed => "speed"
    Skills => "skills"
    Competition => "competition"
    Recovery => "recovery"
    Mixed => "mixed"
    Unknown => "unknown"
  }
}

///|
pub fn sessions_from_records(
  records : Array[DailyRecord],
  kind : SessionKind,
) -> Array[TrainingSession] {
  let sessions = Array::new(capacity=records.length())
  for index, record in records {
    sessions.push(
      new_session(
        "session-" + (index + 1).to_string(),
        record.date,
        record.training_duration,
        record.training_intensity,
        kind,
        None,
        "derived from daily telemetry",
      ),
    )
  }
  sessions
}

///|
pub fn sessions_on_date(
  sessions : Array[TrainingSession],
  date : String,
) -> Array[TrainingSession] {
  sessions.filter(session => session.date == date)
}

///|
pub fn session_count_on_date(
  sessions : Array[TrainingSession],
  date : String,
) -> Int {
  sessions_on_date(sessions, date).length()
}

///|
pub fn session_loads(sessions : Array[TrainingSession]) -> Array[Double] {
  sessions.map(session => session_load(session))
}

///|
pub fn total_session_load(sessions : Array[TrainingSession]) -> Double {
  total_load_values(session_loads(sessions))
}

///|
pub fn total_session_duration(sessions : Array[TrainingSession]) -> Double {
  let mut total = 0.0
  for session in sessions {
    total += session.duration_minutes
  }
  total
}

///|
pub fn average_session_intensity(sessions : Array[TrainingSession]) -> Double {
  if sessions.length() == 0 {
    0.0
  } else {
    let mut total = 0.0
    for session in sessions {
      total += session.intensity
    }
    total / sessions.length().to_double()
  }
}

///|
pub fn high_intensity_sessions(
  sessions : Array[TrainingSession],
  threshold : Double,
) -> Array[TrainingSession] {
  sessions.filter(session => session_is_high_intensity(session, threshold))
}

///|
pub fn sessions_by_kind(
  sessions : Array[TrainingSession],
  kind : SessionKind,
) -> Array[TrainingSession] {
  sessions.filter(session => session.kind == kind)
}

///|
pub fn load_by_kind(
  sessions : Array[TrainingSession],
  kind : SessionKind,
) -> Double {
  total_session_load(sessions_by_kind(sessions, kind))
}

///|
pub fn summarize_sessions(
  sessions : Array[TrainingSession],
  high_intensity_threshold : Double,
) -> SessionSummary {
  {
    session_count: sessions.length(),
    total_duration_minutes: total_session_duration(sessions),
    total_load: total_session_load(sessions),
    average_intensity: average_session_intensity(sessions),
    high_intensity_count: high_intensity_sessions(
      sessions, high_intensity_threshold,
    ).length(),
    recovery_session_count: sessions_by_kind(sessions, Recovery).length(),
    endurance_load: load_by_kind(sessions, Endurance),
    strength_load: load_by_kind(sessions, Strength),
    competition_load: load_by_kind(sessions, Competition),
  }
}

///|
pub fn distribute_daily_session_load(
  records : Array[DailyRecord],
  sessions : Array[TrainingSession],
) -> Array[Double] {
  let output = Array::new(capacity=records.length())
  for record in records {
    output.push(total_session_load(sessions_on_date(sessions, record.date)))
  }
  output
}

///|
pub fn session_load_gap(
  records : Array[DailyRecord],
  sessions : Array[TrainingSession],
) -> Array[Double] {
  let gaps = []
  for record in records {
    let expected = daily_training_load(record)
    let observed = total_session_load(sessions_on_date(sessions, record.date))
    gaps.push(expected - observed)
  }
  gaps
}

///|
pub fn session_density(sessions : Array[TrainingSession]) -> Double {
  let duration = total_session_duration(sessions)
  if duration <= 0.0 {
    0.0
  } else {
    total_session_load(sessions) / duration
  }
}

///|
pub fn session_load_share(
  sessions : Array[TrainingSession],
  kind : SessionKind,
) -> Double {
  let total = total_session_load(sessions)
  if total == 0.0 {
    0.0
  } else {
    load_by_kind(sessions, kind) / total * 100.0
  }
}

///|
pub fn session_distance_total(sessions : Array[TrainingSession]) -> Double {
  let mut total = 0.0
  for session in sessions {
    match session.distance_km {
      Some(distance) => total += distance
      None => ()
    }
  }
  total
}

///|
pub fn session_distance_density(sessions : Array[TrainingSession]) -> Double {
  let duration = total_session_duration(sessions)
  if duration == 0.0 {
    0.0
  } else {
    session_distance_total(sessions) / duration * 60.0
  }
}

///|
pub fn merge_sessions(
  sessions : Array[TrainingSession],
) -> Array[TrainingSession] {
  let merged = []
  let dates = []
  for session in sessions {
    if !dates.contains(session.date) {
      dates.push(session.date)
      merged.push(session)
    } else {
      let mut index = 0
      for i in 0..<dates.length() {
        if dates[i] == session.date {
          index = i
          break
        }
      }
      let previous = merged[index]
      let combined_kind = if previous.kind == session.kind {
        previous.kind
      } else {
        Mixed
      }
      merged[index] = {
        id: previous.id,
        date: previous.date,
        duration_minutes: previous.duration_minutes + session.duration_minutes,
        intensity: if previous.duration_minutes + session.duration_minutes ==
          0.0 {
          0.0
        } else {
          (session_load(previous) + session_load(session)) /
          (previous.duration_minutes + session.duration_minutes)
        },
        kind: combined_kind,
        distance_km: match (previous.distance_km, session.distance_km) {
          (Some(left), Some(right)) => Some(left + right)
          (Some(value), None) | (None, Some(value)) => Some(value)
          _ => None
        },
        notes: previous.notes + "; " + session.notes,
      }
    }
  }
  merged
}

///|
pub fn session_to_text(session : TrainingSession) -> String {
  let distance = match session.distance_km {
    Some(value) => " distance=" + value.to_string() + "km"
    None => ""
  }
  session.id +
  " " +
  session.date +
  " " +
  session_kind_name(session.kind) +
  " duration=" +
  session.duration_minutes.to_string() +
  "min intensity=" +
  session.intensity.to_string() +
  distance
}
