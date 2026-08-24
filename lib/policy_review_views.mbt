///|
/// Policy review views make thresholds and their operational impact visible.
pub(all) struct PolicyReviewCard {
  name : String
  category : String
  value : Double
  unit : String
  rationale : String
  risk : String
  valid : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PolicyReviewView {
  policy_name : String
  cards : Array[PolicyReviewCard]
  invalid_count : Int
  high_sensitivity_count : Int
  status : String
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PolicySensitivity {
  name : String
  baseline : Double
  lower : Double
  upper : Double
  span : Double
  note : String
} derive(Debug, Eq, ToJson)

///|
fn policy_review_card(
  name : String,
  category : String,
  value : Double,
  unit : String,
  rationale : String,
  risk : String,
  valid : Bool,
) -> PolicyReviewCard {
  { name, category, value, unit, rationale, risk, valid }
}

///|
pub fn policy_review_cards(
  config : DecisionRunConfig,
) -> Array[PolicyReviewCard] {
  let policy = config.risk_policy
  let monitor = config.monitor_thresholds
  let gate = config.quality_gate
  [
    policy_review_card(
      "acute_window",
      "load",
      policy.acute_window.to_double(),
      "days",
      "acute load horizon",
      if policy.acute_window < 3 {
        "high"
      } else {
        "normal"
      },
      policy.acute_window > 0,
    ),
    policy_review_card(
      "chronic_window",
      "load",
      policy.chronic_window.to_double(),
      "days",
      "chronic load horizon",
      if policy.chronic_window < policy.acute_window {
        "high"
      } else {
        "normal"
      },
      policy.chronic_window >= policy.acute_window,
    ),
    policy_review_card(
      "baseline_window",
      "load",
      policy.baseline_window.to_double(),
      "days",
      "baseline comparison horizon",
      "normal",
      policy.baseline_window > 0,
    ),
    policy_review_card(
      "high_acwr",
      "load",
      policy.high_acwr,
      "ratio",
      "high workload ratio threshold",
      if policy.high_acwr < 1.2 {
        "high"
      } else {
        "normal"
      },
      policy.high_acwr > policy.medium_acwr,
    ),
    policy_review_card(
      "medium_acwr",
      "load",
      policy.medium_acwr,
      "ratio",
      "medium workload ratio threshold",
      "normal",
      policy.medium_acwr > 0.0,
    ),
    policy_review_card(
      "sleep_target",
      "recovery",
      policy.sleep_target,
      "hours",
      "sleep target",
      if policy.sleep_target < 6.0 {
        "high"
      } else {
        "normal"
      },
      policy.sleep_target > 0.0 && policy.sleep_target <= 24.0,
    ),
    policy_review_card(
      "high_risk_score",
      "monitoring",
      monitor.high_risk_score,
      "score",
      "escalation floor",
      if monitor.high_risk_score < 60.0 {
        "high"
      } else {
        "normal"
      },
      monitor.high_risk_score <= 100.0,
    ),
    policy_review_card(
      "medium_risk_score",
      "monitoring",
      monitor.medium_risk_score,
      "score",
      "action floor",
      "normal",
      monitor.medium_risk_score >= 0.0 &&
      monitor.medium_risk_score < monitor.high_risk_score,
    ),
    policy_review_card(
      "minimum_readiness",
      "monitoring",
      monitor.minimum_readiness,
      "score",
      "readiness floor",
      "normal",
      monitor.minimum_readiness >= 0.0 && monitor.minimum_readiness <= 100.0,
    ),
    policy_review_card(
      "maximum_pain",
      "monitoring",
      monitor.maximum_pain,
      "score",
      "pain action threshold",
      "normal",
      monitor.maximum_pain >= 0.0 && monitor.maximum_pain <= 10.0,
    ),
    policy_review_card(
      "maximum_acwr",
      "monitoring",
      monitor.maximum_acwr,
      "ratio",
      "monitoring ratio threshold",
      "normal",
      monitor.maximum_acwr > 0.0,
    ),
    policy_review_card(
      "minimum_sleep_hours",
      "monitoring",
      monitor.minimum_sleep_hours,
      "hours",
      "sleep action threshold",
      "normal",
      monitor.minimum_sleep_hours >= 0.0 && monitor.minimum_sleep_hours <= 24.0,
    ),
    policy_review_card(
      "maximum_fatigue",
      "monitoring",
      monitor.maximum_fatigue,
      "score",
      "fatigue action threshold",
      "normal",
      monitor.maximum_fatigue >= 0.0 && monitor.maximum_fatigue <= 10.0,
    ),
    policy_review_card(
      "quality_floor",
      "monitoring",
      monitor.quality_floor,
      "score",
      "quality floor",
      "normal",
      monitor.quality_floor >= 0.0 && monitor.quality_floor <= 100.0,
    ),
    policy_review_card(
      "minimum_records",
      "quality",
      gate.minimum_records.to_double(),
      "records",
      "minimum history",
      "normal",
      gate.minimum_records >= 0,
    ),
    policy_review_card(
      "minimum_coverage",
      "quality",
      gate.minimum_coverage * 100.0,
      "percent",
      "coverage floor",
      "normal",
      gate.minimum_coverage >= 0.0 && gate.minimum_coverage <= 1.0,
    ),
  ]
}

///|
pub fn build_policy_review_view(config : DecisionRunConfig) -> PolicyReviewView {
  let cards = policy_review_cards(config)
  let invalid = cards.filter(card => !card.valid).length()
  let sensitive = cards.filter(card => card.risk == "high").length()
  {
    policy_name: config.risk_policy.name,
    cards,
    invalid_count: invalid,
    high_sensitivity_count: sensitive,
    status: if invalid > 0 {
      "invalid"
    } else if sensitive > 0 {
      "sensitive"
    } else {
      "stable"
    },
    recommendation: if invalid > 0 {
      "repair invalid policy thresholds"
    } else if sensitive > 0 {
      "review high-sensitivity thresholds"
    } else {
      "policy is ready for operational use"
    },
  }
}

///|
pub fn policy_review_card_by_name(
  view : PolicyReviewView,
  name : String,
) -> PolicyReviewCard? {
  for card in view.cards {
    if card.name == name {
      return Some(card)
    }
  }
  None
}

///|
pub fn policy_review_cards_by_category(
  view : PolicyReviewView,
  category : String,
) -> Array[PolicyReviewCard] {
  view.cards.filter(card => card.category == category)
}

///|
pub fn policy_review_categories(view : PolicyReviewView) -> Array[String] {
  let values = []
  for card in view.cards {
    if !values.contains(card.category) {
      values.push(card.category)
    }
  }
  values
}

///|
pub fn policy_review_names(view : PolicyReviewView) -> Array[String] {
  view.cards.map(card => card.name)
}

///|
pub fn policy_review_values(view : PolicyReviewView) -> Array[Double] {
  view.cards.map(card => card.value)
}

///|
pub fn policy_review_invalid_cards(
  view : PolicyReviewView,
) -> Array[PolicyReviewCard] {
  view.cards.filter(card => !card.valid)
}

///|
pub fn policy_review_sensitive_cards(
  view : PolicyReviewView,
) -> Array[PolicyReviewCard] {
  view.cards.filter(card => card.risk == "high")
}

///|
pub fn policy_review_count(view : PolicyReviewView) -> Int {
  view.cards.length()
}

///|
pub fn policy_review_invalid_count(view : PolicyReviewView) -> Int {
  view.invalid_count
}

///|
pub fn policy_review_sensitive_count(view : PolicyReviewView) -> Int {
  view.high_sensitivity_count
}

///|
pub fn policy_review_valid(view : PolicyReviewView) -> Bool {
  view.cards.length() > 0 &&
  view.cards.all(card => policy_review_card_valid(card)) &&
  view.invalid_count == policy_review_invalid_cards(view).length()
}

///|
pub fn policy_review_card_valid(card : PolicyReviewCard) -> Bool {
  card.name != "" &&
  card.category != "" &&
  card.unit != "" &&
  card.rationale != "" &&
  card.value.is_nan() == false
}

///|
pub fn policy_review_value(view : PolicyReviewView, name : String) -> Double {
  match policy_review_card_by_name(view, name) {
    Some(card) => card.value
    None => 0.0
  }
}

///|
pub fn policy_review_category_average(
  view : PolicyReviewView,
  category : String,
) -> Double {
  mean_load_values(
    policy_review_cards_by_category(view, category).map(card => card.value),
  )
}

///|
pub fn policy_review_category_maximum(
  view : PolicyReviewView,
  category : String,
) -> Double {
  maximum_load_values(
    policy_review_cards_by_category(view, category).map(card => card.value),
  )
}

///|
pub fn policy_review_category_minimum(
  view : PolicyReviewView,
  category : String,
) -> Double {
  minimum_load_values(
    policy_review_cards_by_category(view, category).map(card => card.value),
  )
}

///|
pub fn policy_review_category_deviation(
  view : PolicyReviewView,
  category : String,
) -> Double {
  standard_deviation_values(
    policy_review_cards_by_category(view, category).map(card => card.value),
  )
}

///|
pub fn policy_review_sensitivity(
  view : PolicyReviewView,
  name : String,
  tolerance : Double,
) -> PolicySensitivity {
  let baseline = policy_review_value(view, name)
  {
    name,
    baseline,
    lower: baseline - tolerance,
    upper: baseline + tolerance,
    span: tolerance * 2.0,
    note: "change within configured tolerance",
  }
}

///|
pub fn policy_review_sensitivities(
  view : PolicyReviewView,
  tolerance : Double,
) -> Array[PolicySensitivity] {
  view.cards.map(card => policy_review_sensitivity(view, card.name, tolerance))
}

///|
pub fn policy_review_status(view : PolicyReviewView) -> String {
  view.status
}

///|
pub fn policy_review_recommendation(view : PolicyReviewView) -> String {
  view.recommendation
}

///|
pub fn policy_review_needs_review(view : PolicyReviewView) -> Bool {
  view.invalid_count > 0 || view.high_sensitivity_count > 0
}

///|
pub fn policy_review_status_code(view : PolicyReviewView) -> Int {
  if view.status == "invalid" {
    422
  } else if view.status == "sensitive" {
    206
  } else {
    200
  }
}

///|
pub fn policy_review_card_text(card : PolicyReviewCard) -> String {
  card.name +
  " category=" +
  card.category +
  " value=" +
  card.value.to_string() +
  " " +
  card.unit +
  " risk=" +
  card.risk +
  " valid=" +
  card.valid.to_string() +
  " rationale=" +
  card.rationale
}

///|
pub fn policy_review_text(view : PolicyReviewView) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "policy=" +
    view.policy_name +
    " status=" +
    view.status +
    " cards=" +
    view.cards.length().to_string() +
    " invalid=" +
    view.invalid_count.to_string() +
    " sensitive=" +
    view.high_sensitivity_count.to_string(),
  )
  builder.write_string("\nrecommendation=" + view.recommendation)
  for card in view.cards {
    builder.write_string("\n" + policy_review_card_text(card))
  }
  builder.to_string()
}

