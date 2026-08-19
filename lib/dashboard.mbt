///|
/// A single-screen summary suitable for a CLI or web dashboard.
pub(all) struct DashboardSnapshot {
  date : String
  status : String
  risk_level : RiskLevel
  risk_score : Double
  readiness_score : Double
  acwr : Double
  load_trend : LoadTrend
  recovery_band : RecoveryBand
  pain_level : Double
  quality_score : Double
  active_alerts : Int
  primary_action : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct DashboardRange {
  start_date : String
  end_date : String
  high_risk_days : Int
  average_risk_score : Double
  average_readiness : Double
  average_acwr : Double
  average_quality : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
pub fn dashboard_status(assessment : ComprehensiveAssessment) -> String {
  if assessment.quality.blocking_issue_count > 0 {
    "data-review"
  } else if assessment.risk_level == High {
    "urgent"
  } else if assessment.risk_level == Medium || assessment.readiness_score < 60.0 {
    "caution"
  } else {
    "on-track"
  }
}

///|
pub fn dashboard_snapshot(
  assessment : ComprehensiveAssessment,
) -> DashboardSnapshot {
  {
    date: assessment.date,
    status: dashboard_status(assessment),
    risk_level: assessment.risk_level,
    risk_score: assessment.risk_score,
    readiness_score: assessment.readiness_score,
    acwr: assessment.load.acwr,
    load_trend: load_trend(
      [assessment.load.average_load, assessment.load.acute_load],
      0.1,
    ),
    recovery_band: recovery_band(assessment.recovery.recovery_score),
    pain_level: assessment.recovery.maximum_pain,
    quality_score: assessment.quality.score,
    active_alerts: assessment.signals.signal_count,
    primary_action: assessment.action_plan.focus,
  }
}

///|
pub fn dashboard_range(timeline : RiskTimeline) -> DashboardRange {
  let first = if timeline.points.length() == 0 {
    ""
  } else {
    timeline.points[0].date
  }
  let last = if timeline.points.length() == 0 {
    ""
  } else {
    timeline.points[timeline.points.length() - 1].date
  }
  let status = if timeline.high_risk_days > 0 {
    "needs-review"
  } else if timeline.medium_risk_days > 0 {
    "monitor"
  } else {
    "stable"
  }
  {
    start_date: first,
    end_date: last,
    high_risk_days: timeline.high_risk_days,
    average_risk_score: mean_load_values(timeline_risk_scores(timeline)),
    average_readiness: mean_load_values(timeline_readiness_scores(timeline)),
    average_acwr: mean_load_values(timeline_acwr_values(timeline)),
    average_quality: mean_load_values(
      timeline.points.map(point => point.quality_score),
    ),
    status,
  }
}

///|
pub fn dashboard_snapshot_text(snapshot : DashboardSnapshot) -> String {
  "date=" +
  snapshot.date +
  " status=" +
  snapshot.status +
  " risk=" +
  risk_level_name(snapshot.risk_level) +
  " score=" +
  snapshot.risk_score.to_string() +
  " readiness=" +
  snapshot.readiness_score.to_string() +
  " acwr=" +
  snapshot.acwr.to_string() +
  " recovery=" +
  recovery_band_name(snapshot.recovery_band) +
  " alerts=" +
  snapshot.active_alerts.to_string()
}

///|
pub fn dashboard_range_text(range : DashboardRange) -> String {
  "range=" +
  range.start_date +
  ".." +
  range.end_date +
  " status=" +
  range.status +
  " high_days=" +
  range.high_risk_days.to_string() +
  " risk=" +
  range.average_risk_score.to_string() +
  " readiness=" +
  range.average_readiness.to_string() +
  " acwr=" +
  range.average_acwr.to_string()
}

///|
pub fn dashboard_alerts(assessment : ComprehensiveAssessment) -> Array[String] {
  assessment.signals.signals.map(signal => signal.title + ": " + signal.action)
}

///|
pub fn dashboard_csv(snapshot : DashboardSnapshot) -> String {
  "date,status,risk_level,risk_score,readiness_score,acwr,recovery_band,pain_level,quality_score,active_alerts\n" +
  snapshot.date +
  "," +
  snapshot.status +
  "," +
  risk_level_name(snapshot.risk_level) +
  "," +
  snapshot.risk_score.to_string() +
  "," +
  snapshot.readiness_score.to_string() +
  "," +
  snapshot.acwr.to_string() +
  "," +
  recovery_band_name(snapshot.recovery_band) +
  "," +
  snapshot.pain_level.to_string() +
  "," +
  snapshot.quality_score.to_string() +
  "," +
  snapshot.active_alerts.to_string() +
  "\n"
}
