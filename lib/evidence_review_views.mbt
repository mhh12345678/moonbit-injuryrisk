///|
/// Evidence review cards keep every recommendation tied to a signal and an action.
pub(all) struct EvidenceReviewCard {
  id : String
  kind : String
  title : String
  value : Double
  threshold : Double
  severity : RiskLevel
  confidence : Double
  evidence : String
  action : String
  review_required : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct EvidenceReview {
  date : String
  cards : Array[EvidenceReviewCard]
  high_count : Int
  medium_count : Int
  low_count : Int
  average_confidence : Double
  status : String
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct EvidenceReviewComparison {
  left_date : String
  right_date : String
  confidence_change : Double
  high_change : Int
  active_change : Int
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
fn evidence_review_card(signal : RiskSignal) -> EvidenceReviewCard {
  {
    id: signal.id,
    kind: signal_kind_name(signal.kind),
    title: signal.title,
    value: signal.value,
    threshold: signal.threshold,
    severity: signal.severity,
    confidence: signal.confidence,
    evidence: signal.evidence,
    action: signal.action,
    review_required: signal.severity != Low || signal.confidence < 0.7,
  }
}

///|
pub fn build_evidence_review(
  assessment : ComprehensiveAssessment,
) -> EvidenceReview {
  let cards = assessment.signals.signals.map(signal => {
    evidence_review_card(signal)
  })
  let high = cards.filter(card => card.severity == High).length()
  let medium = cards.filter(card => card.severity == Medium).length()
  let low = cards.filter(card => card.severity == Low).length()
  {
    date: assessment.date,
    cards,
    high_count: high,
    medium_count: medium,
    low_count: low,
    average_confidence: mean_load_values(
      assessment.signals.signals.map(signal => signal.confidence),
    ),
    status: if high > 0 {
      "high"
    } else if medium > 0 {
      "medium"
    } else if low > 0 {
      "low"
    } else {
      "empty"
    },
    recommendation: if high > 0 {
      "resolve high-severity evidence before progression"
    } else if medium > 0 {
      "review medium-severity evidence"
    } else if low > 0 {
      "continue monitoring the active signals"
    } else {
      "collect more evidence"
    },
  }
}

///|
pub fn evidence_review_for_date(
  records : Array[DailyRecord],
  date : String,
  policy : RiskPolicy,
) -> EvidenceReview? {
  match assess_comprehensive(records, date, policy) {
    Some(assessment) => Some(build_evidence_review(assessment))
    None => None
  }
}

///|
pub fn evidence_review_cards(
  review : EvidenceReview,
) -> Array[EvidenceReviewCard] {
  review.cards
}

///|
pub fn evidence_review_card_by_id(
  review : EvidenceReview,
  id : String,
) -> EvidenceReviewCard? {
  for card in review.cards {
    if card.id == id {
      return Some(card)
    }
  }
  None
}

///|
pub fn evidence_review_card_by_kind(
  review : EvidenceReview,
  kind : String,
) -> Array[EvidenceReviewCard] {
  review.cards.filter(card => card.kind == kind)
}

///|
pub fn evidence_review_active(
  review : EvidenceReview,
) -> Array[EvidenceReviewCard] {
  review.cards.filter(card => card.review_required)
}

///|
pub fn evidence_review_high(
  review : EvidenceReview,
) -> Array[EvidenceReviewCard] {
  review.cards.filter(card => card.severity == High)
}

///|
pub fn evidence_review_medium(
  review : EvidenceReview,
) -> Array[EvidenceReviewCard] {
  review.cards.filter(card => card.severity == Medium)
}

///|
pub fn evidence_review_low(
  review : EvidenceReview,
) -> Array[EvidenceReviewCard] {
  review.cards.filter(card => card.severity == Low)
}

///|
pub fn evidence_review_card_count(review : EvidenceReview) -> Int {
  review.cards.length()
}

///|
pub fn evidence_review_active_count(review : EvidenceReview) -> Int {
  evidence_review_active(review).length()
}

///|
pub fn evidence_review_high_count(review : EvidenceReview) -> Int {
  review.high_count
}

///|
pub fn evidence_review_medium_count(review : EvidenceReview) -> Int {
  review.medium_count
}

///|
pub fn evidence_review_low_count(review : EvidenceReview) -> Int {
  review.low_count
}

///|
pub fn evidence_review_confidence(review : EvidenceReview) -> Double {
  review.average_confidence
}

///|
pub fn evidence_review_ids(review : EvidenceReview) -> Array[String] {
  review.cards.map(card => card.id)
}

///|
pub fn evidence_review_titles(review : EvidenceReview) -> Array[String] {
  review.cards.map(card => card.title)
}

///|
pub fn evidence_review_values(review : EvidenceReview) -> Array[Double] {
  review.cards.map(card => card.value)
}

///|
pub fn evidence_review_confidences(review : EvidenceReview) -> Array[Double] {
  review.cards.map(card => card.confidence)
}

///|
pub fn evidence_review_actions(review : EvidenceReview) -> Array[String] {
  evidence_review_active(review).map(card => card.action)
}

///|
pub fn evidence_review_actions_unique(review : EvidenceReview) -> Array[String] {
  let values = []
  for action in evidence_review_actions(review) {
    if !values.contains(action) {
      values.push(action)
    }
  }
  values
}

///|
pub fn evidence_review_kinds(review : EvidenceReview) -> Array[String] {
  let values = []
  for card in review.cards {
    if !values.contains(card.kind) {
      values.push(card.kind)
    }
  }
  values
}

///|
pub fn evidence_review_kind_count(
  review : EvidenceReview,
  kind : String,
) -> Int {
  evidence_review_card_by_kind(review, kind).length()
}

///|
pub fn evidence_review_metric(review : EvidenceReview, name : String) -> Double {
  match name {
    "confidence" => review.average_confidence
    "high" => review.high_count.to_double()
    "medium" => review.medium_count.to_double()
    "low" => review.low_count.to_double()
    "active" => evidence_review_active_count(review).to_double()
    _ => 0.0
  }
}

///|
pub fn evidence_review_status(review : EvidenceReview) -> String {
  review.status
}

///|
pub fn evidence_review_requires_review(review : EvidenceReview) -> Bool {
  review.high_count > 0 ||
  review.medium_count > 0 ||
  evidence_review_active_count(review) > 0
}

///|
pub fn evidence_review_valid_card(card : EvidenceReviewCard) -> Bool {
  card.id != "" &&
  card.kind != "" &&
  card.title != "" &&
  card.value >= 0.0 &&
  card.threshold >= 0.0 &&
  card.confidence >= 0.0 &&
  card.confidence <= 1.0 &&
  card.evidence != "" &&
  card.action != ""
}

///|
pub fn evidence_review_valid(review : EvidenceReview) -> Bool {
  review.date != "" &&
  review.cards.all(card => evidence_review_valid_card(card)) &&
  review.high_count >= 0 &&
  review.medium_count >= 0 &&
  review.low_count >= 0 &&
  review.average_confidence >= 0.0 &&
  review.average_confidence <= 1.0
}

///|
pub fn evidence_review_card_text(card : EvidenceReviewCard) -> String {
  card.id +
  " kind=" +
  card.kind +
  " title=" +
  card.title +
  " value=" +
  card.value.to_string() +
  " threshold=" +
  card.threshold.to_string() +
  " severity=" +
  risk_level_name(card.severity) +
  " confidence=" +
  card.confidence.to_string() +
  " review=" +
  card.review_required.to_string() +
  " evidence=" +
  card.evidence +
  " action=" +
  card.action
}

///|
pub fn evidence_review_text(review : EvidenceReview) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "date=" +
    review.date +
    " status=" +
    review.status +
    " cards=" +
    review.cards.length().to_string() +
    " high=" +
    review.high_count.to_string() +
    " medium=" +
    review.medium_count.to_string() +
    " low=" +
    review.low_count.to_string() +
    " confidence=" +
    review.average_confidence.to_string(),
  )
  builder.write_string("\nrecommendation=" + review.recommendation)
  for card in review.cards {
    builder.write_string("\n" + evidence_review_card_text(card))
  }
  builder.to_string()
}

///|
pub fn evidence_review_card_csv_header() -> String {
  "id,kind,title,value,threshold,severity,confidence,evidence,action,review_required"
}

///|
pub fn evidence_review_card_csv(card : EvidenceReviewCard) -> String {
  card.id +
  "," +
  card.kind +
  "," +
  card.title +
  "," +
  card.value.to_string() +
  "," +
  card.threshold.to_string() +
  "," +
  risk_level_name(card.severity) +
  "," +
  card.confidence.to_string() +
  "," +
  card.evidence +
  "," +
  card.action +
  "," +
  card.review_required.to_string()
}

///|
pub fn evidence_review_csv(review : EvidenceReview) -> String {
  let builder = StringBuilder()
  builder.write_string(evidence_review_card_csv_header())
  for card in review.cards {
    builder.write_string("\n" + evidence_review_card_csv(card))
  }
  builder.to_string()
}

///|
pub fn evidence_review_compare(
  left : EvidenceReview,
  right : EvidenceReview,
) -> EvidenceReviewComparison {
  {
    left_date: left.date,
    right_date: right.date,
    confidence_change: right.average_confidence - left.average_confidence,
    high_change: right.high_count - left.high_count,
    active_change: evidence_review_active_count(right) -
    evidence_review_active_count(left),
    conclusion: if right.high_count < left.high_count &&
      evidence_review_active_count(right) <= evidence_review_active_count(left) {
      "evidence burden improved"
    } else if right.high_count > left.high_count ||
      evidence_review_active_count(right) > evidence_review_active_count(left) {
      "evidence burden increased"
    } else {
      "evidence burden is stable"
    },
  }
}

///|
pub fn evidence_review_comparison_text(
  comparison : EvidenceReviewComparison,
) -> String {
  comparison.left_date +
  " -> " +
  comparison.right_date +
  " confidence_change=" +
  comparison.confidence_change.to_string() +
  " high_change=" +
  comparison.high_change.to_string() +
  " active_change=" +
  comparison.active_change.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn evidence_review_checksum(review : EvidenceReview) -> String {
  let mut value = review.cards.length()
  for character in evidence_review_text(review) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn evidence_review_reproducible(
  left : EvidenceReview,
  right : EvidenceReview,
) -> Bool {
  evidence_review_checksum(left) == evidence_review_checksum(right)
}

///|
pub fn evidence_review_recommendation(review : EvidenceReview) -> String {
  review.recommendation
}

///|
pub fn evidence_review_exportable(review : EvidenceReview) -> Bool {
  evidence_review_valid(review)
}

///|
pub fn evidence_review_export_status(review : EvidenceReview) -> String {
  if evidence_review_exportable(review) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn evidence_review_contract(review : EvidenceReview) -> Array[String] {
  [
    review.date,
    review.status,
    review.high_count.to_string(),
    review.medium_count.to_string(),
    evidence_review_active_count(review).to_string(),
    review.average_confidence.to_string(),
    evidence_review_recommendation(review),
    evidence_review_export_status(review),
    evidence_review_checksum(review),
  ]
}
