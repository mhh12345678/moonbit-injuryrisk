///|
/// Human review records that preserve the context around automated decisions.
pub(all) enum ManualReviewOutcome {
  ReviewAccepted
  ReviewModified
  ReviewRejected
  ReviewDeferred
  ReviewEscalated
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ManualReview {
  id : String
  date : String
  reviewer : String
  outcome : ManualReviewOutcome
  original_decision : String
  final_decision : String
  reason : String
  evidence_ids : Array[String]
  follow_up_date : String
  closed : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ReviewRegister {
  reviews : Array[ManualReview]
  open_count : Int
  closed_count : Int
  escalation_count : Int
  agreement_percent : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
pub fn manual_review_outcome_name(outcome : ManualReviewOutcome) -> String {
  match outcome {
    ReviewAccepted => "accepted"
    ReviewModified => "modified"
    ReviewRejected => "rejected"
    ReviewDeferred => "deferred"
    ReviewEscalated => "escalated"
  }
}

///|
pub fn manual_review(
  id : String,
  date : String,
  reviewer : String,
  outcome : ManualReviewOutcome,
  original : String,
  final_decision : String,
  reason : String,
  evidence_ids : Array[String],
  follow_up_date : String,
  closed : Bool,
) -> ManualReview {
  {
    id,
    date,
    reviewer,
    outcome,
    original_decision: original,
    final_decision,
    reason,
    evidence_ids,
    follow_up_date,
    closed,
  }
}

///|
pub fn new_review_register() -> ReviewRegister {
  {
    reviews: [],
    open_count: 0,
    closed_count: 0,
    escalation_count: 0,
    agreement_percent: 0.0,
    status: "empty",
  }
}

///|
fn review_register_status(register : ReviewRegister) -> String {
  if register.escalation_count > 0 {
    "escalated"
  } else if register.open_count > 0 {
    "open"
  } else if register.reviews.length() > 0 {
    "closed"
  } else {
    "empty"
  }
}

///|
pub fn add_manual_review(
  register : ReviewRegister,
  review : ManualReview,
) -> ReviewRegister {
  let reviews = register.reviews.filter(item => item.id != review.id) + [review]
  let closed = reviews.filter(item => item.closed).length()
  let agreed = reviews
    .filter(item => item.original_decision == item.final_decision)
    .length()
  let escalated = reviews
    .filter(item => item.outcome == ReviewEscalated)
    .length()
  let base = {
    reviews,
    open_count: reviews.length() - closed,
    closed_count: closed,
    escalation_count: escalated,
    agreement_percent: if reviews.length() == 0 {
      0.0
    } else {
      agreed.to_double() / reviews.length().to_double() * 100.0
    },
    status: "",
  }
  {
    reviews: base.reviews,
    open_count: base.open_count,
    closed_count: base.closed_count,
    escalation_count: base.escalation_count,
    agreement_percent: base.agreement_percent,
    status: review_register_status(base),
  }
}

///|
pub fn close_manual_review(
  register : ReviewRegister,
  id : String,
  final_decision : String,
) -> ReviewRegister {
  let reviews = register.reviews.map(item => {
    if item.id == id {
      manual_review(
        item.id,
        item.date,
        item.reviewer,
        item.outcome,
        item.original_decision,
        final_decision,
        item.reason,
        item.evidence_ids,
        item.follow_up_date,
        true,
      )
    } else {
      item
    }
  })
  let closed = reviews.filter(item => item.closed).length()
  let agreed = reviews
    .filter(item => item.original_decision == item.final_decision)
    .length()
  let escalated = reviews
    .filter(item => item.outcome == ReviewEscalated)
    .length()
  let base = {
    reviews,
    open_count: reviews.length() - closed,
    closed_count: closed,
    escalation_count: escalated,
    agreement_percent: if reviews.length() == 0 {
      0.0
    } else {
      agreed.to_double() / reviews.length().to_double() * 100.0
    },
    status: "",
  }
  {
    reviews: base.reviews,
    open_count: base.open_count,
    closed_count: base.closed_count,
    escalation_count: base.escalation_count,
    agreement_percent: base.agreement_percent,
    status: review_register_status(base),
  }
}

///|
pub fn review_for_id(register : ReviewRegister, id : String) -> ManualReview? {
  for review in register.reviews {
    if review.id == id {
      return Some(review)
    }
  }
  None
}

///|
pub fn open_reviews(register : ReviewRegister) -> Array[ManualReview] {
  register.reviews.filter(review => !review.closed)
}

///|
pub fn closed_reviews(register : ReviewRegister) -> Array[ManualReview] {
  register.reviews.filter(review => review.closed)
}

///|
pub fn escalated_reviews(register : ReviewRegister) -> Array[ManualReview] {
  register.reviews.filter(review => review.outcome == ReviewEscalated)
}

///|
pub fn reviews_by_outcome(
  register : ReviewRegister,
  outcome : ManualReviewOutcome,
) -> Array[ManualReview] {
  register.reviews.filter(review => review.outcome == outcome)
}

///|
pub fn review_followups_due(
  register : ReviewRegister,
  date : String,
) -> Array[ManualReview] {
  register.reviews.filter(review => {
    !review.closed &&
    review.follow_up_date != "" &&
    review.follow_up_date <= date
  })
}

///|
pub fn review_agreement(register : ReviewRegister) -> Double {
  register.agreement_percent
}

///|
pub fn review_requires_attention(register : ReviewRegister) -> Bool {
  register.open_count > 0 || register.escalation_count > 0
}

///|
pub fn review_recommendation(register : ReviewRegister) -> String {
  if register.escalation_count > 0 {
    "resolve escalated reviews"
  } else if register.open_count > 0 {
    "close open reviews with evidence"
  } else {
    "continue periodic review sampling"
  }
}

///|
pub fn manual_review_text(review : ManualReview) -> String {
  review.id +
  " date=" +
  review.date +
  " reviewer=" +
  review.reviewer +
  " outcome=" +
  manual_review_outcome_name(review.outcome) +
  " original=" +
  review.original_decision +
  " final=" +
  review.final_decision +
  " closed=" +
  review.closed.to_string() +
  " reason=" +
  review.reason
}

///|
pub fn review_register_text(register : ReviewRegister) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "status=" +
    register.status +
    " reviews=" +
    register.reviews.length().to_string() +
    " open=" +
    register.open_count.to_string() +
    " escalated=" +
    register.escalation_count.to_string() +
    " agreement=" +
    register.agreement_percent.to_string() +
    "%",
  )
  for review in register.reviews {
    builder.write_string("\n" + manual_review_text(review))
  }
  builder.to_string()
}

///|
pub fn manual_review_csv_header() -> String {
  "id,date,reviewer,outcome,original_decision,final_decision,follow_up_date,closed,reason"
}

///|
pub fn manual_review_csv(review : ManualReview) -> String {
  review.id +
  "," +
  review.date +
  "," +
  review.reviewer +
  "," +
  manual_review_outcome_name(review.outcome) +
  "," +
  review.original_decision +
  "," +
  review.final_decision +
  "," +
  review.follow_up_date +
  "," +
  review.closed.to_string() +
  "," +
  review.reason
}

///|
pub fn review_register_csv(register : ReviewRegister) -> String {
  let builder = StringBuilder()
  builder.write_string(manual_review_csv_header())
  for review in register.reviews {
    builder.write_string("\n")
    builder.write_string(manual_review_csv(review))
  }
  builder.to_string()
}

///|
pub fn manual_review_valid(review : ManualReview) -> Bool {
  review.id != "" &&
  review.date != "" &&
  review.reviewer != "" &&
  review.original_decision != "" &&
  review.final_decision != "" &&
  review.reason != ""
}

///|
pub fn review_register_valid(register : ReviewRegister) -> Bool {
  register.open_count >= 0 &&
  register.closed_count >= 0 &&
  register.escalation_count >= 0 &&
  register.agreement_percent >= 0.0 &&
  register.agreement_percent <= 100.0 &&
  register.reviews.all(review => manual_review_valid(review))
}
