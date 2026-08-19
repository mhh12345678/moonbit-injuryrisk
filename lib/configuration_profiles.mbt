///|
/// Named policy profiles for integrating the library into different workflows.
pub(all) enum ConfigurationProfileKind {
  ConservativeProfile
  BalancedProfile
  PerformanceProfile
  ReturnProfile
  DataReviewProfile
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ConfigurationProfile {
  kind : ConfigurationProfileKind
  name : String
  risk_policy : RiskPolicy
  monitor_thresholds : MonitoringThresholds
  quality_gate : QualityGateConfig
  control : RiskControlConfig
  description : String
} derive(Debug, Eq, ToJson)

///|
pub fn configuration_profile_name(kind : ConfigurationProfileKind) -> String {
  match kind {
    ConservativeProfile => "conservative"
    BalancedProfile => "balanced"
    PerformanceProfile => "performance"
    ReturnProfile => "return"
    DataReviewProfile => "data_review"
  }
}

///|
fn configuration_profile_policy(kind : ConfigurationProfileKind) -> RiskPolicy {
  let policy = default_risk_policy()
  match kind {
    ConservativeProfile =>
      {
        name: policy.name,
        acute_window: policy.acute_window,
        chronic_window: policy.chronic_window,
        baseline_window: policy.baseline_window,
        high_acwr: 1.35,
        medium_acwr: 1.20,
        sleep_target: 8.5,
        recovery_weights: policy.recovery_weights,
        rules: policy.rules,
      }
    BalancedProfile => policy
    PerformanceProfile =>
      {
        name: policy.name,
        acute_window: policy.acute_window,
        chronic_window: policy.chronic_window,
        baseline_window: policy.baseline_window,
        high_acwr: 1.60,
        medium_acwr: 1.35,
        sleep_target: 7.5,
        recovery_weights: policy.recovery_weights,
        rules: policy.rules,
      }
    ReturnProfile =>
      {
        name: policy.name,
        acute_window: policy.acute_window,
        chronic_window: policy.chronic_window,
        baseline_window: policy.baseline_window,
        high_acwr: 1.25,
        medium_acwr: 1.15,
        sleep_target: 8.5,
        recovery_weights: policy.recovery_weights,
        rules: policy.rules,
      }
    DataReviewProfile =>
      {
        name: policy.name,
        acute_window: policy.acute_window,
        chronic_window: 14,
        baseline_window: 14,
        high_acwr: policy.high_acwr,
        medium_acwr: policy.medium_acwr,
        sleep_target: policy.sleep_target,
        recovery_weights: policy.recovery_weights,
        rules: policy.rules,
      }
  }
}

///|
fn profile_monitor(kind : ConfigurationProfileKind) -> MonitoringThresholds {
  let thresholds = default_monitoring_thresholds()
  match kind {
    ConservativeProfile =>
      {
        high_risk_score: 60.0,
        medium_risk_score: 30.0,
        minimum_readiness: thresholds.minimum_readiness,
        maximum_pain: thresholds.maximum_pain,
        maximum_acwr: thresholds.maximum_acwr,
        minimum_sleep_hours: thresholds.minimum_sleep_hours,
        maximum_fatigue: thresholds.maximum_fatigue,
        quality_floor: thresholds.quality_floor,
        consecutive_days: thresholds.consecutive_days,
      }
    BalancedProfile => thresholds
    PerformanceProfile =>
      {
        high_risk_score: 75.0,
        medium_risk_score: thresholds.medium_risk_score,
        minimum_readiness: thresholds.minimum_readiness,
        maximum_pain: thresholds.maximum_pain,
        maximum_acwr: thresholds.maximum_acwr,
        minimum_sleep_hours: thresholds.minimum_sleep_hours,
        maximum_fatigue: thresholds.maximum_fatigue,
        quality_floor: thresholds.quality_floor,
        consecutive_days: thresholds.consecutive_days,
      }
    ReturnProfile =>
      {
        high_risk_score: thresholds.high_risk_score,
        medium_risk_score: thresholds.medium_risk_score,
        minimum_readiness: 75.0,
        maximum_pain: 2.0,
        maximum_acwr: 1.25,
        minimum_sleep_hours: thresholds.minimum_sleep_hours,
        maximum_fatigue: thresholds.maximum_fatigue,
        quality_floor: thresholds.quality_floor,
        consecutive_days: thresholds.consecutive_days,
      }
    DataReviewProfile =>
      {
        high_risk_score: thresholds.high_risk_score,
        medium_risk_score: thresholds.medium_risk_score,
        minimum_readiness: thresholds.minimum_readiness,
        maximum_pain: thresholds.maximum_pain,
        maximum_acwr: thresholds.maximum_acwr,
        minimum_sleep_hours: thresholds.minimum_sleep_hours,
        maximum_fatigue: thresholds.maximum_fatigue,
        quality_floor: 90.0,
        consecutive_days: thresholds.consecutive_days,
      }
  }
}

///|
pub fn configuration_profile(
  kind : ConfigurationProfileKind,
) -> ConfigurationProfile {
  let quality = default_quality_gate_config()
  let control = default_risk_control_config()
  let description = match kind {
    ConservativeProfile => "early warning and small progression steps"
    BalancedProfile => "general daily monitoring"
    PerformanceProfile => "performance-oriented with explicit guardrails"
    ReturnProfile => "conservative return-to-training checks"
    DataReviewProfile => "strict data quality before interpretation"
  }
  {
    kind,
    name: configuration_profile_name(kind),
    risk_policy: configuration_profile_policy(kind),
    monitor_thresholds: profile_monitor(kind),
    quality_gate: quality,
    control,
    description,
  }
}

///|
pub fn configuration_profiles() -> Array[ConfigurationProfile] {
  configuration_profile_kinds().map(kind => configuration_profile(kind))
}

///|
pub fn configuration_profile_kinds() -> Array[ConfigurationProfileKind] {
  [
    ConservativeProfile,
    BalancedProfile,
    PerformanceProfile,
    ReturnProfile,
    DataReviewProfile,
  ]
}

///|
pub fn configuration_profile_for_name(name : String) -> ConfigurationProfile? {
  for profile in configuration_profiles() {
    if profile.name == name {
      return Some(profile)
    }
  }
  None
}

///|
pub fn configuration_profile_valid(profile : ConfigurationProfile) -> Bool {
  profile.name != "" &&
  monitoring_config_valid(profile.monitor_thresholds) &&
  quality_gate_config_valid(profile.quality_gate) &&
  risk_control_config_valid(profile.control)
}

///|
pub fn configuration_profile_summary(profile : ConfigurationProfile) -> String {
  profile.name +
  ": " +
  profile.description +
  " high_risk=" +
  profile.monitor_thresholds.high_risk_score.to_string() +
  " minimum_readiness=" +
  profile.monitor_thresholds.minimum_readiness.to_string() +
  " quality_floor=" +
  profile.monitor_thresholds.quality_floor.to_string()
}

///|
pub fn configuration_profile_texts() -> Array[String] {
  configuration_profiles().map(profile => configuration_profile_summary(profile))
}
