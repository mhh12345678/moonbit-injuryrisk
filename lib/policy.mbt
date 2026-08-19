///|
/// A production policy condition with an explicit stable identifier.
pub(all) struct PolicyRule {
  id : String
  name : String
  metric : Metric
  operator : Operator
  threshold : Double
  window_size : Int
  severity : RiskLevel
  weight : Double
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RiskPolicy {
  name : String
  acute_window : Int
  chronic_window : Int
  baseline_window : Int
  high_acwr : Double
  medium_acwr : Double
  sleep_target : Double
  recovery_weights : RecoveryWeights
  rules : Array[PolicyRule]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PolicyDecision {
  rule_id : String
  rule_name : String
  metric : Metric
  triggered : Bool
  actual_value : Double
  threshold : Double
  severity : RiskLevel
  weight : Double
  message : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PolicyValidation {
  valid : Bool
  errors : Array[String]
  warnings : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub fn policy_rule(
  id : String,
  name : String,
  metric : Metric,
  operator : Operator,
  threshold : Double,
  window_size : Int,
  severity : RiskLevel,
  weight : Double,
  recommendation : String,
) -> PolicyRule {
  {
    id,
    name,
    metric,
    operator,
    threshold,
    window_size,
    severity,
    weight,
    recommendation,
  }
}

///|
pub fn default_risk_policy() -> RiskPolicy {
  {
    name: "balanced-training-v1",
    acute_window: 7,
    chronic_window: 28,
    baseline_window: 28,
    high_acwr: 1.5,
    medium_acwr: 1.3,
    sleep_target: 8.0,
    recovery_weights: default_recovery_weights(),
    rules: [
      policy_rule(
        "load.acwr.high",
        "High acute to chronic load ratio",
        ACWR,
        GreaterThan,
        1.5,
        28,
        High,
        1.0,
        "Reduce high-intensity volume and review the last four weeks of load.",
      ),
      policy_rule(
        "load.acwr.medium",
        "Elevated acute to chronic load ratio",
        ACWR,
        GreaterThan,
        1.3,
        28,
        Medium,
        0.7,
        "Use a conservative progression and add a recovery day.",
      ),
      policy_rule(
        "recovery.sleep",
        "Insufficient rolling sleep",
        SleepHours,
        LessThan,
        7.0,
        7,
        High,
        0.9,
        "Protect sleep opportunity before increasing training load.",
      ),
      policy_rule(
        "recovery.quality",
        "Low sleep quality",
        SleepQuality,
        LessThan,
        3.0,
        7,
        Medium,
        0.5,
        "Check recovery routines and reduce late high-intensity work.",
      ),
      policy_rule(
        "pain.high",
        "High reported pain",
        PainLevel,
        GreaterThan,
        4.0,
        3,
        High,
        1.0,
        "Pause aggravating work and route the athlete for clinical review.",
      ),
      policy_rule(
        "fatigue.high",
        "High subjective fatigue",
        FatigueLevel,
        GreaterThan,
        7.0,
        7,
        Medium,
        0.7,
        "Replace intense work with low-load movement until fatigue falls.",
      ),
      policy_rule(
        "load.spike",
        "Week-over-week load spike",
        LoadSpike,
        GreaterThan,
        50.0,
        7,
        Medium,
        0.6,
        "Avoid a second consecutive spike and inspect session distribution.",
      ),
      policy_rule(
        "load.rest-days",
        "Too few rest days",
        ChronicLoad,
        GreaterThan,
        5000.0,
        28,
        Low,
        0.3,
        "Schedule a rest day and review cumulative strain.",
      ),
    ],
  }
}

///|
pub fn validate_policy(policy : RiskPolicy) -> PolicyValidation {
  let errors = []
  let warnings = []
  if policy.acute_window <= 0 ||
    policy.chronic_window <= 0 ||
    policy.baseline_window <= 0 {
    errors.push("policy windows must be positive")
  }
  if policy.acute_window > policy.chronic_window {
    warnings.push("acute window is longer than chronic window")
  }
  if policy.high_acwr < policy.medium_acwr {
    errors.push("high ACWR threshold must be at least the medium threshold")
  }
  if policy.sleep_target <= 0.0 {
    errors.push("sleep target must be positive")
  }
  if policy.rules.length() == 0 {
    warnings.push("policy has no rules")
  }
  for rule in policy.rules {
    if rule.id == "" || rule.name == "" {
      errors.push("every policy rule needs an id and name")
    }
    if rule.window_size <= 0 {
      errors.push("policy rule windows must be positive")
    }
    if rule.weight < 0.0 {
      errors.push("policy rule weights cannot be negative")
    }
  }
  { valid: errors.length() == 0, errors, warnings }
}

///|
pub fn policy_metric_value(
  records : Array[DailyRecord],
  end_idx : Int,
  metric : Metric,
  window_size : Int,
) -> Double {
  let window = get_window_by_index(records, end_idx, window_size)
  match metric {
    AcuteLoad => average_load(window)
    ChronicLoad => average_load(window)
    ACWR => acwr_at(records, end_idx, 7, window_size.max(28))
    SleepHours => average_sleep_hours(window)
    SleepQuality => average_sleep_quality(window)
    PainLevel => max_pain_level(window)
    FatigueLevel => average_fatigue(window)
    LoadSpike => compute_load_spike(records, end_idx)
  }
}

///|
fn evaluate_operator(
  value : Double,
  operator : Operator,
  threshold : Double,
) -> Bool {
  match operator {
    GreaterThan => value > threshold
    LessThan => value < threshold
    EqualTo => value == threshold
  }
}

///|
pub fn evaluate_policy_rule(
  records : Array[DailyRecord],
  end_idx : Int,
  rule : PolicyRule,
) -> PolicyDecision {
  let value = policy_metric_value(
    records,
    end_idx,
    rule.metric,
    rule.window_size,
  )
  let triggered = end_idx >= 0 &&
    end_idx < records.length() &&
    evaluate_operator(value, rule.operator, rule.threshold)
  let symbol = match rule.operator {
    GreaterThan => ">"
    LessThan => "<"
    EqualTo => "=="
  }
  let message = if triggered {
    rule.name +
    " triggered: value=" +
    value.to_string() +
    " threshold=" +
    symbol +
    " " +
    rule.threshold.to_string() +
    ". " +
    rule.recommendation
  } else {
    rule.name +
    " clear: value=" +
    value.to_string() +
    " threshold=" +
    symbol +
    " " +
    rule.threshold.to_string()
  }
  {
    rule_id: rule.id,
    rule_name: rule.name,
    metric: rule.metric,
    triggered,
    actual_value: value,
    threshold: rule.threshold,
    severity: rule.severity,
    weight: rule.weight,
    message,
  }
}

///|
pub fn evaluate_policy(
  records : Array[DailyRecord],
  end_idx : Int,
  policy : RiskPolicy,
) -> Array[PolicyDecision] {
  policy.rules.map(rule => evaluate_policy_rule(records, end_idx, rule))
}

///|
pub fn triggered_policy_decisions(
  decisions : Array[PolicyDecision],
) -> Array[PolicyDecision] {
  decisions.filter(decision => decision.triggered)
}

///|
pub fn weighted_risk_score(decisions : ArrayView[PolicyDecision]) -> Double {
  let mut score = 0.0
  let mut total = 0.0
  for decision in decisions {
    total += decision.weight
    if decision.triggered {
      let severity_weight = match decision.severity {
        Low => 1.0
        Medium => 2.0
        High => 3.0
      }
      score += decision.weight * severity_weight
    }
  }
  if total == 0.0 {
    0.0
  } else {
    score / total / 3.0 * 100.0
  }
}

///|
pub fn highest_policy_risk(decisions : ArrayView[PolicyDecision]) -> RiskLevel {
  let mut risk = Low
  for decision in decisions {
    if decision.triggered {
      risk = risk.max(decision.severity)
    }
  }
  risk
}

///|
pub fn policy_decision_text(decision : PolicyDecision) -> String {
  let state = if decision.triggered { "triggered" } else { "clear" }
  state + " " + decision.rule_id + " value=" + decision.actual_value.to_string()
}
