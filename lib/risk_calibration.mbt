///|
/// Local calibration profiles for adjusting decision thresholds to a dataset.
pub(all) struct CalibrationConfig {
  minimum_samples : Int
  target_high_rate : Double
  target_medium_rate : Double
  minimum_high_score : Double
  maximum_low_score : Double
  smoothing : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct CalibrationResult {
  config : CalibrationConfig
  sample_count : Int
  observed_high_rate : Double
  observed_medium_rate : Double
  calibrated_high_score : Double
  calibrated_medium_score : Double
  confidence : Double
  applied : Bool
  note : String
} derive(Debug, Eq, ToJson)

///|
pub fn default_calibration_config() -> CalibrationConfig {
  {
    minimum_samples: 14,
    target_high_rate: 0.15,
    target_medium_rate: 0.30,
    minimum_high_score: 60.0,
    maximum_low_score: 30.0,
    smoothing: 0.10,
  }
}

///|
fn calibration_high_rate(
  assessments : Array[ComprehensiveAssessment],
) -> Double {
  if assessments.length() == 0 {
    0.0
  } else {
    assessments.filter(item => item.risk_level == High).length().to_double() /
    assessments.length().to_double()
  }
}

///|
fn calibration_medium_rate(
  assessments : Array[ComprehensiveAssessment],
) -> Double {
  if assessments.length() == 0 {
    0.0
  } else {
    assessments.filter(item => item.risk_level == Medium).length().to_double() /
    assessments.length().to_double()
  }
}

///|
fn calibration_scores(
  assessments : Array[ComprehensiveAssessment],
) -> Array[Double] {
  assessments.map(item => item.risk_score)
}

///|
fn calibrated_cutoff(
  scores : Array[Double],
  target_rate : Double,
  floor : Double,
  ceiling : Double,
) -> Double {
  if scores.length() == 0 {
    floor
  } else {
    let percentile = (1.0 - target_rate).max(0.0).min(1.0) * 100.0
    quantile(scores, percentile).max(floor).min(ceiling)
  }
}

///|
pub fn calibrate_assessments(
  assessments : Array[ComprehensiveAssessment],
  config : CalibrationConfig,
) -> CalibrationResult {
  let high_rate = calibration_high_rate(assessments)
  let medium_rate = calibration_medium_rate(assessments)
  let scores = calibration_scores(assessments)
  let applied = assessments.length() >= config.minimum_samples
  let confidence = (assessments.length().to_double() /
  config.minimum_samples.max(1).to_double()).min(1.0)
  {
    config,
    sample_count: assessments.length(),
    observed_high_rate: high_rate,
    observed_medium_rate: medium_rate,
    calibrated_high_score: if applied {
      calibrated_cutoff(
        scores,
        config.target_high_rate,
        config.minimum_high_score,
        100.0,
      )
    } else {
      config.minimum_high_score
    },
    calibrated_medium_score: if applied {
      calibrated_cutoff(
        scores,
        config.target_medium_rate,
        config.maximum_low_score,
        100.0,
      )
    } else {
      config.maximum_low_score
    },
    confidence,
    applied,
    note: if applied {
      "calibration is based on the configured sample floor"
    } else {
      "insufficient samples; default thresholds remain active"
    },
  }
}

///|
pub fn calibrate_records(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  config : CalibrationConfig,
) -> CalibrationResult {
  let assessments = []
  let sorted = sort_records_by_date(records)
  for record in sorted {
    match assess_comprehensive(sorted, record.date, policy) {
      Some(value) => assessments.push(value)
      None => ()
    }
  }
  calibrate_assessments(assessments, config)
}

///|
pub fn calibration_is_reliable(result : CalibrationResult) -> Bool {
  result.applied && result.confidence >= 0.80
}

///|
pub fn calibration_high_threshold(result : CalibrationResult) -> Double {
  result.calibrated_high_score.max(result.calibrated_medium_score)
}

///|
pub fn calibration_medium_threshold(result : CalibrationResult) -> Double {
  result.calibrated_medium_score.min(result.calibrated_high_score)
}

///|
pub fn calibration_classify(
  result : CalibrationResult,
  score : Double,
) -> RiskLevel {
  if score >= calibration_high_threshold(result) {
    High
  } else if score >= calibration_medium_threshold(result) {
    Medium
  } else {
    Low
  }
}

///|
pub fn calibration_drift(result : CalibrationResult) -> Double {
  result.observed_high_rate - result.config.target_high_rate
}

///|
pub fn calibration_needs_review(result : CalibrationResult) -> Bool {
  !result.applied ||
  result.confidence < 0.50 ||
  calibration_drift(result).abs() > 0.20
}

///|
pub fn calibration_recommendation(result : CalibrationResult) -> String {
  if !result.applied {
    "collect more assessments before calibration"
  } else if calibration_needs_review(result) {
    "review calibration sample composition"
  } else {
    "calibration is suitable for local comparison"
  }
}

///|
pub fn calibration_text(result : CalibrationResult) -> String {
  "samples=" +
  result.sample_count.to_string() +
  " observed_high_rate=" +
  result.observed_high_rate.to_string() +
  " observed_medium_rate=" +
  result.observed_medium_rate.to_string() +
  " high_threshold=" +
  calibration_high_threshold(result).to_string() +
  " medium_threshold=" +
  calibration_medium_threshold(result).to_string() +
  " confidence=" +
  result.confidence.to_string() +
  " applied=" +
  result.applied.to_string() +
  " note=" +
  result.note
}

///|
pub fn calibration_config_valid(config : CalibrationConfig) -> Bool {
  config.minimum_samples > 0 &&
  config.target_high_rate >= 0.0 &&
  config.target_high_rate <= 1.0 &&
  config.target_medium_rate >= 0.0 &&
  config.target_medium_rate <= 1.0 &&
  config.minimum_high_score >= 0.0 &&
  config.maximum_low_score >= 0.0 &&
  config.smoothing >= 0.0 &&
  config.smoothing <= 1.0
}

///|
pub fn calibration_result_valid(result : CalibrationResult) -> Bool {
  calibration_config_valid(result.config) &&
  result.sample_count >= 0 &&
  result.observed_high_rate >= 0.0 &&
  result.observed_high_rate <= 1.0 &&
  result.observed_medium_rate >= 0.0 &&
  result.observed_medium_rate <= 1.0 &&
  result.confidence >= 0.0 &&
  result.confidence <= 1.0
}
