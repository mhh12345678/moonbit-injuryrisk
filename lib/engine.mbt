///| Helper to convert Operator to readable string.
fn op_symbol(op : Operator) -> String {
  match op {
    GreaterThan => ">"
    LessThan => "<"
    EqualTo => "=="
  }
}

///| Helper to convert Metric to readable label.
fn metric_name(metric : Metric) -> String {
  match metric {
    AcuteLoad => "Acute Workload"
    ChronicLoad => "Chronic Workload"
    ACWR => "ACWR"
    SleepHours => "Sleep Duration"
    SleepQuality => "Sleep Quality"
    PainLevel => "Pain Level"
    FatigueLevel => "Fatigue Level"
    LoadSpike => "Workload Spike"
  }
}

///| Evaluate a single rule against the records ending at a specific index.
pub fn evaluate_rule(
  records : Array[DailyRecord],
  end_idx : Int,
  rule : Rule
) -> RuleResult {
  if end_idx < 0 || end_idx >= records.length() {
    return {
      rule,
      triggered: false,
      actual_value: 0.0,
      explanation: "No telemetry data available for the specified date."
    }
  }

  let window = get_window_by_index(records, end_idx, rule.window_size)
  
  let actual_value = match rule.metric {
    AcuteLoad => average_load(window)
    ChronicLoad => average_load(window)
    ACWR => {
      let acute = average_load(get_window_by_index(records, end_idx, 7))
      let chronic = average_load(get_window_by_index(records, end_idx, 28))
      if chronic == 0.0 { 0.0 } else { acute / chronic }
    }
    SleepHours => average_sleep_hours(window)
    SleepQuality => average_sleep_quality(window)
    PainLevel => max_pain_level(window)
    FatigueLevel => average_fatigue(window)
    LoadSpike => compute_load_spike(records, end_idx)
  }

  let triggered = match rule.op {
    GreaterThan => actual_value > rule.threshold
    LessThan => actual_value < rule.threshold
    EqualTo => actual_value == rule.threshold
  }

  let m_name = metric_name(rule.metric)
  let sym = op_symbol(rule.op)
  
  let explanation = if triggered {
    "Metric '\{m_name}' evaluated to \{actual_value} (threshold: \{sym} \{rule.threshold}). Rule '\{rule.name}' triggered."
  } else {
    "Metric '\{m_name}' evaluated to \{actual_value} (threshold: \{sym} \{rule.threshold}). Rule did not trigger."
  }

  { rule, triggered, actual_value, explanation }
}

///| Perform overall injury risk assessment using the configured rules at the target date.
pub fn assess_injury_risk(
  records : Array[DailyRecord],
  target_date : String,
  rules : Array[Rule]
) -> RiskAssessment? {
  let idx_opt = find_record_index(records, target_date)
  if idx_opt is None {
    return None
  }
  let end_idx = idx_opt.unwrap()
  
  let results = Array::new(capacity=rules.length())
  for rule in rules {
    let result = evaluate_rule(records, end_idx, rule)
    results.push(result)
  }

  let triggered = results.filter((r) => r.triggered)
  
  let overall_risk = triggered.fold(
    init=RiskLevel::Low,
    (acc, r) => acc.max(r.rule.severity)
  )

  let summary_sb = StringBuilder::new()
  summary_sb.write_string("Overall risk level is ")
  summary_sb.write_string(match overall_risk {
    Low => "LOW"
    Medium => "MEDIUM"
    High => "HIGH"
  })
  summary_sb.write_string(".")

  if triggered.length() == 0 {
    summary_sb.write_string(" No training or recovery anomalies detected.")
  } else {
    summary_sb.write_string(" Anomalies detected:")
    for r in triggered {
      summary_sb.write_string("\n- [")
      summary_sb.write_string(match r.rule.severity {
        Low => "LOW"
        Medium => "MEDIUM"
        High => "HIGH"
      })
      summary_sb.write_string("] ")
      summary_sb.write_string(r.rule.name)
      summary_sb.write_string(": ")
      summary_sb.write_string(r.explanation)
    }
  }

  Some({
    date: target_date,
    risk_level: overall_risk,
    triggered_rules: results,
    summary: summary_sb.to_string()
  })
}
