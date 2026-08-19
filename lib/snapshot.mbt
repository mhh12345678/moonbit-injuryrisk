///|
/// An application-friendly immutable view of one athlete assessment.
pub(all) struct AthleteSnapshot {
  athlete_id : String
  date : String
  risk_level : RiskLevel
  risk_score : Double
  readiness_score : Double
  acwr : Double
  sleep_hours : Double
  fatigue : Double
  pain : Double
  data_quality : Double
  alert_count : Int
  action : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct SnapshotDelta {
  risk_change : Double
  readiness_change : Double
  acwr_change : Double
  sleep_change : Double
  fatigue_change : Double
  pain_change : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
pub fn snapshot_from_assessment(
  athlete_id : String,
  assessment : ComprehensiveAssessment,
) -> AthleteSnapshot {
  {
    athlete_id,
    date: assessment.date,
    risk_level: assessment.risk_level,
    risk_score: assessment.risk_score,
    readiness_score: assessment.readiness_score,
    acwr: assessment.load.acwr,
    sleep_hours: assessment.recovery.average_sleep_hours,
    fatigue: assessment.recovery.average_fatigue,
    pain: assessment.recovery.maximum_pain,
    data_quality: assessment.quality.score,
    alert_count: assessment.signals.signal_count,
    action: assessment.action_plan.focus,
  }
}

///|
pub fn snapshot_delta(
  previous : AthleteSnapshot,
  current : AthleteSnapshot,
) -> SnapshotDelta {
  let status = if current.risk_score < previous.risk_score &&
    current.readiness_score > previous.readiness_score {
    "improving"
  } else if current.risk_score > previous.risk_score ||
    current.readiness_score < previous.readiness_score {
    "worsening"
  } else {
    "stable"
  }
  {
    risk_change: current.risk_score - previous.risk_score,
    readiness_change: current.readiness_score - previous.readiness_score,
    acwr_change: current.acwr - previous.acwr,
    sleep_change: current.sleep_hours - previous.sleep_hours,
    fatigue_change: current.fatigue - previous.fatigue,
    pain_change: current.pain - previous.pain,
    status,
  }
}

///|
pub fn snapshot_text(snapshot : AthleteSnapshot) -> String {
  "athlete=" +
  snapshot.athlete_id +
  " date=" +
  snapshot.date +
  " risk=" +
  risk_level_name(snapshot.risk_level) +
  " score=" +
  snapshot.risk_score.to_string() +
  " readiness=" +
  snapshot.readiness_score.to_string() +
  " acwr=" +
  snapshot.acwr.to_string() +
  " sleep=" +
  snapshot.sleep_hours.to_string() +
  " fatigue=" +
  snapshot.fatigue.to_string() +
  " pain=" +
  snapshot.pain.to_string() +
  " quality=" +
  snapshot.data_quality.to_string()
}

///|
pub fn snapshot_csv(snapshot : AthleteSnapshot) -> String {
  "athlete_id,date,risk_level,risk_score,readiness_score,acwr,sleep_hours,fatigue,pain,data_quality,alert_count\n" +
  snapshot.athlete_id +
  "," +
  snapshot.date +
  "," +
  risk_level_name(snapshot.risk_level) +
  "," +
  snapshot.risk_score.to_string() +
  "," +
  snapshot.readiness_score.to_string() +
  "," +
  snapshot.acwr.to_string() +
  "," +
  snapshot.sleep_hours.to_string() +
  "," +
  snapshot.fatigue.to_string() +
  "," +
  snapshot.pain.to_string() +
  "," +
  snapshot.data_quality.to_string() +
  "," +
  snapshot.alert_count.to_string() +
  "\n"
}

///|
pub fn snapshot_flags(snapshot : AthleteSnapshot) -> Array[String] {
  let flags = []
  if snapshot.risk_level == High {
    flags.push("high-risk")
  }
  if snapshot.readiness_score < 60.0 {
    flags.push("low-readiness")
  }
  if snapshot.acwr > 1.5 {
    flags.push("high-acwr")
  }
  if snapshot.sleep_hours < 7.0 {
    flags.push("low-sleep")
  }
  if snapshot.fatigue > 7.0 {
    flags.push("high-fatigue")
  }
  if snapshot.pain > 4.0 {
    flags.push("pain")
  }
  if snapshot.data_quality < 80.0 {
    flags.push("data-review")
  }
  flags
}
