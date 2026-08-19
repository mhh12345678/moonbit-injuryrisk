///|
/// Recovery check-ins and protocol adherence for daily use.
pub(all) enum RecoveryCheckinStatus {
  RecoveryGood
  RecoveryWatch
  RecoveryAction
  RecoveryMissing
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RecoveryCheckin {
  date : String
  sleep_hours : Double
  sleep_quality : Double
  fatigue : Double
  pain : Double
  recovery_score : Double
  status : RecoveryCheckinStatus
  completed : Bool
  notes : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RecoveryProtocol {
  name : String
  target_sleep_hours : Double
  minimum_sleep_quality : Double
  maximum_fatigue : Double
  maximum_pain : Double
  minimum_recovery_score : Double
  checkins : Array[RecoveryCheckin]
  completion_percent : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RecoveryStreak {
  current : Int
  longest : Int
  good_days : Int
  watch_days : Int
  action_days : Int
  missing_days : Int
} derive(Debug, Eq, ToJson)

///|
pub fn recovery_checkin_status_name(status : RecoveryCheckinStatus) -> String {
  match status {
    RecoveryGood => "good"
    RecoveryWatch => "watch"
    RecoveryAction => "action"
    RecoveryMissing => "missing"
  }
}

///|
pub fn default_recovery_protocol() -> RecoveryProtocol {
  {
    name: "daily recovery protocol",
    target_sleep_hours: 8.0,
    minimum_sleep_quality: 4.0,
    maximum_fatigue: 6.0,
    maximum_pain: 3.0,
    minimum_recovery_score: 70.0,
    checkins: [],
    completion_percent: 0.0,
    status: "empty",
  }
}

///|
fn recovery_checkin_status(
  sleep_hours : Double,
  sleep_quality : Double,
  fatigue : Double,
  pain : Double,
  recovery_score : Double,
  protocol : RecoveryProtocol,
) -> RecoveryCheckinStatus {
  if recovery_score >= protocol.minimum_recovery_score &&
    sleep_hours >= protocol.target_sleep_hours &&
    sleep_quality >= protocol.minimum_sleep_quality &&
    fatigue <= protocol.maximum_fatigue &&
    pain <= protocol.maximum_pain {
    RecoveryGood
  } else if pain > protocol.maximum_pain + 2.0 ||
    fatigue > protocol.maximum_fatigue + 2.0 ||
    recovery_score < protocol.minimum_recovery_score - 20.0 {
    RecoveryAction
  } else {
    RecoveryWatch
  }
}

///|
pub fn recovery_checkin(
  date : String,
  record : DailyRecord,
  policy : RiskPolicy,
  protocol : RecoveryProtocol,
) -> RecoveryCheckin {
  let score = record_recovery_score(
    record,
    policy.recovery_weights,
    policy.sleep_target,
  )
  {
    date,
    sleep_hours: record.sleep_hours,
    sleep_quality: record.sleep_quality,
    fatigue: record.fatigue,
    pain: record.pain_level,
    recovery_score: score,
    status: recovery_checkin_status(
      record.sleep_hours,
      record.sleep_quality,
      record.fatigue,
      record.pain_level,
      score,
      protocol,
    ),
    completed: true,
    notes: if record.pain_site is Some(site) {
      "pain_site=" + site
    } else {
      ""
    },
  }
}

///|
pub fn missing_recovery_checkin(date : String) -> RecoveryCheckin {
  {
    date,
    sleep_hours: 0.0,
    sleep_quality: 0.0,
    fatigue: 0.0,
    pain: 0.0,
    recovery_score: 0.0,
    status: RecoveryMissing,
    completed: false,
    notes: "no daily recovery record",
  }
}

///|
pub fn build_recovery_checkins(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  protocol : RecoveryProtocol,
) -> Array[RecoveryCheckin] {
  let checkins = []
  for record in sort_records_by_date(records) {
    checkins.push(recovery_checkin(record.date, record, policy, protocol))
  }
  checkins
}

///|
fn recovery_protocol_status(checkins : Array[RecoveryCheckin]) -> String {
  if checkins.length() == 0 {
    "empty"
  } else if checkins.any(item => {
      item.status == RecoveryCheckinStatus::RecoveryAction
    }) {
    "action_required"
  } else if checkins.any(item => {
      item.status == RecoveryCheckinStatus::RecoveryWatch
    }) {
    "watch"
  } else if checkins.any(item => item.status == RecoveryMissing) {
    "incomplete"
  } else {
    "on_track"
  }
}

///|
pub fn build_recovery_protocol(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  protocol : RecoveryProtocol,
) -> RecoveryProtocol {
  let checkins = build_recovery_checkins(records, policy, protocol)
  let completed = checkins.filter(item => item.completed).length()
  {
    name: protocol.name,
    target_sleep_hours: protocol.target_sleep_hours,
    minimum_sleep_quality: protocol.minimum_sleep_quality,
    maximum_fatigue: protocol.maximum_fatigue,
    maximum_pain: protocol.maximum_pain,
    minimum_recovery_score: protocol.minimum_recovery_score,
    checkins,
    completion_percent: if checkins.length() == 0 {
      0.0
    } else {
      completed.to_double() / checkins.length().to_double() * 100.0
    },
    status: recovery_protocol_status(checkins),
  }
}

///|
pub fn add_recovery_checkin(
  protocol : RecoveryProtocol,
  checkin : RecoveryCheckin,
) -> RecoveryProtocol {
  let checkins = protocol.checkins.filter(item => item.date != checkin.date) +
    [checkin]
  let completed = checkins.filter(item => item.completed).length()
  {
    name: protocol.name,
    target_sleep_hours: protocol.target_sleep_hours,
    minimum_sleep_quality: protocol.minimum_sleep_quality,
    maximum_fatigue: protocol.maximum_fatigue,
    maximum_pain: protocol.maximum_pain,
    minimum_recovery_score: protocol.minimum_recovery_score,
    checkins,
    completion_percent: if checkins.length() == 0 {
      0.0
    } else {
      completed.to_double() / checkins.length().to_double() * 100.0
    },
    status: recovery_protocol_status(checkins),
  }
}

///|
pub fn checkin_for_date(
  protocol : RecoveryProtocol,
  date : String,
) -> RecoveryCheckin? {
  for checkin in protocol.checkins {
    if checkin.date == date {
      return Some(checkin)
    }
  }
  None
}

///|
pub fn recovery_good_days(protocol : RecoveryProtocol) -> Array[String] {
  protocol.checkins
  .filter(item => item.status == RecoveryGood)
  .map(item => item.date)
}

///|
pub fn recovery_watch_days(protocol : RecoveryProtocol) -> Array[String] {
  protocol.checkins
  .filter(item => item.status == RecoveryWatch)
  .map(item => item.date)
}

///|
pub fn recovery_action_days(protocol : RecoveryProtocol) -> Array[String] {
  protocol.checkins
  .filter(item => item.status == RecoveryAction)
  .map(item => item.date)
}

///|
pub fn recovery_missing_days(protocol : RecoveryProtocol) -> Array[String] {
  protocol.checkins
  .filter(item => item.status == RecoveryMissing)
  .map(item => item.date)
}

///|
pub fn protocol_recovery_scores(protocol : RecoveryProtocol) -> Array[Double] {
  protocol.checkins
  .filter(item => item.completed)
  .map(item => item.recovery_score)
}

///|
pub fn recovery_average_score(protocol : RecoveryProtocol) -> Double {
  mean_load_values(protocol_recovery_scores(protocol))
}

///|
pub fn recovery_sleep_average(protocol : RecoveryProtocol) -> Double {
  mean_load_values(
    protocol.checkins
    .filter(item => item.completed)
    .map(item => item.sleep_hours),
  )
}

///|
pub fn recovery_fatigue_average(protocol : RecoveryProtocol) -> Double {
  mean_load_values(
    protocol.checkins.filter(item => item.completed).map(item => item.fatigue),
  )
}

///|
pub fn recovery_streak(protocol : RecoveryProtocol) -> RecoveryStreak {
  let mut current = 0
  let mut longest = 0
  for checkin in protocol.checkins {
    if checkin.status == RecoveryGood {
      current += 1
      if current > longest {
        longest = current
      }
    } else {
      current = 0
    }
  }
  {
    current,
    longest,
    good_days: recovery_good_days(protocol).length(),
    watch_days: recovery_watch_days(protocol).length(),
    action_days: recovery_action_days(protocol).length(),
    missing_days: recovery_missing_days(protocol).length(),
  }
}

///|
pub fn recovery_adherence_score(protocol : RecoveryProtocol) -> Double {
  if protocol.checkins.length() == 0 {
    0.0
  } else {
    protocol.checkins
    .filter(item => item.completed && item.status == RecoveryGood)
    .length()
    .to_double() /
    protocol.checkins.length().to_double() *
    100.0
  }
}

///|
pub fn recovery_protocol_is_safe(protocol : RecoveryProtocol) -> Bool {
  protocol.status == "on_track" && recovery_action_days(protocol).length() == 0
}

///|
pub fn recovery_protocol_next_action(protocol : RecoveryProtocol) -> String {
  if recovery_missing_days(protocol).length() > 0 {
    "complete the missing recovery check-ins"
  } else if recovery_action_days(protocol).length() > 0 {
    "reduce load and review the action days"
  } else if recovery_watch_days(protocol).length() > 0 {
    "continue check-ins and hold progression"
  } else {
    "continue the recovery routine"
  }
}

///|
pub fn recovery_protocol_text(protocol : RecoveryProtocol) -> String {
  let streak = recovery_streak(protocol)
  "name=" +
  protocol.name +
  " status=" +
  protocol.status +
  " completion=" +
  protocol.completion_percent.to_string() +
  "%" +
  " average_score=" +
  recovery_average_score(protocol).to_string() +
  " good_streak=" +
  streak.current.to_string() +
  " action=" +
  recovery_protocol_next_action(protocol)
}

///|
pub fn recovery_checkin_csv_header() -> String {
  "date,sleep_hours,sleep_quality,fatigue,pain,recovery_score,status,completed,notes"
}

///|
pub fn recovery_checkin_csv(checkin : RecoveryCheckin) -> String {
  checkin.date +
  "," +
  checkin.sleep_hours.to_string() +
  "," +
  checkin.sleep_quality.to_string() +
  "," +
  checkin.fatigue.to_string() +
  "," +
  checkin.pain.to_string() +
  "," +
  checkin.recovery_score.to_string() +
  "," +
  recovery_checkin_status_name(checkin.status) +
  "," +
  checkin.completed.to_string() +
  "," +
  checkin.notes
}

///|
pub fn recovery_protocol_csv(protocol : RecoveryProtocol) -> String {
  let builder = StringBuilder::new()
  builder.write_string(recovery_checkin_csv_header())
  for checkin in protocol.checkins {
    builder.write_string("\n")
    builder.write_string(recovery_checkin_csv(checkin))
  }
  builder.to_string()
}

///|
pub fn recovery_protocol_valid(protocol : RecoveryProtocol) -> Bool {
  protocol.name != "" &&
  protocol.target_sleep_hours >= 0.0 &&
  protocol.minimum_sleep_quality >= 0.0 &&
  protocol.maximum_fatigue >= 0.0 &&
  protocol.maximum_pain >= 0.0 &&
  protocol.minimum_recovery_score >= 0.0 &&
  protocol.minimum_recovery_score <= 100.0 &&
  protocol.checkins.all(item => {
    item.date != "" &&
    item.recovery_score >= 0.0 &&
    item.recovery_score <= 100.0
  })
}

///|
pub fn recovery_status_catalog() -> Array[String] {
  [
    recovery_checkin_status_name(RecoveryGood),
    recovery_checkin_status_name(RecoveryWatch),
    recovery_checkin_status_name(RecoveryAction),
    recovery_checkin_status_name(RecoveryMissing),
  ]
}

///|
pub fn recovery_protocol_window(
  protocol : RecoveryProtocol,
  start : String,
  end : String,
) -> Array[RecoveryCheckin] {
  match (parse_date(start), parse_date(end)) {
    (Some(start), Some(end)) =>
      match make_date_range(start, end) {
        Some(range) =>
          protocol.checkins.filter(item => {
            match parse_date(item.date) {
              Some(date) => date_is_in_range(date, range)
              None => false
            }
          })
        None => []
      }
    _ => []
  }
}
