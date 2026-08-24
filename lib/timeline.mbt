///|
/// A compact point in an assessment timeline.
pub(all) struct TimelinePoint {
  date : String
  risk_level : RiskLevel
  risk_score : Double
  readiness_score : Double
  acute_load : Double
  chronic_load : Double
  acwr : Double
  recovery_score : Double
  quality_score : Double
  signal_count : Int
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RiskTimeline {
  points : Array[TimelinePoint]
  high_risk_days : Int
  medium_risk_days : Int
  improving_days : Int
  worsening_days : Int
  latest : TimelinePoint?
} derive(Debug, Eq, ToJson)

///|
fn timeline_point(assessment : ComprehensiveAssessment) -> TimelinePoint {
  {
    date: assessment.date,
    risk_level: assessment.risk_level,
    risk_score: assessment.risk_score,
    readiness_score: assessment.readiness_score,
    acute_load: assessment.load.acute_load,
    chronic_load: assessment.load.chronic_load,
    acwr: assessment.load.acwr,
    recovery_score: assessment.recovery.recovery_score,
    quality_score: assessment.quality.score,
    signal_count: assessment.signals.signal_count,
  }
}

///|
pub fn build_timeline(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> RiskTimeline {
  let sorted = sort_records_by_date(records)
  let points = []
  for record in sorted {
    match assess_comprehensive(sorted, record.date, policy) {
      Some(assessment) => points.push(timeline_point(assessment))
      None => ()
    }
  }
  let high = points.filter(point => point.risk_level == High).length()
  let medium = points.filter(point => point.risk_level == Medium).length()
  let mut improving = 0
  let mut worsening = 0
  for index in 1..<points.length() {
    if points[index].risk_score < points[index - 1].risk_score {
      improving += 1
    } else if points[index].risk_score > points[index - 1].risk_score {
      worsening += 1
    }
  }
  {
    points,
    high_risk_days: high,
    medium_risk_days: medium,
    improving_days: improving,
    worsening_days: worsening,
    latest: if points.length() == 0 {
      None
    } else {
      Some(points[points.length() - 1])
    },
  }
}

///|
pub fn timeline_risk_scores(timeline : RiskTimeline) -> Array[Double] {
  timeline.points.map(point => point.risk_score)
}

///|
pub fn timeline_readiness_scores(timeline : RiskTimeline) -> Array[Double] {
  timeline.points.map(point => point.readiness_score)
}

///|
pub fn timeline_acwr_values(timeline : RiskTimeline) -> Array[Double] {
  timeline.points.map(point => point.acwr)
}

///|
pub fn timeline_trend(timeline : RiskTimeline) -> TrendSummary {
  summarize_trend(timeline_risk_scores(timeline), 0.1, 2)
}

///|
pub fn highest_risk_point(timeline : RiskTimeline) -> TimelinePoint? {
  if timeline.points.length() == 0 {
    return None
  }
  let mut best = timeline.points[0]
  for point in timeline.points {
    if point.risk_score > best.risk_score {
      best = point
    }
  }
  Some(best)
}

///|
pub fn longest_risk_streak(timeline : RiskTimeline, level : RiskLevel) -> Int {
  let mut longest = 0
  let mut current = 0
  for point in timeline.points {
    if point.risk_level == level {
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
pub fn timeline_points_in_range(
  timeline : RiskTimeline,
  range : DateRange,
) -> Array[TimelinePoint] {
  timeline.points.filter(point => {
    match parse_date(point.date) {
      Some(date) => date_is_in_range(date, range)
      None => false
    }
  })
}

///|
pub fn timeline_delta(timeline : RiskTimeline) -> AssessmentDelta? {
  if timeline.points.length() < 2 {
    None
  } else {
    let first = timeline.points[0]
    let last = timeline.points[timeline.points.length() - 1]
    Some({
      risk_score_change: last.risk_score - first.risk_score,
      readiness_score_change: last.readiness_score - first.readiness_score,
      load_change_percent: percentage_change(first.acute_load, last.acute_load),
      recovery_change: last.recovery_score - first.recovery_score,
      direction: classify_trend(timeline_risk_scores(timeline), 0.1, 2),
    })
  }
}

///|
pub fn timeline_text(timeline : RiskTimeline) -> String {
  let builder = StringBuilder()
  builder.write_string("points=")
  builder.write_string(timeline.points.length().to_string())
  builder.write_string(" high=")
  builder.write_string(timeline.high_risk_days.to_string())
  builder.write_string(" medium=")
  builder.write_string(timeline.medium_risk_days.to_string())
  builder.write_string(" improving=")
  builder.write_string(timeline.improving_days.to_string())
  builder.write_string(" worsening=")
  builder.write_string(timeline.worsening_days.to_string())
  builder.to_string()
}

///|
pub fn timeline_alert_dates(
  timeline : RiskTimeline,
  minimum : RiskLevel,
) -> Array[String] {
  timeline.points
  .filter(point => point.risk_level.max(minimum) == point.risk_level)
  .map(point => point.date)
}
