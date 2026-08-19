///|
/// Rule groups make policy editing explicit for application configuration.
pub(all) enum RuleGroup {
  LoadRules
  RecoveryRules
  SymptomRules
  DataRules
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PolicyCatalogEntry {
  rule : PolicyRule
  group : RuleGroup
  enabled : Bool
  rationale : String
} derive(Debug, Eq, ToJson)

///|
pub fn rule_group_name(group : RuleGroup) -> String {
  match group {
    LoadRules => "load"
    RecoveryRules => "recovery"
    SymptomRules => "symptoms"
    DataRules => "data"
  }
}

///|
pub fn classify_rule_group(rule : PolicyRule) -> RuleGroup {
  match rule.metric {
    AcuteLoad | ChronicLoad | ACWR | LoadSpike => LoadRules
    SleepHours | SleepQuality | FatigueLevel => RecoveryRules
    PainLevel => SymptomRules
  }
}

///|
pub fn policy_catalog(policy : RiskPolicy) -> Array[PolicyCatalogEntry] {
  policy.rules.map(rule => {
    rule,
    group: classify_rule_group(rule),
    enabled: true,
    rationale: rule.recommendation,
  })
}

///|
pub fn policy_rules_by_group(
  policy : RiskPolicy,
  group : RuleGroup,
) -> Array[PolicyRule] {
  policy.rules.filter(rule => classify_rule_group(rule) == group)
}

///|
pub fn policy_rules_by_metric(
  policy : RiskPolicy,
  metric : Metric,
) -> Array[PolicyRule] {
  policy.rules.filter(rule => rule.metric == metric)
}

///|
pub fn policy_rule_ids(policy : RiskPolicy) -> Array[String] {
  policy.rules.map(rule => rule.id)
}

///|
pub fn policy_contains_rule(policy : RiskPolicy, id : String) -> Bool {
  policy.rules.filter(rule => rule.id == id).length() > 0
}

///|
pub fn policy_with_rule(policy : RiskPolicy, rule : PolicyRule) -> RiskPolicy {
  let rules = policy.rules.filter(item => item.id != rule.id)
  rules.push(rule)
  { ..policy, rules, }
}

///|
pub fn policy_without_rule(policy : RiskPolicy, id : String) -> RiskPolicy {
  { ..policy, rules: policy.rules.filter(rule => rule.id != id) }
}

///|
pub fn policy_with_windows(
  policy : RiskPolicy,
  acute : Int,
  chronic : Int,
  baseline : Int,
) -> RiskPolicy {
  {
    ..policy,
    acute_window: acute,
    chronic_window: chronic,
    baseline_window: baseline,
  }
}

///|
pub fn conservative_policy() -> RiskPolicy {
  let base = default_risk_policy()
  let adjusted = base.rules.map(rule => {
    ..rule,
    threshold: match rule.metric {
      ACWR => rule.threshold - 0.1
      LoadSpike => rule.threshold - 10.0
      SleepHours => rule.threshold + 0.5
      PainLevel => rule.threshold - 0.5
      _ => rule.threshold
    },
    severity: if rule.severity == Low {
      Medium
    } else {
      rule.severity
    },
  })
  { ..base, name: "conservative-v1", rules: adjusted }
}

///|
pub fn performance_policy() -> RiskPolicy {
  let base = default_risk_policy()
  let adjusted = base.rules.map(rule => {
    ..rule,
    threshold: match rule.metric {
      ACWR => rule.threshold + 0.1
      LoadSpike => rule.threshold + 10.0
      SleepHours => rule.threshold - 0.5
      _ => rule.threshold
    },
  })
  { ..base, name: "performance-v1", rules: adjusted }
}

///|
pub fn policy_intersection(left : RiskPolicy, right : RiskPolicy) -> RiskPolicy {
  let rules = []
  for rule in left.rules {
    let matching = right.rules.filter(item => item.id == rule.id)
    match matching.get(0) {
      Some(other) =>
        rules.push({
          ..rule,
          threshold: if rule.operator == LessThan {
            rule.threshold.max(other.threshold)
          } else {
            rule.threshold.min(other.threshold)
          },
          severity: rule.severity.max(other.severity),
        })
      None => ()
    }
  }
  { ..left, name: left.name + "+" + right.name, rules }
}

///|
pub fn policy_explanation(policy : RiskPolicy) -> String {
  let catalog = policy_catalog(policy)
  let builder = StringBuilder::new()
  builder.write_string(policy.name)
  builder.write_string(" rules=")
  builder.write_string(catalog.length().to_string())
  for entry in catalog {
    builder.write_string("\n- [")
    builder.write_string(rule_group_name(entry.group))
    builder.write_string("] ")
    builder.write_string(entry.rule.name)
  }
  builder.to_string()
}
