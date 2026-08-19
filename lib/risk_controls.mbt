///|
/// Guardrail controls that turn metrics into bounded operational choices.
pub(all) struct RiskControlConfig {
  maximum_risk : Double
  minimum_readiness : Double
  maximum_pain : Double
  maximum_acwr : Double
  maximum_daily_load : Double
  maximum_consecutive_days : Int
  require_quality : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RiskControlResult {
  allowed : Bool
  load_cap : Double
  intensity_cap : Double
  rest_required : Bool
  referral_required : Bool
  reasons : Array[String]
  next_action : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RiskControlSnapshot {
  date : String
  result : RiskControlResult
  current_load : Double
  current_intensity : Double
  current_acwr : Double
  current_readiness : Double
  current_pain : Double
  consecutive_days : Int
} derive(Debug, Eq, ToJson)

///|
pub fn default_risk_control_config() -> RiskControlConfig {
  {
    maximum_risk: 40.0,
    minimum_readiness: 70.0,
    maximum_pain: 4.0,
    maximum_acwr: 1.5,
    maximum_daily_load: 900.0,
    maximum_consecutive_days: 5,
    require_quality: true,
  }
}

///|
fn control_reasons(
  assessment : ComprehensiveAssessment,
  record : DailyRecord,
  streak : Int,
  config : RiskControlConfig,
) -> Array[String] {
  let reasons = []
  if assessment.risk_score > config.maximum_risk {
    reasons.push("risk score exceeds control limit")
  }
  if assessment.readiness_score < config.minimum_readiness {
    reasons.push("readiness is below control floor")
  }
  if assessment.load.acwr > config.maximum_acwr {
    reasons.push("acute chronic ratio exceeds control limit")
  }
  if record.pain_level > config.maximum_pain {
    reasons.push("pain exceeds control limit")
  }
  if daily_training_load(record) > config.maximum_daily_load {
    reasons.push("daily load exceeds control limit")
  }
  if streak > config.maximum_consecutive_days {
    reasons.push("consecutive training days exceed control limit")
  }
  if config.require_quality && assessment.quality.blocking_issue_count > 0 {
    reasons.push("quality is blocking")
  }
  reasons
}

///|
pub fn evaluate_risk_control(
  assessment : ComprehensiveAssessment,
  record : DailyRecord,
  streak : Int,
  config : RiskControlConfig,
) -> RiskControlResult {
  let reasons = control_reasons(assessment, record, streak, config)
  let severe = assessment.risk_level == High ||
    record.pain_level >= config.maximum_pain + 2.0
  let load_cap = if severe {
    0.0
  } else if reasons.length() > 0 {
    daily_training_load(record).min(config.maximum_daily_load) * 0.80
  } else {
    config.maximum_daily_load
  }
  let intensity_cap = if severe {
    0.0
  } else if reasons.length() > 0 {
    5.0
  } else {
    8.0
  }
  {
    allowed: reasons.length() == 0,
    load_cap,
    intensity_cap,
    rest_required: severe ||
    reasons.contains("consecutive training days exceed control limit"),
    referral_required: severe || record.pain_level > config.maximum_pain,
    reasons,
    next_action: if severe {
      "pause and refer"
    } else if reasons.length() > 0 {
      "hold or reduce load"
    } else {
      "progress within caps"
    },
  }
}

///|
pub fn risk_control_for_records(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  config : RiskControlConfig,
) -> RiskControlSnapshot? {
  let sorted = sort_records_by_date(records)
  if sorted.length() == 0 {
    return None
  }
  let record = sorted[sorted.length() - 1]
  match assess_latest(sorted, policy) {
    Some(assessment) => {
      let streak = longest_training_block(sorted)
      let result = evaluate_risk_control(assessment, record, streak, config)
      Some({
        date: record.date,
        result,
        current_load: daily_training_load(record),
        current_intensity: record.training_intensity,
        current_acwr: assessment.load.acwr,
        current_readiness: assessment.readiness_score,
        current_pain: record.pain_level,
        consecutive_days: streak,
      })
    }
    None => None
  }
}

///|
pub fn control_load_cap(snapshot : RiskControlSnapshot) -> Double {
  snapshot.result.load_cap
}

///|
pub fn control_intensity_cap(snapshot : RiskControlSnapshot) -> Double {
  snapshot.result.intensity_cap
}

///|
pub fn control_is_safe(snapshot : RiskControlSnapshot) -> Bool {
  snapshot.result.allowed && !snapshot.result.referral_required
}

///|
pub fn control_requires_rest(snapshot : RiskControlSnapshot) -> Bool {
  snapshot.result.rest_required
}

///|
pub fn control_requires_referral(snapshot : RiskControlSnapshot) -> Bool {
  snapshot.result.referral_required
}

///|
pub fn control_reason_codes(snapshot : RiskControlSnapshot) -> Array[String] {
  snapshot.result.reasons
}

///|
pub fn control_apply_load(
  snapshot : RiskControlSnapshot,
  proposed_load : Double,
) -> Double {
  proposed_load.min(snapshot.result.load_cap).max(0.0)
}

///|
pub fn control_apply_intensity(
  snapshot : RiskControlSnapshot,
  proposed_intensity : Double,
) -> Double {
  proposed_intensity.min(snapshot.result.intensity_cap).max(0.0)
}

///|
pub fn control_projected_load(
  snapshot : RiskControlSnapshot,
  duration : Double,
  intensity : Double,
) -> Double {
  control_apply_load(
    snapshot,
    duration.max(0.0) * control_apply_intensity(snapshot, intensity),
  )
}

///|
pub fn control_status(snapshot : RiskControlSnapshot) -> String {
  if snapshot.result.referral_required {
    "refer"
  } else if snapshot.result.rest_required {
    "rest"
  } else if snapshot.result.allowed {
    "allow"
  } else {
    "reduce"
  }
}

///|
pub fn risk_control_text(snapshot : RiskControlSnapshot) -> String {
  snapshot.date +
  " status=" +
  control_status(snapshot) +
  " load_cap=" +
  snapshot.result.load_cap.to_string() +
  " intensity_cap=" +
  snapshot.result.intensity_cap.to_string() +
  " risk=" +
  snapshot.current_acwr.to_string() +
  " readiness=" +
  snapshot.current_readiness.to_string() +
  " reasons=" +
  snapshot.result.reasons.join(";")
}

///|
pub fn risk_control_config_valid(config : RiskControlConfig) -> Bool {
  config.maximum_risk >= 0.0 &&
  config.maximum_risk <= 100.0 &&
  config.minimum_readiness >= 0.0 &&
  config.minimum_readiness <= 100.0 &&
  config.maximum_pain >= 0.0 &&
  config.maximum_acwr >= 0.0 &&
  config.maximum_daily_load >= 0.0 &&
  config.maximum_consecutive_days > 0
}

///|
pub fn risk_control_result_valid(result : RiskControlResult) -> Bool {
  result.load_cap >= 0.0 &&
  result.intensity_cap >= 0.0 &&
  result.intensity_cap <= 10.0 &&
  result.next_action != ""
}