///|
pub fn policy_review_card_csv_header() -> String {
  "name,category,value,unit,rationale,risk,valid"
}

///|
pub fn policy_review_card_csv(card : PolicyReviewCard) -> String {
  card.name +
  "," +
  card.category +
  "," +
  card.value.to_string() +
  "," +
  card.unit +
  "," +
  card.rationale +
  "," +
  card.risk +
  "," +
  card.valid.to_string()
}

///|
pub fn policy_review_csv(view : PolicyReviewView) -> String {
  let builder = StringBuilder()
  builder.write_string(policy_review_card_csv_header())
  for card in view.cards {
    builder.write_string("\n" + policy_review_card_csv(card))
  }
  builder.to_string()
}

///|
pub fn policy_review_summary_header() -> Array[String] {
  ["policy_name", "status", "cards", "invalid", "sensitive", "recommendation"]
}

///|
pub fn policy_review_summary(view : PolicyReviewView) -> Array[String] {
  [
    view.policy_name,
    view.status,
    view.cards.length().to_string(),
    view.invalid_count.to_string(),
    view.high_sensitivity_count.to_string(),
    view.recommendation,
  ]
}

///|
pub fn policy_review_summary_csv(view : PolicyReviewView) -> String {
  policy_review_summary_header().join(",") +
  "\n" +
  policy_review_summary(view).join(",")
}

///|
pub fn policy_review_checksum(view : PolicyReviewView) -> String {
  let mut value = view.cards.length() + view.invalid_count
  for character in policy_review_text(view) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn policy_review_reproducible(
  left : PolicyReviewView,
  right : PolicyReviewView,
) -> Bool {
  policy_review_checksum(left) == policy_review_checksum(right)
}

///|
pub fn policy_review_exportable(view : PolicyReviewView) -> Bool {
  policy_review_valid(view)
}

///|
pub fn policy_review_export_status(view : PolicyReviewView) -> String {
  if policy_review_exportable(view) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn policy_review_contract(view : PolicyReviewView) -> Array[String] {
  [
    view.policy_name,
    view.status,
    view.invalid_count.to_string(),
    view.high_sensitivity_count.to_string(),
    policy_review_recommendation(view),
    policy_review_needs_review(view).to_string(),
    policy_review_export_status(view),
    policy_review_checksum(view),
  ]
}
