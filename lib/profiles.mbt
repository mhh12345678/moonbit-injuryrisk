///|
/// Athlete-specific settings that keep policy thresholds explicit.
pub(all) struct AthleteProfile {
  athlete_id : String
  display_name : String
  target_sleep_hours : Double
  preferred_max_intensity : Double
  pain_review_threshold : Double
  fatigue_review_threshold : Double
  policy : RiskPolicy
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ProfileEvaluation {
  profile : AthleteProfile
  assessment : ComprehensiveAssessment?
  adjusted_readiness : Double
  personalized_action : String
} derive(Debug, Eq, ToJson)

///|
pub fn athlete_profile(
  athlete_id : String,
  display_name : String,
  target_sleep_hours : Double,
  preferred_max_intensity : Double,
  pain_review_threshold : Double,
  fatigue_review_threshold : Double,
  policy : RiskPolicy,
) -> AthleteProfile {
  {
    athlete_id,
    display_name,
    target_sleep_hours,
    preferred_max_intensity,
    pain_review_threshold,
    fatigue_review_threshold,
    policy,
  }
}

///|
pub fn default_athlete_profile(athlete_id : String) -> AthleteProfile {
  athlete_profile(
    athlete_id,
    athlete_id,
    8.0,
    10.0,
    4.0,
    7.0,
    default_risk_policy(),
  )
}

///|
pub fn profile_policy(profile : AthleteProfile) -> RiskPolicy {
  { ..profile.policy, sleep_target: profile.target_sleep_hours }
}

///|
pub fn profile_action(
  profile : AthleteProfile,
  assessment : ComprehensiveAssessment,
) -> String {
  if assessment.recovery.maximum_pain >= profile.pain_review_threshold {
    "clinical review before loading"
  } else if assessment.recovery.maximum_fatigue >=
    profile.fatigue_review_threshold {
    "reduce intensity and protect recovery"
  } else if assessment.readiness_score >= 80.0 {
    "continue a gradual progression"
  } else {
    "maintain load and collect another observation"
  }
}

///|
pub fn evaluate_profile(
  profile : AthleteProfile,
  records : Array[DailyRecord],
) -> ProfileEvaluation {
  let assessment = assess_latest(records, profile_policy(profile))
  let readiness = match assessment {
    Some(value) => value.readiness_score
    None => 0.0
  }
  let adjusted = if records.length() == 0 {
    0.0
  } else {
    let intensity_penalty = records
      .filter(record => {
        record.training_intensity > profile.preferred_max_intensity
      })
      .length()
      .to_double() *
      2.0
    (readiness - intensity_penalty).max(0.0)
  }
  let action = match assessment {
    Some(value) => profile_action(profile, value)
    None => "collect enough telemetry for a personalized assessment"
  }
  {
    profile,
    assessment,
    adjusted_readiness: adjusted,
    personalized_action: action,
  }
}

///|
pub fn profile_text(evaluation : ProfileEvaluation) -> String {
  "athlete=" +
  evaluation.profile.athlete_id +
  " readiness=" +
  evaluation.adjusted_readiness.to_string() +
  " action=" +
  evaluation.personalized_action
}
