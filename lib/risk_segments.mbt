///|
/// Segment a timeline into stable operating periods for review and comparison.
pub(all) struct RiskSegment {
  id : Int
  start_date : String
  end_date : String
  point_count : Int
  average_risk : Double
  average_readiness : Double
  average_load : Double
  average_recovery : Double
  dominant_level : RiskLevel
  direction : TrendDirection
  action_required : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct SegmentSummary {
  segments : Array[RiskSegment]
  highest_risk_segment : Int?
  longest_segment : Int?
  action_segment_count : Int
  improving_segment_count : Int
  worsening_segment_count : Int
  status : String
} derive(Debug, Eq, ToJson)

///|
fn segment_level(points : Array[TimelinePoint]) -> RiskLevel {
  if points.filter(point => point.risk_level == High).length().to_double() >=
    points.length().to_double() * 0.5 {
    High
  } else if points.filter(point => point.risk_level == Medium).length() > 0 {
    Medium
  } else {
    Low
  }
}

///|
fn make_risk_segment(id : Int, points : Array[TimelinePoint]) -> RiskSegment {
  let risks = points.map(point => point.risk_score)
  let readiness = points.map(point => point.readiness_score)
  let loads = points.map(point => point.acute_load)
  let recovery = points.map(point => point.recovery_score)
  {
    id,
    start_date: points[0].date,
    end_date: points[points.length() - 1].date,
    point_count: points.length(),
    average_risk: mean_load_values(risks),
    average_readiness: mean_load_values(readiness),
    average_load: mean_load_values(loads),
    average_recovery: mean_load_values(recovery),
    dominant_level: segment_level(points),
    direction: classify_trend(risks, 0.1, 2),
    action_required: points.any(point => {
      point.risk_level != Low || point.readiness_score < 60.0
    }),
  }
}

///|
fn point_change(
  left : TimelinePoint,
  right : TimelinePoint,
  risk_delta : Double,
  readiness_delta : Double,
) -> Bool {
  (right.risk_score - left.risk_score).abs() >= risk_delta ||
  (right.readiness_score - left.readiness_score).abs() >= readiness_delta
}

///|
pub fn segment_timeline(
  timeline : RiskTimeline,
  risk_delta : Double,
  readiness_delta : Double,
) -> Array[RiskSegment] {
  if timeline.points.length() == 0 {
    return []
  }
  let segments : Array[RiskSegment] = []
  let current : Array[TimelinePoint] = []
  current.push(timeline.points[0])
  let mut segment_id = 0
  for index in 1..<timeline.points.length() {
    let previous = timeline.points[index - 1]
    let point = timeline.points[index]
    if point_change(previous, point, risk_delta, readiness_delta) {
      segments.push(make_risk_segment(segment_id, current))
      segment_id += 1
      current.clear()
    }
    current.push(point)
  }
  if current.length() > 0 {
    segments.push(make_risk_segment(segment_id, current))
  }
  segments
}

///|
pub fn default_timeline_segments(timeline : RiskTimeline) -> Array[RiskSegment] {
  segment_timeline(timeline, 15.0, 15.0)
}

///|
pub fn summarize_segments(segments : Array[RiskSegment]) -> SegmentSummary {
  let mut highest : Int? = None
  let mut highest_value = 0.0
  let mut longest : Int? = None
  let mut longest_count = 0
  for segment in segments {
    if segment.average_risk > highest_value {
      highest_value = segment.average_risk
      highest = Some(segment.id)
    }
    if segment.point_count > longest_count {
      longest_count = segment.point_count
      longest = Some(segment.id)
    }
  }
  {
    segments,
    highest_risk_segment: highest,
    longest_segment: longest,
    action_segment_count: segments
    .filter(segment => segment.action_required)
    .length(),
    improving_segment_count: segments
    .filter(segment => segment.direction == Improving)
    .length(),
    worsening_segment_count: segments
    .filter(segment => segment.direction == Worsening)
    .length(),
    status: if segments.any(segment => segment.dominant_level == High) {
      "high_attention"
    } else if segments.any(segment => segment.action_required) {
      "review"
    } else {
      "stable"
    },
  }
}

///|
pub fn segment_for_id(summary : SegmentSummary, id : Int) -> RiskSegment? {
  for segment in summary.segments {
    if segment.id == id {
      return Some(segment)
    }
  }
  None
}

///|
pub fn segment_action_segments(summary : SegmentSummary) -> Array[RiskSegment] {
  summary.segments.filter(segment => segment.action_required)
}

///|
pub fn segment_high_risk_segments(
  summary : SegmentSummary,
) -> Array[RiskSegment] {
  summary.segments.filter(segment => segment.dominant_level == High)
}

///|
pub fn segment_average_risk(summary : SegmentSummary) -> Double {
  mean_load_values(summary.segments.map(segment => segment.average_risk))
}

///|
pub fn segment_average_readiness(summary : SegmentSummary) -> Double {
  mean_load_values(summary.segments.map(segment => segment.average_readiness))
}

///|
pub fn segment_total_days(summary : SegmentSummary) -> Int {
  summary.segments.fold(init=0, (total, segment) => total + segment.point_count)
}

///|
pub fn segment_risk_change(left : RiskSegment, right : RiskSegment) -> Double {
  right.average_risk - left.average_risk
}

///|
pub fn segment_readiness_change(
  left : RiskSegment,
  right : RiskSegment,
) -> Double {
  right.average_readiness - left.average_readiness
}

///|
pub fn segment_transition_is_concerning(
  left : RiskSegment,
  right : RiskSegment,
) -> Bool {
  segment_risk_change(left, right) >= 10.0 ||
  segment_readiness_change(left, right) <= -10.0
}

///|
pub fn segment_transition_count(summary : SegmentSummary) -> Int {
  (summary.segments.length() - 1).max(0)
}

///|
pub fn segment_latest(summary : SegmentSummary) -> RiskSegment? {
  if summary.segments.length() == 0 {
    None
  } else {
    Some(summary.segments[summary.segments.length() - 1])
  }
}

///|
pub fn segment_first(summary : SegmentSummary) -> RiskSegment? {
  if summary.segments.length() == 0 {
    None
  } else {
    Some(summary.segments[0])
  }
}

///|
pub fn segment_recommendation(summary : SegmentSummary) -> String {
  if summary.status == "high_attention" {
    "review the highest-risk segment and apply an intervention"
  } else if summary.status == "review" {
    "compare action segments with completed interventions"
  } else {
    "continue monitoring segment transitions"
  }
}

///|
pub fn segment_text(segment : RiskSegment) -> String {
  "segment=" +
  segment.id.to_string() +
  " dates=" +
  segment.start_date +
  ".." +
  segment.end_date +
  " points=" +
  segment.point_count.to_string() +
  " risk=" +
  segment.average_risk.to_string() +
  " readiness=" +
  segment.average_readiness.to_string() +
  " level=" +
  risk_level_name(segment.dominant_level) +
  " action=" +
  segment.action_required.to_string()
}

///|
pub fn segment_summary_text(summary : SegmentSummary) -> String {
  "status=" +
  summary.status +
  " segments=" +
  summary.segments.length().to_string() +
  " action_segments=" +
  summary.action_segment_count.to_string() +
  " improving=" +
  summary.improving_segment_count.to_string() +
  " worsening=" +
  summary.worsening_segment_count.to_string() +
  " recommendation=" +
  segment_recommendation(summary)
}

///|
pub fn segment_csv_header() -> String {
  "id,start_date,end_date,point_count,average_risk,average_readiness,average_load,average_recovery,dominant_level,direction,action_required"
}

///|
pub fn segment_csv(segment : RiskSegment) -> String {
  segment.id.to_string() +
  "," +
  segment.start_date +
  "," +
  segment.end_date +
  "," +
  segment.point_count.to_string() +
  "," +
  segment.average_risk.to_string() +
  "," +
  segment.average_readiness.to_string() +
  "," +
  segment.average_load.to_string() +
  "," +
  segment.average_recovery.to_string() +
  "," +
  risk_level_name(segment.dominant_level) +
  "," +
  trend_direction_name(segment.direction) +
  "," +
  segment.action_required.to_string()
}

///|
pub fn segment_summary_csv(summary : SegmentSummary) -> String {
  let builder = StringBuilder()
  builder.write_string(segment_csv_header())
  for segment in summary.segments {
    builder.write_string("\n")
    builder.write_string(segment_csv(segment))
  }
  builder.to_string()
}

///|
pub fn segment_valid(segment : RiskSegment) -> Bool {
  segment.id >= 0 &&
  segment.start_date != "" &&
  segment.end_date != "" &&
  segment.point_count > 0 &&
  segment.average_risk >= 0.0 &&
  segment.average_risk <= 100.0 &&
  segment.average_readiness >= 0.0 &&
  segment.average_readiness <= 100.0
}

///|
pub fn segment_summary_valid(summary : SegmentSummary) -> Bool {
  summary.action_segment_count >= 0 &&
  summary.improving_segment_count >= 0 &&
  summary.worsening_segment_count >= 0 &&
  summary.segments.all(segment => segment_valid(segment))
}
