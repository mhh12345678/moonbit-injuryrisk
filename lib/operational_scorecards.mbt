///|
/// Operational scorecards summarize a set of acceptance packets for review cadence.
pub(all) struct OperationalScorecard {
  packet_count : Int
  ready_count : Int
  review_count : Int
  blocked_count : Int
  average_score : Double
  average_risk : Double
  average_readiness : Double
  average_quality : Double
  average_coverage : Double
  total_records : Int
  total_open_items : Int
  status : String
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct OperationalScorecardDelta {
  left_packets : Int
  right_packets : Int
  packet_change : Int
  ready_change : Int
  blocked_change : Int
  score_change : Double
  risk_change : Double
  quality_change : Double
  open_item_change : Int
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
fn scorecard_status(
  packets : Array[AcceptancePacket],
  ready : Int,
  review : Int,
  blocked : Int,
) -> String {
  if packets.length() == 0 {
    "empty"
  } else if blocked > 0 {
    "blocked"
  } else if review > 0 {
    "review"
  } else if ready == packets.length() {
    "ready"
  } else {
    "mixed"
  }
}

///|
fn scorecard_recommendation(
  status : String,
  blocked : Int,
  review : Int,
  open_items : Int,
) -> String {
  if status == "empty" {
    "collect the first operational packet"
  } else if blocked > 0 {
    "resolve blocked packets before release"
  } else if review > 0 {
    "complete packet-level review actions"
  } else if open_items > 0 {
    "clear remaining follow-up items"
  } else {
    "continue the current review cadence"
  }
}

///|
pub fn build_operational_scorecard(
  packets : Array[AcceptancePacket],
) -> OperationalScorecard {
  let ready = packets
    .filter(packet => acceptance_packet_accepted(packet))
    .length()
  let review = packets
    .filter(packet => acceptance_packet_needs_review(packet))
    .length()
  let blocked = packets
    .filter(packet => acceptance_packet_blocked(packet))
    .length()
  let open_items = packets.fold(init=0, (total, packet) => {
    total + acceptance_packet_follow_up_count(packet)
  })
  let status = scorecard_status(packets, ready, review, blocked)
  {
    packet_count: packets.length(),
    ready_count: ready,
    review_count: review,
    blocked_count: blocked,
    average_score: mean_load_values(
      packets.map(packet => acceptance_packet_score(packet)),
    ),
    average_risk: mean_load_values(
      packets.map(packet => acceptance_packet_risk(packet)),
    ),
    average_readiness: mean_load_values(
      packets.map(packet => acceptance_packet_readiness(packet)),
    ),
    average_quality: mean_load_values(
      packets.map(packet => acceptance_packet_quality(packet)),
    ),
    average_coverage: mean_load_values(
      packets.map(packet => acceptance_packet_coverage(packet)),
    ),
    total_records: packets.fold(init=0, (total, packet) => {
      total + acceptance_packet_record_count(packet)
    }),
    total_open_items: open_items,
    status,
    recommendation: scorecard_recommendation(
      status, blocked, review, open_items,
    ),
  }
}

///|
pub fn empty_operational_scorecard() -> OperationalScorecard {
  build_operational_scorecard([])
}

///|
pub fn operational_scorecard_for_records(
  records : Array[DailyRecord],
  dates : Array[String],
) -> OperationalScorecard {
  build_operational_scorecard(acceptance_packet_batch(records, dates))
}

///|
pub fn operational_scorecard_packets(
  scorecard : OperationalScorecard,
  packets : Array[AcceptancePacket],
) -> OperationalScorecard {
  if packets.length() == scorecard.packet_count {
    scorecard
  } else {
    build_operational_scorecard(packets)
  }
}

///|
pub fn operational_scorecard_count(scorecard : OperationalScorecard) -> Int {
  scorecard.packet_count
}

///|
pub fn operational_scorecard_ready_count(
  scorecard : OperationalScorecard,
) -> Int {
  scorecard.ready_count
}

///|
pub fn operational_scorecard_review_count(
  scorecard : OperationalScorecard,
) -> Int {
  scorecard.review_count
}

///|
pub fn operational_scorecard_blocked_count(
  scorecard : OperationalScorecard,
) -> Int {
  scorecard.blocked_count
}

///|
pub fn operational_scorecard_average_score(
  scorecard : OperationalScorecard,
) -> Double {
  scorecard.average_score
}

///|
pub fn operational_scorecard_average_risk(
  scorecard : OperationalScorecard,
) -> Double {
  scorecard.average_risk
}

///|
pub fn operational_scorecard_average_readiness(
  scorecard : OperationalScorecard,
) -> Double {
  scorecard.average_readiness
}

///|
pub fn operational_scorecard_average_quality(
  scorecard : OperationalScorecard,
) -> Double {
  scorecard.average_quality
}

///|
pub fn operational_scorecard_average_coverage(
  scorecard : OperationalScorecard,
) -> Double {
  scorecard.average_coverage
}

///|
pub fn operational_scorecard_total_records(
  scorecard : OperationalScorecard,
) -> Int {
  scorecard.total_records
}

///|
pub fn operational_scorecard_total_open_items(
  scorecard : OperationalScorecard,
) -> Int {
  scorecard.total_open_items
}

///|
pub fn operational_scorecard_status(scorecard : OperationalScorecard) -> String {
  scorecard.status
}

///|
pub fn operational_scorecard_recommendation(
  scorecard : OperationalScorecard,
) -> String {
  scorecard.recommendation
}

///|
pub fn operational_scorecard_ready_percent(
  scorecard : OperationalScorecard,
) -> Double {
  if scorecard.packet_count == 0 {
    0.0
  } else {
    scorecard.ready_count.to_double() /
    scorecard.packet_count.to_double() *
    100.0
  }
}

///|
pub fn operational_scorecard_review_percent(
  scorecard : OperationalScorecard,
) -> Double {
  if scorecard.packet_count == 0 {
    0.0
  } else {
    scorecard.review_count.to_double() /
    scorecard.packet_count.to_double() *
    100.0
  }
}

///|
pub fn operational_scorecard_blocked_percent(
  scorecard : OperationalScorecard,
) -> Double {
  if scorecard.packet_count == 0 {
    0.0
  } else {
    scorecard.blocked_count.to_double() /
    scorecard.packet_count.to_double() *
    100.0
  }
}

///|
pub fn operational_scorecard_average_open_items(
  scorecard : OperationalScorecard,
) -> Double {
  if scorecard.packet_count == 0 {
    0.0
  } else {
    scorecard.total_open_items.to_double() / scorecard.packet_count.to_double()
  }
}

///|
pub fn operational_scorecard_risk_band(
  scorecard : OperationalScorecard,
) -> String {
  if scorecard.average_risk >= 75.0 {
    "high"
  } else if scorecard.average_risk >= 50.0 {
    "medium"
  } else {
    "low"
  }
}

///|
pub fn operational_scorecard_quality_band(
  scorecard : OperationalScorecard,
) -> String {
  if scorecard.average_quality >= 90.0 {
    "excellent"
  } else if scorecard.average_quality >= 80.0 {
    "good"
  } else if scorecard.average_quality >= 60.0 {
    "watch"
  } else {
    "poor"
  }
}

///|
pub fn operational_scorecard_coverage_band(
  scorecard : OperationalScorecard,
) -> String {
  if scorecard.average_coverage >= 90.0 {
    "complete"
  } else if scorecard.average_coverage >= 80.0 {
    "adequate"
  } else {
    "limited"
  }
}

///|
pub fn operational_scorecard_passes(
  scorecard : OperationalScorecard,
  score_floor : Double,
  quality_floor : Double,
) -> Bool {
  scorecard.average_score >= score_floor &&
  scorecard.average_quality >= quality_floor &&
  scorecard.blocked_count == 0
}

///|
pub fn operational_scorecard_requires_review(
  scorecard : OperationalScorecard,
) -> Bool {
  scorecard.status == "review" ||
  scorecard.status == "blocked" ||
  scorecard.total_open_items > 0
}

///|
pub fn operational_scorecard_release_ready(
  scorecard : OperationalScorecard,
) -> Bool {
  scorecard.status == "ready" &&
  scorecard.total_open_items == 0 &&
  scorecard.average_quality >= 80.0 &&
  scorecard.average_coverage >= 80.0
}

///|
pub fn operational_scorecard_metric(
  scorecard : OperationalScorecard,
  name : String,
) -> Double {
  match name {
    "score" => scorecard.average_score
    "risk" => scorecard.average_risk
    "readiness" => scorecard.average_readiness
    "quality" => scorecard.average_quality
    "coverage" => scorecard.average_coverage
    "ready" => scorecard.ready_count.to_double()
    "review" => scorecard.review_count.to_double()
    "blocked" => scorecard.blocked_count.to_double()
    "records" => scorecard.total_records.to_double()
    "open_items" => scorecard.total_open_items.to_double()
    "ready_percent" => operational_scorecard_ready_percent(scorecard)
    "review_percent" => operational_scorecard_review_percent(scorecard)
    "blocked_percent" => operational_scorecard_blocked_percent(scorecard)
    _ => 0.0
  }
}

///|
pub fn operational_scorecard_metric_names() -> Array[String] {
  [
    "score", "risk", "readiness", "quality", "coverage", "ready", "review", "blocked",
    "records", "open_items", "ready_percent", "review_percent", "blocked_percent",
  ]
}

///|
pub fn operational_scorecard_metric_values(
  scorecard : OperationalScorecard,
) -> Array[Double] {
  operational_scorecard_metric_names().map(name => {
    operational_scorecard_metric(scorecard, name)
  })
}

///|
pub fn operational_scorecard_projection(
  scorecard : OperationalScorecard,
  names : Array[String],
) -> Array[Double] {
  names.map(name => operational_scorecard_metric(scorecard, name))
}

///|
pub fn operational_scorecard_projection_average(
  scorecard : OperationalScorecard,
  names : Array[String],
) -> Double {
  mean_load_values(operational_scorecard_projection(scorecard, names))
}

///|
pub fn operational_scorecard_projection_minimum(
  scorecard : OperationalScorecard,
  names : Array[String],
) -> Double {
  minimum_load_values(operational_scorecard_projection(scorecard, names))
}

///|
pub fn operational_scorecard_projection_maximum(
  scorecard : OperationalScorecard,
  names : Array[String],
) -> Double {
  maximum_load_values(operational_scorecard_projection(scorecard, names))
}

///|
pub fn operational_scorecard_projection_deviation(
  scorecard : OperationalScorecard,
  names : Array[String],
) -> Double {
  standard_deviation_values(operational_scorecard_projection(scorecard, names))
}

///|
pub fn operational_scorecard_valid(scorecard : OperationalScorecard) -> Bool {
  scorecard.packet_count >= 0 &&
  scorecard.ready_count >= 0 &&
  scorecard.review_count >= 0 &&
  scorecard.blocked_count >= 0 &&
  scorecard.ready_count + scorecard.review_count + scorecard.blocked_count <=
  scorecard.packet_count &&
  scorecard.average_score >= 0.0 &&
  scorecard.average_score <= 100.0 &&
  scorecard.average_risk >= 0.0 &&
  scorecard.average_risk <= 100.0 &&
  scorecard.average_readiness >= 0.0 &&
  scorecard.average_readiness <= 100.0 &&
  scorecard.average_quality >= 0.0 &&
  scorecard.average_quality <= 100.0 &&
  scorecard.average_coverage >= 0.0 &&
  scorecard.average_coverage <= 100.0 &&
  scorecard.total_records >= 0 &&
  scorecard.total_open_items >= 0 &&
  scorecard.status != "" &&
  scorecard.recommendation != ""
}

///|
pub fn operational_scorecard_contract(
  scorecard : OperationalScorecard,
) -> Array[String] {
  [
    scorecard.packet_count.to_string(),
    scorecard.status,
    scorecard.ready_count.to_string(),
    scorecard.review_count.to_string(),
    scorecard.blocked_count.to_string(),
    scorecard.average_score.to_string(),
    scorecard.average_risk.to_string(),
    scorecard.average_quality.to_string(),
    scorecard.average_coverage.to_string(),
    scorecard.total_open_items.to_string(),
    operational_scorecard_release_ready(scorecard).to_string(),
  ]
}

///|
pub fn operational_scorecard_status_code(
  scorecard : OperationalScorecard,
) -> Int {
  if scorecard.status == "ready" {
    200
  } else if scorecard.status == "review" {
    206
  } else if scorecard.status == "blocked" {
    422
  } else if scorecard.status == "empty" {
    204
  } else {
    207
  }
}

///|
pub fn operational_scorecard_status_label(
  scorecard : OperationalScorecard,
) -> String {
  scorecard.status +
  "(" +
  operational_scorecard_status_code(scorecard).to_string() +
  ")"
}

///|
pub fn operational_scorecard_summary(
  scorecard : OperationalScorecard,
) -> String {
  "status=" +
  scorecard.status +
  " packets=" +
  scorecard.packet_count.to_string() +
  " ready=" +
  scorecard.ready_count.to_string() +
  " review=" +
  scorecard.review_count.to_string() +
  " blocked=" +
  scorecard.blocked_count.to_string() +
  " score=" +
  scorecard.average_score.to_string() +
  " risk=" +
  scorecard.average_risk.to_string() +
  " quality=" +
  scorecard.average_quality.to_string() +
  " coverage=" +
  scorecard.average_coverage.to_string() +
  " open_items=" +
  scorecard.total_open_items.to_string() +
  " recommendation=" +
  scorecard.recommendation
}

///|
pub fn operational_scorecard_text(scorecard : OperationalScorecard) -> String {
  let builder = StringBuilder::new()
  builder.write_string(operational_scorecard_summary(scorecard))
  builder.write_string(
    "\nbands=risk:" +
    operational_scorecard_risk_band(scorecard) +
    " quality:" +
    operational_scorecard_quality_band(scorecard) +
    " coverage:" +
    operational_scorecard_coverage_band(scorecard),
  )
  builder.write_string(
    "\npercent=ready:" +
    operational_scorecard_ready_percent(scorecard).to_string() +
    " review:" +
    operational_scorecard_review_percent(scorecard).to_string() +
    " blocked:" +
    operational_scorecard_blocked_percent(scorecard).to_string(),
  )
  builder.to_string()
}

///|
pub fn operational_scorecard_csv_header() -> String {
  "status,packets,ready,review,blocked,ready_percent,review_percent,blocked_percent,average_score,average_risk,average_readiness,average_quality,average_coverage,total_records,total_open_items,recommendation"
}

///|
pub fn operational_scorecard_csv(scorecard : OperationalScorecard) -> String {
  operational_scorecard_csv_header() +
  "\n" +
  scorecard.status +
  "," +
  scorecard.packet_count.to_string() +
  "," +
  scorecard.ready_count.to_string() +
  "," +
  scorecard.review_count.to_string() +
  "," +
  scorecard.blocked_count.to_string() +
  "," +
  operational_scorecard_ready_percent(scorecard).to_string() +
  "," +
  operational_scorecard_review_percent(scorecard).to_string() +
  "," +
  operational_scorecard_blocked_percent(scorecard).to_string() +
  "," +
  scorecard.average_score.to_string() +
  "," +
  scorecard.average_risk.to_string() +
  "," +
  scorecard.average_readiness.to_string() +
  "," +
  scorecard.average_quality.to_string() +
  "," +
  scorecard.average_coverage.to_string() +
  "," +
  scorecard.total_records.to_string() +
  "," +
  scorecard.total_open_items.to_string() +
  "," +
  scorecard.recommendation
}

///|
pub fn operational_scorecard_band_summary(
  scorecard : OperationalScorecard,
) -> Array[String] {
  [
    operational_scorecard_status_label(scorecard),
    operational_scorecard_risk_band(scorecard),
    operational_scorecard_quality_band(scorecard),
    operational_scorecard_coverage_band(scorecard),
    operational_scorecard_release_ready(scorecard).to_string(),
  ]
}

///|
pub fn operational_scorecard_band_summary_csv(
  scorecard : OperationalScorecard,
) -> String {
  ["status", "risk_band", "quality_band", "coverage_band", "release_ready"].join(
    ",",
  ) +
  "\n" +
  operational_scorecard_band_summary(scorecard).join(",")
}

///|
pub fn operational_scorecard_checksum(
  scorecard : OperationalScorecard,
) -> String {
  let mut value = scorecard.packet_count + scorecard.total_records
  for character in operational_scorecard_summary(scorecard) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn operational_scorecard_reproducible(
  left : OperationalScorecard,
  right : OperationalScorecard,
) -> Bool {
  operational_scorecard_checksum(left) == operational_scorecard_checksum(right)
}

///|
pub fn operational_scorecard_delta(
  left : OperationalScorecard,
  right : OperationalScorecard,
) -> OperationalScorecardDelta {
  {
    left_packets: left.packet_count,
    right_packets: right.packet_count,
    packet_change: right.packet_count - left.packet_count,
    ready_change: right.ready_count - left.ready_count,
    blocked_change: right.blocked_count - left.blocked_count,
    score_change: right.average_score - left.average_score,
    risk_change: right.average_risk - left.average_risk,
    quality_change: right.average_quality - left.average_quality,
    open_item_change: right.total_open_items - left.total_open_items,
    conclusion: if right.average_score > left.average_score &&
      right.average_risk <= left.average_risk &&
      right.total_open_items <= left.total_open_items {
      "operational health improved"
    } else if right.average_risk > left.average_risk ||
      right.total_open_items > left.total_open_items {
      "operational burden increased"
    } else {
      "operational health is mixed"
    },
  }
}

///|
pub fn operational_scorecard_delta_text(
  delta : OperationalScorecardDelta,
) -> String {
  "packets=" +
  delta.left_packets.to_string() +
  " -> " +
  delta.right_packets.to_string() +
  " ready_change=" +
  delta.ready_change.to_string() +
  " blocked_change=" +
  delta.blocked_change.to_string() +
  " score_change=" +
  delta.score_change.to_string() +
  " risk_change=" +
  delta.risk_change.to_string() +
  " quality_change=" +
  delta.quality_change.to_string() +
  " open_change=" +
  delta.open_item_change.to_string() +
  " conclusion=" +
  delta.conclusion
}

///|
pub fn operational_scorecard_delta_csv(
  delta : OperationalScorecardDelta,
) -> String {
  "left_packets,right_packets,packet_change,ready_change,blocked_change,score_change,risk_change,quality_change,open_item_change,conclusion\n" +
  delta.left_packets.to_string() +
  "," +
  delta.right_packets.to_string() +
  "," +
  delta.packet_change.to_string() +
  "," +
  delta.ready_change.to_string() +
  "," +
  delta.blocked_change.to_string() +
  "," +
  delta.score_change.to_string() +
  "," +
  delta.risk_change.to_string() +
  "," +
  delta.quality_change.to_string() +
  "," +
  delta.open_item_change.to_string() +
  "," +
  delta.conclusion
}

///|
pub fn operational_scorecard_improved(
  delta : OperationalScorecardDelta,
) -> Bool {
  delta.score_change > 0.0 &&
  delta.risk_change <= 0.0 &&
  delta.open_item_change <= 0
}

///|
pub fn operational_scorecard_worsened(
  delta : OperationalScorecardDelta,
) -> Bool {
  delta.risk_change > 0.0 ||
  delta.open_item_change > 0 ||
  delta.blocked_change > 0
}

///|
pub fn operational_scorecard_stable(delta : OperationalScorecardDelta) -> Bool {
  !operational_scorecard_improved(delta) &&
  !operational_scorecard_worsened(delta)
}

///|
pub fn operational_scorecard_delta_valid(
  delta : OperationalScorecardDelta,
) -> Bool {
  delta.left_packets >= 0 &&
  delta.right_packets >= 0 &&
  delta.left_packets + delta.packet_change == delta.right_packets &&
  delta.conclusion != ""
}

///|
pub fn operational_scorecard_packet_statuses(
  packets : Array[AcceptancePacket],
) -> Array[String] {
  packets.map(packet => acceptance_packet_status_value(packet))
}

///|
pub fn operational_scorecard_packet_scores(
  packets : Array[AcceptancePacket],
) -> Array[Double] {
  packets.map(packet => acceptance_packet_score(packet))
}

///|
pub fn operational_scorecard_packet_risks(
  packets : Array[AcceptancePacket],
) -> Array[Double] {
  packets.map(packet => acceptance_packet_risk(packet))
}

///|
pub fn operational_scorecard_packet_quality(
  packets : Array[AcceptancePacket],
) -> Array[Double] {
  packets.map(packet => acceptance_packet_quality(packet))
}

///|
pub fn operational_scorecard_packet_open_items(
  packets : Array[AcceptancePacket],
) -> Array[Int] {
  packets.map(packet => acceptance_packet_follow_up_count(packet))
}

///|
pub fn operational_scorecard_filter_ready(
  packets : Array[AcceptancePacket],
) -> Array[AcceptancePacket] {
  packets.filter(packet => acceptance_packet_accepted(packet))
}

///|
pub fn operational_scorecard_filter_review(
  packets : Array[AcceptancePacket],
) -> Array[AcceptancePacket] {
  packets.filter(packet => acceptance_packet_needs_review(packet))
}

///|
pub fn operational_scorecard_filter_blocked(
  packets : Array[AcceptancePacket],
) -> Array[AcceptancePacket] {
  packets.filter(packet => acceptance_packet_blocked(packet))
}

///|
pub fn operational_scorecard_filter_exportable(
  packets : Array[AcceptancePacket],
) -> Array[AcceptancePacket] {
  packets.filter(packet => acceptance_packet_exportable(packet))
}

///|
pub fn operational_scorecard_filter_release_ready(
  packets : Array[AcceptancePacket],
) -> Array[AcceptancePacket] {
  packets.filter(packet => acceptance_packet_release_ready(packet))
}

///|
pub fn operational_scorecard_valid_packets(
  packets : Array[AcceptancePacket],
) -> Array[AcceptancePacket] {
  packets.filter(packet => acceptance_packet_valid(packet))
}

///|
pub fn operational_scorecard_invalid_packets(
  packets : Array[AcceptancePacket],
) -> Array[AcceptancePacket] {
  packets.filter(packet => !acceptance_packet_valid(packet))
}

///|
pub fn operational_scorecard_status_counts(
  packets : Array[AcceptancePacket],
) -> Array[Int] {
  [
    operational_scorecard_filter_ready(packets).length(),
    operational_scorecard_filter_review(packets).length(),
    operational_scorecard_filter_blocked(packets).length(),
  ]
}

///|
pub fn operational_scorecard_risk_average(
  packets : Array[AcceptancePacket],
) -> Double {
  mean_load_values(operational_scorecard_packet_risks(packets))
}

///|
pub fn operational_scorecard_quality_average(
  packets : Array[AcceptancePacket],
) -> Double {
  mean_load_values(operational_scorecard_packet_quality(packets))
}

///|
pub fn operational_scorecard_score_average(
  packets : Array[AcceptancePacket],
) -> Double {
  mean_load_values(operational_scorecard_packet_scores(packets))
}

///|
pub fn operational_scorecard_open_item_total(
  packets : Array[AcceptancePacket],
) -> Int {
  operational_scorecard_packet_open_items(packets).fold(init=0, (total, value) => {
    total + value
  })
}

///|
pub fn operational_scorecard_summary_header() -> Array[String] {
  [
    "status", "packets", "ready", "review", "blocked", "average_score", "average_risk",
    "average_quality", "average_coverage", "total_records", "total_open_items", "recommendation",
  ]
}

///|
pub fn operational_scorecard_summary_row(
  scorecard : OperationalScorecard,
) -> Array[String] {
  [
    scorecard.status,
    scorecard.packet_count.to_string(),
    scorecard.ready_count.to_string(),
    scorecard.review_count.to_string(),
    scorecard.blocked_count.to_string(),
    scorecard.average_score.to_string(),
    scorecard.average_risk.to_string(),
    scorecard.average_quality.to_string(),
    scorecard.average_coverage.to_string(),
    scorecard.total_records.to_string(),
    scorecard.total_open_items.to_string(),
    scorecard.recommendation,
  ]
}

///|
pub fn operational_scorecard_summary_csv(
  scorecard : OperationalScorecard,
) -> String {
  operational_scorecard_summary_header().join(",") +
  "\n" +
  operational_scorecard_summary_row(scorecard).join(",")
}

///|
pub fn operational_scorecard_report(scorecard : OperationalScorecard) -> String {
  operational_scorecard_text(scorecard) +
  "\nchecksum=" +
  operational_scorecard_checksum(scorecard) +
  "\nvalid=" +
  operational_scorecard_valid(scorecard).to_string() +
  "\nrelease_ready=" +
  operational_scorecard_release_ready(scorecard).to_string()
}

///|
pub fn operational_scorecard_report_csv(
  scorecard : OperationalScorecard,
) -> String {
  operational_scorecard_csv(scorecard) +
  "\n\n" +
  operational_scorecard_band_summary_csv(scorecard)
}

///|
pub fn operational_scorecard_empty_contract() -> Array[String] {
  operational_scorecard_contract(empty_operational_scorecard())
}

///|
pub fn operational_scorecard_empty_valid() -> Bool {
  operational_scorecard_valid(empty_operational_scorecard())
}

///|
pub fn operational_scorecard_empty_status() -> String {
  operational_scorecard_status(empty_operational_scorecard())
}

///|
pub fn operational_scorecard_batch_summary(
  packets : Array[AcceptancePacket],
) -> String {
  operational_scorecard_summary(build_operational_scorecard(packets))
}

///|
pub fn operational_scorecard_batch_csv(
  packets : Array[AcceptancePacket],
) -> String {
  operational_scorecard_csv(build_operational_scorecard(packets))
}

///|
pub fn operational_scorecard_batch_contract(
  packets : Array[AcceptancePacket],
) -> Array[String] {
  operational_scorecard_contract(build_operational_scorecard(packets))
}

///|
pub fn operational_scorecard_batch_checksum(
  packets : Array[AcceptancePacket],
) -> String {
  operational_scorecard_checksum(build_operational_scorecard(packets))
}

///|
pub fn operational_scorecard_batch_releasable(
  packets : Array[AcceptancePacket],
) -> Bool {
  operational_scorecard_release_ready(build_operational_scorecard(packets))
}

///|
pub(all) struct OperationalScorecardRow {
  index : Int
  run_id : String
  status : String
  score : Double
  risk : Double
  readiness : Double
  quality : Double
  coverage : Double
  open_items : Int
  release_ready : Bool
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct OperationalScorecardPage {
  offset : Int
  limit : Int
  total : Int
  rows : Array[OperationalScorecardRow]
  has_previous : Bool
  has_next : Bool
} derive(Debug, Eq, ToJson)

///|
fn operational_scorecard_row(
  index : Int,
  packet : AcceptancePacket,
) -> OperationalScorecardRow {
  {
    index,
    run_id: packet.run.config.run_id,
    status: packet.status,
    score: acceptance_packet_score(packet),
    risk: acceptance_packet_risk(packet),
    readiness: acceptance_packet_readiness(packet),
    quality: acceptance_packet_quality(packet),
    coverage: acceptance_packet_coverage(packet),
    open_items: acceptance_packet_follow_up_count(packet),
    release_ready: acceptance_packet_release_ready(packet),
    recommendation: packet.recommendation,
  }
}

///|
pub fn operational_scorecard_rows(
  packets : Array[AcceptancePacket],
) -> Array[OperationalScorecardRow] {
  let rows = []
  for index, packet in packets {
    rows.push(operational_scorecard_row(index, packet))
  }
  rows
}

///|
pub fn operational_scorecard_row_by_id(
  rows : Array[OperationalScorecardRow],
  run_id : String,
) -> OperationalScorecardRow? {
  for row in rows {
    if row.run_id == run_id {
      return Some(row)
    }
  }
  None
}

///|
pub fn operational_scorecard_row_by_index(
  rows : Array[OperationalScorecardRow],
  index : Int,
) -> OperationalScorecardRow? {
  for row in rows {
    if row.index == index {
      return Some(row)
    }
  }
  None
}

///|
pub fn operational_scorecard_ready_rows(
  rows : Array[OperationalScorecardRow],
) -> Array[OperationalScorecardRow] {
  rows.filter(row => row.release_ready)
}

///|
pub fn operational_scorecard_review_rows(
  rows : Array[OperationalScorecardRow],
) -> Array[OperationalScorecardRow] {
  rows.filter(row => row.status == "review")
}

///|
pub fn operational_scorecard_blocked_rows(
  rows : Array[OperationalScorecardRow],
) -> Array[OperationalScorecardRow] {
  rows.filter(row => row.status == "blocked")
}

///|
pub fn operational_scorecard_high_risk_rows(
  rows : Array[OperationalScorecardRow],
  threshold : Double,
) -> Array[OperationalScorecardRow] {
  rows.filter(row => row.risk >= threshold)
}

///|
pub fn operational_scorecard_low_quality_rows(
  rows : Array[OperationalScorecardRow],
  threshold : Double,
) -> Array[OperationalScorecardRow] {
  rows.filter(row => row.quality < threshold)
}

///|
pub fn operational_scorecard_open_item_rows(
  rows : Array[OperationalScorecardRow],
) -> Array[OperationalScorecardRow] {
  rows.filter(row => row.open_items > 0)
}

///|
pub fn operational_scorecard_row_count(
  rows : Array[OperationalScorecardRow],
) -> Int {
  rows.length()
}

///|
pub fn operational_scorecard_row_ids(
  rows : Array[OperationalScorecardRow],
) -> Array[String] {
  rows.map(row => row.run_id)
}

///|
pub fn operational_scorecard_row_statuses(
  rows : Array[OperationalScorecardRow],
) -> Array[String] {
  rows.map(row => row.status)
}

///|
pub fn operational_scorecard_row_scores(
  rows : Array[OperationalScorecardRow],
) -> Array[Double] {
  rows.map(row => row.score)
}

///|
pub fn operational_scorecard_row_risks(
  rows : Array[OperationalScorecardRow],
) -> Array[Double] {
  rows.map(row => row.risk)
}

///|
pub fn operational_scorecard_row_quality(
  rows : Array[OperationalScorecardRow],
) -> Array[Double] {
  rows.map(row => row.quality)
}

///|
pub fn operational_scorecard_row_open_items(
  rows : Array[OperationalScorecardRow],
) -> Array[Int] {
  rows.map(row => row.open_items)
}

///|
pub fn operational_scorecard_row_average_score(
  rows : Array[OperationalScorecardRow],
) -> Double {
  mean_load_values(operational_scorecard_row_scores(rows))
}

///|
pub fn operational_scorecard_row_average_risk(
  rows : Array[OperationalScorecardRow],
) -> Double {
  mean_load_values(operational_scorecard_row_risks(rows))
}

///|
pub fn operational_scorecard_row_average_quality(
  rows : Array[OperationalScorecardRow],
) -> Double {
  mean_load_values(operational_scorecard_row_quality(rows))
}

///|
pub fn operational_scorecard_row_total_open_items(
  rows : Array[OperationalScorecardRow],
) -> Int {
  operational_scorecard_row_open_items(rows).fold(init=0, (total, value) => {
    total + value
  })
}

///|
pub fn operational_scorecard_row_valid(row : OperationalScorecardRow) -> Bool {
  row.index >= 0 &&
  row.run_id != "" &&
  row.status != "" &&
  row.score >= 0.0 &&
  row.score <= 100.0 &&
  row.risk >= 0.0 &&
  row.risk <= 100.0 &&
  row.readiness >= 0.0 &&
  row.readiness <= 100.0 &&
  row.quality >= 0.0 &&
  row.quality <= 100.0 &&
  row.coverage >= 0.0 &&
  row.coverage <= 100.0 &&
  row.open_items >= 0 &&
  row.recommendation != ""
}

///|
pub fn operational_scorecard_rows_valid(
  rows : Array[OperationalScorecardRow],
) -> Bool {
  rows.all(row => operational_scorecard_row_valid(row))
}

///|
pub fn operational_scorecard_row_text(row : OperationalScorecardRow) -> String {
  "index=" +
  row.index.to_string() +
  " run=" +
  row.run_id +
  " status=" +
  row.status +
  " score=" +
  row.score.to_string() +
  " risk=" +
  row.risk.to_string() +
  " readiness=" +
  row.readiness.to_string() +
  " quality=" +
  row.quality.to_string() +
  " coverage=" +
  row.coverage.to_string() +
  " open_items=" +
  row.open_items.to_string() +
  " release_ready=" +
  row.release_ready.to_string() +
  " recommendation=" +
  row.recommendation
}

///|
pub fn operational_scorecard_rows_text(
  rows : Array[OperationalScorecardRow],
) -> String {
  let builder = StringBuilder::new()
  for row in rows {
    builder.write_string("\n" + operational_scorecard_row_text(row))
  }
  builder.to_string()
}

///|
pub fn operational_scorecard_row_csv_header() -> String {
  "index,run_id,status,score,risk,readiness,quality,coverage,open_items,release_ready,recommendation"
}

///|
pub fn operational_scorecard_row_csv(row : OperationalScorecardRow) -> String {
  row.index.to_string() +
  "," +
  row.run_id +
  "," +
  row.status +
  "," +
  row.score.to_string() +
  "," +
  row.risk.to_string() +
  "," +
  row.readiness.to_string() +
  "," +
  row.quality.to_string() +
  "," +
  row.coverage.to_string() +
  "," +
  row.open_items.to_string() +
  "," +
  row.release_ready.to_string() +
  "," +
  row.recommendation
}

///|
pub fn operational_scorecard_rows_csv(
  rows : Array[OperationalScorecardRow],
) -> String {
  let builder = StringBuilder::new()
  builder.write_string(operational_scorecard_row_csv_header())
  for row in rows {
    builder.write_string("\n" + operational_scorecard_row_csv(row))
  }
  builder.to_string()
}

///|
pub fn operational_scorecard_row_metric(
  row : OperationalScorecardRow,
  name : String,
) -> Double {
  match name {
    "score" => row.score
    "risk" => row.risk
    "readiness" => row.readiness
    "quality" => row.quality
    "coverage" => row.coverage
    "open_items" => row.open_items.to_double()
    "release_ready" => if row.release_ready { 1.0 } else { 0.0 }
    _ => 0.0
  }
}

///|
pub fn operational_scorecard_row_projection(
  rows : Array[OperationalScorecardRow],
  name : String,
) -> Array[Double] {
  rows.map(row => operational_scorecard_row_metric(row, name))
}

///|
pub fn operational_scorecard_row_projection_average(
  rows : Array[OperationalScorecardRow],
  name : String,
) -> Double {
  mean_load_values(operational_scorecard_row_projection(rows, name))
}

///|
pub fn operational_scorecard_row_projection_minimum(
  rows : Array[OperationalScorecardRow],
  name : String,
) -> Double {
  minimum_load_values(operational_scorecard_row_projection(rows, name))
}

///|
pub fn operational_scorecard_row_projection_maximum(
  rows : Array[OperationalScorecardRow],
  name : String,
) -> Double {
  maximum_load_values(operational_scorecard_row_projection(rows, name))
}

///|
pub fn operational_scorecard_row_projection_deviation(
  rows : Array[OperationalScorecardRow],
  name : String,
) -> Double {
  standard_deviation_values(operational_scorecard_row_projection(rows, name))
}

///|
pub fn operational_scorecard_row_checksum(
  row : OperationalScorecardRow,
) -> String {
  let mut value = row.index + row.open_items
  for character in operational_scorecard_row_text(row) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn operational_scorecard_rows_checksum(
  rows : Array[OperationalScorecardRow],
) -> String {
  let mut value = rows.length()
  for row in rows {
    for character in operational_scorecard_row_checksum(row) {
      value = (value * 31 + character.to_int()) % 2147483647
    }
  }
  value.to_string()
}

///|
pub fn operational_scorecard_rows_reproducible(
  left : Array[OperationalScorecardRow],
  right : Array[OperationalScorecardRow],
) -> Bool {
  operational_scorecard_rows_checksum(left) ==
  operational_scorecard_rows_checksum(right)
}

///|
pub fn operational_scorecard_page(
  rows : Array[OperationalScorecardRow],
  offset : Int,
  limit : Int,
) -> OperationalScorecardPage {
  let safe_offset = offset.max(0).min(rows.length())
  let safe_limit = limit.max(0)
  let page_rows = []
  let end = (safe_offset + safe_limit).min(rows.length())
  for index in safe_offset..<end {
    page_rows.push(rows[index])
  }
  {
    offset: safe_offset,
    limit: safe_limit,
    total: rows.length(),
    rows: page_rows,
    has_previous: safe_offset > 0,
    has_next: end < rows.length(),
  }
}

///|
pub fn operational_scorecard_page_for_packets(
  packets : Array[AcceptancePacket],
  offset : Int,
  limit : Int,
) -> OperationalScorecardPage {
  operational_scorecard_page(operational_scorecard_rows(packets), offset, limit)
}

///|
pub fn operational_scorecard_page_offset(
  page : OperationalScorecardPage,
) -> Int {
  page.offset
}

///|
pub fn operational_scorecard_page_limit(page : OperationalScorecardPage) -> Int {
  page.limit
}

///|
pub fn operational_scorecard_page_total(page : OperationalScorecardPage) -> Int {
  page.total
}

///|
pub fn operational_scorecard_page_rows(
  page : OperationalScorecardPage,
) -> Array[OperationalScorecardRow] {
  page.rows
}

///|
pub fn operational_scorecard_page_has_previous(
  page : OperationalScorecardPage,
) -> Bool {
  page.has_previous
}

///|
pub fn operational_scorecard_page_has_next(
  page : OperationalScorecardPage,
) -> Bool {
  page.has_next
}

///|
pub fn operational_scorecard_page_valid(
  page : OperationalScorecardPage,
) -> Bool {
  page.offset >= 0 &&
  page.limit >= 0 &&
  page.total >= 0 &&
  page.offset <= page.total &&
  page.rows.length() <= page.limit &&
  page.offset + page.rows.length() <= page.total &&
  operational_scorecard_rows_valid(page.rows)
}

///|
pub fn operational_scorecard_page_text(
  page : OperationalScorecardPage,
) -> String {
  "offset=" +
  page.offset.to_string() +
  " limit=" +
  page.limit.to_string() +
  " total=" +
  page.total.to_string() +
  " previous=" +
  page.has_previous.to_string() +
  " next=" +
  page.has_next.to_string() +
  operational_scorecard_rows_text(page.rows)
}

///|
pub fn operational_scorecard_page_csv(
  page : OperationalScorecardPage,
) -> String {
  "offset,limit,total,has_previous,has_next\n" +
  page.offset.to_string() +
  "," +
  page.limit.to_string() +
  "," +
  page.total.to_string() +
  "," +
  page.has_previous.to_string() +
  "," +
  page.has_next.to_string() +
  "\n\n" +
  operational_scorecard_rows_csv(page.rows)
}

///|
pub fn operational_scorecard_page_checksum(
  page : OperationalScorecardPage,
) -> String {
  let mut value = page.offset + page.limit + page.total
  for character in operational_scorecard_page_text(page) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn operational_scorecard_page_reproducible(
  left : OperationalScorecardPage,
  right : OperationalScorecardPage,
) -> Bool {
  operational_scorecard_page_checksum(left) ==
  operational_scorecard_page_checksum(right)
}

///|
pub fn operational_scorecard_page_contract(
  page : OperationalScorecardPage,
) -> Array[String] {
  [
    page.offset.to_string(),
    page.limit.to_string(),
    page.total.to_string(),
    page.rows.length().to_string(),
    page.has_previous.to_string(),
    page.has_next.to_string(),
    operational_scorecard_page_valid(page).to_string(),
    operational_scorecard_page_checksum(page),
  ]
}

///|
pub fn operational_scorecard_page_count(
  rows : Array[OperationalScorecardRow],
  limit : Int,
) -> Int {
  if limit <= 0 {
    0
  } else {
    (rows.length() + limit - 1) / limit
  }
}

///|
pub fn operational_scorecard_page_at(
  rows : Array[OperationalScorecardRow],
  page_index : Int,
  limit : Int,
) -> OperationalScorecardPage {
  operational_scorecard_page(rows, page_index.max(0) * limit.max(0), limit)
}

///|
pub fn operational_scorecard_pages_for_packets(
  packets : Array[AcceptancePacket],
  limit : Int,
) -> Int {
  operational_scorecard_page_count(operational_scorecard_rows(packets), limit)
}

///|
pub fn operational_scorecard_page_is_empty(
  page : OperationalScorecardPage,
) -> Bool {
  page.rows.length() == 0
}

///|
pub fn operational_scorecard_page_first_id(
  page : OperationalScorecardPage,
) -> String {
  if page.rows.length() == 0 {
    ""
  } else {
    page.rows[0].run_id
  }
}

///|
pub fn operational_scorecard_page_last_id(
  page : OperationalScorecardPage,
) -> String {
  if page.rows.length() == 0 {
    ""
  } else {
    page.rows[page.rows.length() - 1].run_id
  }
}

///|
pub fn operational_scorecard_page_open_items(
  page : OperationalScorecardPage,
) -> Int {
  operational_scorecard_row_total_open_items(page.rows)
}

///|
pub fn operational_scorecard_page_average_score(
  page : OperationalScorecardPage,
) -> Double {
  operational_scorecard_row_average_score(page.rows)
}

///|
pub fn operational_scorecard_page_average_risk(
  page : OperationalScorecardPage,
) -> Double {
  operational_scorecard_row_average_risk(page.rows)
}

///|
pub fn operational_scorecard_page_average_quality(
  page : OperationalScorecardPage,
) -> Double {
  operational_scorecard_row_average_quality(page.rows)
}

///|
pub fn operational_scorecard_page_status_counts(
  page : OperationalScorecardPage,
) -> Array[Int] {
  [
    operational_scorecard_ready_rows(page.rows).length(),
    operational_scorecard_review_rows(page.rows).length(),
    operational_scorecard_blocked_rows(page.rows).length(),
  ]
}

///|
pub fn operational_scorecard_page_release_ready(
  page : OperationalScorecardPage,
) -> Bool {
  page.rows.length() > 0 &&
  operational_scorecard_ready_rows(page.rows).length() == page.rows.length() &&
  operational_scorecard_page_open_items(page) == 0
}

///|
pub fn operational_scorecard_page_recommendation(
  page : OperationalScorecardPage,
) -> String {
  if operational_scorecard_page_is_empty(page) {
    "no rows in this page"
  } else if operational_scorecard_page_release_ready(page) {
    "page is ready for release"
  } else {
    "review page-level rows"
  }
}

///|
pub fn operational_scorecard_page_summary(
  page : OperationalScorecardPage,
) -> String {
  operational_scorecard_page_text(page) +
  "\nopen_items=" +
  operational_scorecard_page_open_items(page).to_string() +
  "\nscore=" +
  operational_scorecard_page_average_score(page).to_string() +
  "\nrisk=" +
  operational_scorecard_page_average_risk(page).to_string() +
  "\nquality=" +
  operational_scorecard_page_average_quality(page).to_string() +
  "\nrecommendation=" +
  operational_scorecard_page_recommendation(page)
}

///|
pub fn operational_scorecard_page_report(
  page : OperationalScorecardPage,
) -> String {
  operational_scorecard_page_summary(page) +
  "\nchecksum=" +
  operational_scorecard_page_checksum(page) +
  "\nvalid=" +
  operational_scorecard_page_valid(page).to_string()
}

///|
pub fn operational_scorecard_page_index(page : OperationalScorecardPage) -> Int {
  if page.limit <= 0 {
    0
  } else {
    page.offset / page.limit
  }
}

///|
pub fn operational_scorecard_next_page(
  rows : Array[OperationalScorecardRow],
  page : OperationalScorecardPage,
) -> OperationalScorecardPage {
  if page.has_next {
    operational_scorecard_page(rows, page.offset + page.limit, page.limit)
  } else {
    page
  }
}

///|
pub fn operational_scorecard_previous_page(
  rows : Array[OperationalScorecardRow],
  page : OperationalScorecardPage,
) -> OperationalScorecardPage {
  if page.has_previous {
    operational_scorecard_page(
      rows,
      (page.offset - page.limit).max(0),
      page.limit,
    )
  } else {
    page
  }
}

///|
pub fn operational_scorecard_page_ids(
  page : OperationalScorecardPage,
) -> Array[String] {
  operational_scorecard_row_ids(page.rows)
}

///|
pub fn operational_scorecard_page_high_risk(
  page : OperationalScorecardPage,
  threshold : Double,
) -> Array[OperationalScorecardRow] {
  operational_scorecard_high_risk_rows(page.rows, threshold)
}

///|
pub fn operational_scorecard_page_low_quality(
  page : OperationalScorecardPage,
  threshold : Double,
) -> Array[OperationalScorecardRow] {
  operational_scorecard_low_quality_rows(page.rows, threshold)
}

///|
pub fn operational_scorecard_page_open_rows(
  page : OperationalScorecardPage,
) -> Array[OperationalScorecardRow] {
  operational_scorecard_open_item_rows(page.rows)
}

///|
pub fn operational_scorecard_rows_by_status(
  rows : Array[OperationalScorecardRow],
  status : String,
) -> Array[OperationalScorecardRow] {
  rows.filter(row => row.status == status)
}

///|
pub fn operational_scorecard_rows_by_release(
  rows : Array[OperationalScorecardRow],
  release_ready : Bool,
) -> Array[OperationalScorecardRow] {
  rows.filter(row => row.release_ready == release_ready)
}

///|
pub fn operational_scorecard_rows_with_recommendation(
  rows : Array[OperationalScorecardRow],
  recommendation : String,
) -> Array[OperationalScorecardRow] {
  rows.filter(row => row.recommendation == recommendation)
}

///|
pub fn operational_scorecard_rows_with_open_items(
  rows : Array[OperationalScorecardRow],
  minimum : Int,
) -> Array[OperationalScorecardRow] {
  rows.filter(row => row.open_items >= minimum)
}

///|
pub fn operational_scorecard_rows_in_risk_range(
  rows : Array[OperationalScorecardRow],
  minimum : Double,
  maximum : Double,
) -> Array[OperationalScorecardRow] {
  rows.filter(row => row.risk >= minimum && row.risk <= maximum)
}

///|
pub fn operational_scorecard_rows_in_quality_range(
  rows : Array[OperationalScorecardRow],
  minimum : Double,
  maximum : Double,
) -> Array[OperationalScorecardRow] {
  rows.filter(row => row.quality >= minimum && row.quality <= maximum)
}

///|
pub fn operational_scorecard_status_page(
  rows : Array[OperationalScorecardRow],
  status : String,
  offset : Int,
  limit : Int,
) -> OperationalScorecardPage {
  operational_scorecard_page(
    operational_scorecard_rows_by_status(rows, status),
    offset,
    limit,
  )
}

///|
pub fn operational_scorecard_risk_page(
  rows : Array[OperationalScorecardRow],
  minimum : Double,
  maximum : Double,
  offset : Int,
  limit : Int,
) -> OperationalScorecardPage {
  operational_scorecard_page(
    operational_scorecard_rows_in_risk_range(rows, minimum, maximum),
    offset,
    limit,
  )
}

///|
pub fn operational_scorecard_quality_page(
  rows : Array[OperationalScorecardRow],
  minimum : Double,
  maximum : Double,
  offset : Int,
  limit : Int,
) -> OperationalScorecardPage {
  operational_scorecard_page(
    operational_scorecard_rows_in_quality_range(rows, minimum, maximum),
    offset,
    limit,
  )
}

///|
pub fn operational_scorecard_page_contract_csv(
  page : OperationalScorecardPage,
) -> String {
  [
    "offset", "limit", "total", "rows", "has_previous", "has_next", "valid", "checksum",
  ].join(",") +
  "\n" +
  operational_scorecard_page_contract(page).join(",")
}

///|
pub fn operational_scorecard_page_row_checksum(
  page : OperationalScorecardPage,
) -> String {
  operational_scorecard_rows_checksum(page.rows)
}

///|
pub fn operational_scorecard_page_status_summary(
  page : OperationalScorecardPage,
) -> Array[String] {
  let counts = operational_scorecard_page_status_counts(page)
  [counts[0].to_string(), counts[1].to_string(), counts[2].to_string()]
}

///|
pub fn operational_scorecard_page_status_summary_csv(
  page : OperationalScorecardPage,
) -> String {
  "ready,review,blocked\n" +
  operational_scorecard_page_status_summary(page).join(",")
}

///|
pub fn operational_scorecard_page_risk_band(
  page : OperationalScorecardPage,
) -> String {
  let average = operational_scorecard_page_average_risk(page)
  if average >= 75.0 {
    "high"
  } else if average >= 50.0 {
    "medium"
  } else {
    "low"
  }
}

///|
pub fn operational_scorecard_page_quality_band(
  page : OperationalScorecardPage,
) -> String {
  let average = operational_scorecard_page_average_quality(page)
  if average >= 90.0 {
    "excellent"
  } else if average >= 80.0 {
    "good"
  } else if average >= 60.0 {
    "watch"
  } else {
    "poor"
  }
}

///|
pub fn operational_scorecard_page_bands(
  page : OperationalScorecardPage,
) -> Array[String] {
  [
    operational_scorecard_page_risk_band(page),
    operational_scorecard_page_quality_band(page),
    operational_scorecard_page_release_ready(page).to_string(),
  ]
}

///|
pub fn operational_scorecard_page_bands_csv(
  page : OperationalScorecardPage,
) -> String {
  "risk_band,quality_band,release_ready\n" +
  operational_scorecard_page_bands(page).join(",")
}

///|
pub fn operational_scorecard_page_recommendation_code(
  page : OperationalScorecardPage,
) -> Int {
  if operational_scorecard_page_is_empty(page) {
    0
  } else if operational_scorecard_page_release_ready(page) {
    1
  } else {
    2
  }
}

///|
pub fn operational_scorecard_page_navigation(
  page : OperationalScorecardPage,
) -> Array[String] {
  [
    operational_scorecard_page_index(page).to_string(),
    page.has_previous.to_string(),
    page.has_next.to_string(),
    operational_scorecard_page_recommendation_code(page).to_string(),
  ]
}

///|
pub fn operational_scorecard_page_navigation_csv(
  page : OperationalScorecardPage,
) -> String {
  "page_index,has_previous,has_next,recommendation_code\n" +
  operational_scorecard_page_navigation(page).join(",")
}

///|
pub fn operational_scorecard_page_ready_ratio(
  page : OperationalScorecardPage,
) -> Double {
  if page.rows.length() == 0 {
    0.0
  } else {
    operational_scorecard_ready_rows(page.rows).length().to_double() /
    page.rows.length().to_double() *
    100.0
  }
}

///|
pub fn operational_scorecard_page_open_ratio(
  page : OperationalScorecardPage,
) -> Double {
  if page.rows.length() == 0 {
    0.0
  } else {
    operational_scorecard_open_item_rows(page.rows).length().to_double() /
    page.rows.length().to_double() *
    100.0
  }
}

///|
pub fn operational_scorecard_page_ratios(
  page : OperationalScorecardPage,
) -> Array[Double] {
  [
    operational_scorecard_page_ready_ratio(page),
    operational_scorecard_page_open_ratio(page),
  ]
}

///|
pub fn operational_scorecard_page_ratios_csv(
  page : OperationalScorecardPage,
) -> String {
  "ready_ratio,open_ratio\n" +
  operational_scorecard_page_ratios(page)
  .map(value => value.to_string())
  .join(",")
}

///|
pub fn operational_scorecard_page_records(
  page : OperationalScorecardPage,
) -> Int {
  page.rows.length()
}

///|
pub fn operational_scorecard_page_complete(
  page : OperationalScorecardPage,
) -> Bool {
  operational_scorecard_page_valid(page) &&
  !operational_scorecard_page_is_empty(page)
}

///|
pub fn operational_scorecard_page_action_required(
  page : OperationalScorecardPage,
) -> Bool {
  operational_scorecard_page_open_items(page) > 0 ||
  operational_scorecard_page_high_risk(page, 75.0).length() > 0
}

///|
pub fn operational_scorecard_page_action_label(
  page : OperationalScorecardPage,
) -> String {
  if operational_scorecard_page_is_empty(page) {
    "empty"
  } else if operational_scorecard_page_action_required(page) {
    "review"
  } else {
    "continue"
  }
}

///|
pub fn operational_scorecard_page_action_summary(
  page : OperationalScorecardPage,
) -> Array[String] {
  [
    operational_scorecard_page_action_label(page),
    operational_scorecard_page_open_items(page).to_string(),
    operational_scorecard_page_high_risk(page, 75.0).length().to_string(),
  ]
}

///|
pub fn operational_scorecard_page_action_summary_csv(
  page : OperationalScorecardPage,
) -> String {
  "action,open_items,high_risk\n" +
  operational_scorecard_page_action_summary(page).join(",")
}

///|
pub fn operational_scorecard_page_exportable(
  page : OperationalScorecardPage,
) -> Bool {
  operational_scorecard_page_valid(page) &&
  operational_scorecard_page_records(page) > 0
}

///|
pub fn operational_scorecard_page_export_status(
  page : OperationalScorecardPage,
) -> String {
  if operational_scorecard_page_exportable(page) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn operational_scorecard_page_export_contract(
  page : OperationalScorecardPage,
) -> Array[String] {
  [
    operational_scorecard_page_export_status(page),
    operational_scorecard_page_records(page).to_string(),
    operational_scorecard_page_checksum(page),
  ]
}

///|
pub fn operational_scorecard_page_export_contract_csv(
  page : OperationalScorecardPage,
) -> String {
  "status,records,checksum\n" +
  operational_scorecard_page_export_contract(page).join(",")
}

///|
pub fn operational_scorecard_page_footer(
  page : OperationalScorecardPage,
) -> String {
  "page=" +
  operational_scorecard_page_index(page).to_string() +
  " records=" +
  operational_scorecard_page_records(page).to_string() +
  " status=" +
  operational_scorecard_page_action_label(page) +
  " export=" +
  operational_scorecard_page_export_status(page)
}

///|
pub fn operational_scorecard_page_report_with_footer(
  page : OperationalScorecardPage,
) -> String {
  operational_scorecard_page_report(page) +
  "\n" +
  operational_scorecard_page_footer(page)
}

///|
pub fn operational_scorecard_page_status(
  page : OperationalScorecardPage,
) -> String {
  if operational_scorecard_page_is_empty(page) {
    "empty"
  } else if operational_scorecard_page_action_required(page) {
    "review"
  } else {
    "ready"
  }
}

///|
pub fn operational_scorecard_page_status_code(
  page : OperationalScorecardPage,
) -> Int {
  if operational_scorecard_page_status(page) == "ready" {
    200
  } else if operational_scorecard_page_status(page) == "review" {
    206
  } else {
    204
  }
}

///|
pub fn operational_scorecard_page_status_label(
  page : OperationalScorecardPage,
) -> String {
  operational_scorecard_page_status(page) +
  "(" +
  operational_scorecard_page_status_code(page).to_string() +
  ")"
}

///|
pub fn operational_scorecard_page_release_label(
  page : OperationalScorecardPage,
) -> String {
  if operational_scorecard_page_release_ready(page) {
    "release"
  } else {
    "review"
  }
}

///|
pub fn operational_scorecard_page_labels(
  page : OperationalScorecardPage,
) -> Array[String] {
  [
    operational_scorecard_page_status_label(page),
    operational_scorecard_page_release_label(page),
    operational_scorecard_page_risk_band(page),
    operational_scorecard_page_quality_band(page),
  ]
}

///|
pub fn operational_scorecard_page_labels_csv(
  page : OperationalScorecardPage,
) -> String {
  "status,release,risk_band,quality_band\n" +
  operational_scorecard_page_labels(page).join(",")
}

///|
pub fn operational_scorecard_page_ready(
  page : OperationalScorecardPage,
) -> Bool {
  operational_scorecard_page_status(page) == "ready" &&
  operational_scorecard_page_exportable(page)
}

///|
pub fn operational_scorecard_page_reviewable(
  page : OperationalScorecardPage,
) -> Bool {
  operational_scorecard_page_status(page) == "review"
}

///|
pub fn operational_scorecard_page_blocked(
  page : OperationalScorecardPage,
) -> Bool {
  operational_scorecard_page_status(page) == "empty" ||
  !operational_scorecard_page_valid(page)
}

///|
pub fn operational_scorecard_page_outcome(
  page : OperationalScorecardPage,
) -> String {
  if operational_scorecard_page_ready(page) {
    "ready"
  } else if operational_scorecard_page_reviewable(page) {
    "review"
  } else {
    "blocked"
  }
}

///|
pub fn operational_scorecard_page_outcome_code(
  page : OperationalScorecardPage,
) -> Int {
  if operational_scorecard_page_outcome(page) == "ready" {
    1
  } else if operational_scorecard_page_outcome(page) == "review" {
    2
  } else {
    0
  }
}

///|
pub fn operational_scorecard_page_outcome_text(
  page : OperationalScorecardPage,
) -> String {
  operational_scorecard_page_outcome(page) +
  "(" +
  operational_scorecard_page_outcome_code(page).to_string() +
  ")"
}
