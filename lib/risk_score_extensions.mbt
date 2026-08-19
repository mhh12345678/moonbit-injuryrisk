///|
/// Decomposed risk scores make an automated recommendation inspectable.
pub(all) enum RiskScoreBand {
  ScoreLow
  ScoreWatch
  ScoreAction
  ScoreEscalate
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RiskScoreComponent {
  name : String
  value : Double
  weight : Double
  contribution : Double
  band : RiskScoreBand
  evidence : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RiskScoreProfile {
  date : String
  components : Array[RiskScoreComponent]
  total : Double
  dominant_component : String
  dominant_contribution : Double
  confidence : Double
  band : RiskScoreBand
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RiskScoreWindow {
  start_date : String
  end_date : String
  profiles : Array[RiskScoreProfile]
  average : Double
  minimum : Double
  maximum : Double
  standard_deviation : Double
  trend : LoadTrend
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RiskScoreComparison {
  left_average : Double
  right_average : Double
  change : Double
  change_percent : Double
  dominant_left : String
  dominant_right : String
  direction : TrendDirection
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RiskScoreDistribution {
  low_count : Int
  watch_count : Int
  action_count : Int
  escalate_count : Int
  total_count : Int
  low_percent : Double
  watch_percent : Double
  action_percent : Double
  escalate_percent : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RiskScorePolicy {
  watch_floor : Double
  action_floor : Double
  escalate_floor : Double
  risk_weight : Double
  readiness_weight : Double
  load_weight : Double
  recovery_weight : Double
  quality_weight : Double
} derive(Debug, Eq, ToJson)

///|
pub fn default_risk_score_policy() -> RiskScorePolicy {
  {
    watch_floor: 25.0,
    action_floor: 50.0,
    escalate_floor: 75.0,
    risk_weight: 0.35,
    readiness_weight: 0.20,
    load_weight: 0.20,
    recovery_weight: 0.15,
    quality_weight: 0.10,
  }
}

///|
fn risk_score_clamp(value : Double) -> Double {
  value.max(0.0).min(100.0)
}

///|
pub fn risk_score_band(
  value : Double,
  policy : RiskScorePolicy,
) -> RiskScoreBand {
  if value >= policy.escalate_floor {
    ScoreEscalate
  } else if value >= policy.action_floor {
    ScoreAction
  } else if value >= policy.watch_floor {
    ScoreWatch
  } else {
    ScoreLow
  }
}

///|
pub fn risk_score_band_name(band : RiskScoreBand) -> String {
  match band {
    ScoreLow => "low"
    ScoreWatch => "watch"
    ScoreAction => "action"
    ScoreEscalate => "escalate"
  }
}

///|
pub fn risk_score_band_rank(band : RiskScoreBand) -> Int {
  match band {
    ScoreLow => 0
    ScoreWatch => 1
    ScoreAction => 2
    ScoreEscalate => 3
  }
}

///|
fn score_component(
  name : String,
  value : Double,
  weight : Double,
  evidence : String,
  policy : RiskScorePolicy,
) -> RiskScoreComponent {
  let safe_value = risk_score_clamp(value)
  let safe_weight = weight.max(0.0)
  {
    name,
    value: safe_value,
    weight: safe_weight,
    contribution: safe_value * safe_weight,
    band: risk_score_band(safe_value, policy),
    evidence,
  }
}

///|
fn score_component_total(components : Array[RiskScoreComponent]) -> Double {
  components.fold(init=0.0, (total, item) => total + item.contribution)
}

///|
fn score_component_weight(components : Array[RiskScoreComponent]) -> Double {
  components.fold(init=0.0, (total, item) => total + item.weight)
}

///|
fn score_component_normalized_total(
  components : Array[RiskScoreComponent],
) -> Double {
  let weight = score_component_weight(components)
  if weight == 0.0 {
    0.0
  } else {
    risk_score_clamp(score_component_total(components) / weight)
  }
}

///|
fn score_dominant_component(
  components : Array[RiskScoreComponent],
) -> Array[String] {
  if components.length() == 0 {
    ["none", "0.0"]
  } else {
    let mut name = components[0].name
    let mut contribution = components[0].contribution
    for item in components {
      if item.contribution > contribution {
        name = item.name
        contribution = item.contribution
      }
    }
    [name, contribution.to_string()]
  }
}

///|
fn score_dominant_contribution(
  components : Array[RiskScoreComponent],
) -> Double {
  if components.length() == 0 {
    0.0
  } else {
    let mut contribution = 0.0
    for item in components {
      contribution = contribution.max(item.contribution)
    }
    contribution
  }
}

///|
fn score_confidence(assessment : ComprehensiveAssessment) -> Double {
  let quality = assessment.quality.score / 100.0
  let signal_quality = if assessment.signals.signal_count == 0 {
    0.5
  } else {
    1.0
  }
  (quality * 0.7 + signal_quality * 0.3).max(0.0).min(1.0)
}

///|
fn score_recommendation(band : RiskScoreBand, dominant : String) -> String {
  match band {
    ScoreLow => "continue planned training and monitor " + dominant
    ScoreWatch => "review " + dominant + " before the next load increase"
    ScoreAction =>
      "reduce exposure and create a follow-up review for " + dominant
    ScoreEscalate =>
      "pause progression and escalate the " + dominant + " signal"
  }
}

///|
pub fn risk_score_profile(
  assessment : ComprehensiveAssessment,
  policy : RiskScorePolicy,
) -> RiskScoreProfile {
  let components = [
    score_component(
      "composite_risk",
      assessment.risk_score,
      policy.risk_weight,
      assessment.summary,
      policy,
    ),
    score_component(
      "readiness_gap",
      100.0 - assessment.readiness_score,
      policy.readiness_weight,
      "inverse readiness score",
      policy,
    ),
    score_component(
      "load_ratio",
      (assessment.load.acwr - 0.8) * 100.0,
      policy.load_weight,
      "acute to chronic workload ratio",
      policy,
    ),
    score_component(
      "recovery_gap",
      100.0 - assessment.recovery.recovery_score,
      policy.recovery_weight,
      "inverse recovery score",
      policy,
    ),
    score_component(
      "quality_gap",
      100.0 - assessment.quality.score,
      policy.quality_weight,
      "inverse quality score",
      policy,
    ),
  ]
  let dominant = score_dominant_component(components)
  let total = score_component_normalized_total(components)
  let band = risk_score_band(total, policy)
  {
    date: assessment.date,
    components,
    total,
    dominant_component: dominant[0],
    dominant_contribution: score_dominant_contribution(components),
    confidence: score_confidence(assessment),
    band,
    recommendation: score_recommendation(band, dominant[0]),
  }
}

///|
pub fn risk_score_profile_for_date(
  records : Array[DailyRecord],
  date : String,
  risk_policy : RiskPolicy,
  score_policy : RiskScorePolicy,
) -> RiskScoreProfile? {
  match assess_comprehensive(records, date, risk_policy) {
    Some(assessment) => Some(risk_score_profile(assessment, score_policy))
    None => None
  }
}

///|
pub fn risk_score_profiles(
  records : Array[DailyRecord],
  risk_policy : RiskPolicy,
  score_policy : RiskScorePolicy,
) -> Array[RiskScoreProfile] {
  let profiles = []
  for record in sort_records_by_date(records) {
    match
      risk_score_profile_for_date(
        records,
        record.date,
        risk_policy,
        score_policy,
      ) {
      Some(profile) => profiles.push(profile)
      None => ()
    }
  }
  profiles
}

///|
fn score_profile_values(profiles : Array[RiskScoreProfile]) -> Array[Double] {
  profiles.map(profile => profile.total)
}

///|
pub fn risk_score_profile_by_date(
  profiles : Array[RiskScoreProfile],
  date : String,
) -> RiskScoreProfile? {
  for profile in profiles {
    if profile.date == date {
      return Some(profile)
    }
  }
  None
}

///|
pub fn risk_score_profiles_by_band(
  profiles : Array[RiskScoreProfile],
  band : RiskScoreBand,
) -> Array[RiskScoreProfile] {
  profiles.filter(profile => profile.band == band)
}

///|
pub fn risk_score_profiles_needing_action(
  profiles : Array[RiskScoreProfile],
) -> Array[RiskScoreProfile] {
  profiles.filter(profile => {
    risk_score_band_rank(profile.band) >= risk_score_band_rank(ScoreAction)
  })
}

///|
pub fn risk_score_average(profiles : Array[RiskScoreProfile]) -> Double {
  mean_load_values(score_profile_values(profiles))
}

///|
pub fn risk_score_minimum(profiles : Array[RiskScoreProfile]) -> Double {
  minimum_load_values(score_profile_values(profiles))
}

///|
pub fn risk_score_maximum(profiles : Array[RiskScoreProfile]) -> Double {
  maximum_load_values(score_profile_values(profiles))
}

///|
pub fn risk_score_standard_deviation(
  profiles : Array[RiskScoreProfile],
) -> Double {
  standard_deviation_values(score_profile_values(profiles))
}

///|
pub fn risk_score_range(profiles : Array[RiskScoreProfile]) -> Double {
  risk_score_maximum(profiles) - risk_score_minimum(profiles)
}

///|
fn score_window_status_value(
  average : Double,
  deviation : Double,
  policy : RiskScorePolicy,
) -> String {
  if average >= policy.escalate_floor || deviation >= 25.0 {
    "escalate"
  } else if average >= policy.action_floor || deviation >= 15.0 {
    "action"
  } else if average >= policy.watch_floor || deviation >= 8.0 {
    "watch"
  } else {
    "stable"
  }
}

///|
pub fn risk_score_window(
  profiles : Array[RiskScoreProfile],
  policy : RiskScorePolicy,
) -> RiskScoreWindow {
  let average = risk_score_average(profiles)
  let deviation = risk_score_standard_deviation(profiles)
  let start_date = if profiles.length() == 0 { "" } else { profiles[0].date }
  let end_date = if profiles.length() == 0 {
    ""
  } else {
    profiles[profiles.length() - 1].date
  }
  {
    start_date,
    end_date,
    profiles,
    average,
    minimum: risk_score_minimum(profiles),
    maximum: risk_score_maximum(profiles),
    standard_deviation: deviation,
    trend: load_trend(score_profile_values(profiles), 0.1),
    status: score_window_status_value(average, deviation, policy),
  }
}

///|
pub fn risk_score_window_for_records(
  records : Array[DailyRecord],
  risk_policy : RiskPolicy,
  score_policy : RiskScorePolicy,
) -> RiskScoreWindow {
  risk_score_window(
    risk_score_profiles(records, risk_policy, score_policy),
    score_policy,
  )
}

///|
pub fn risk_score_distribution(
  profiles : Array[RiskScoreProfile],
) -> RiskScoreDistribution {
  let low = profiles.filter(profile => profile.band == ScoreLow).length()
  let watch = profiles.filter(profile => profile.band == ScoreWatch).length()
  let action = profiles.filter(profile => profile.band == ScoreAction).length()
  let escalate = profiles
    .filter(profile => profile.band == ScoreEscalate)
    .length()
  let total = profiles.length()
  let ratio = if total == 0 { 0.0 } else { 100.0 / total.to_double() }
  {
    low_count: low,
    watch_count: watch,
    action_count: action,
    escalate_count: escalate,
    total_count: total,
    low_percent: low.to_double() * ratio,
    watch_percent: watch.to_double() * ratio,
    action_percent: action.to_double() * ratio,
    escalate_percent: escalate.to_double() * ratio,
  }
}

///|
pub fn risk_score_distribution_for_records(
  records : Array[DailyRecord],
  risk_policy : RiskPolicy,
  score_policy : RiskScorePolicy,
) -> RiskScoreDistribution {
  risk_score_distribution(
    risk_score_profiles(records, risk_policy, score_policy),
  )
}

///|
pub fn risk_score_compare(
  left : RiskScoreWindow,
  right : RiskScoreWindow,
) -> RiskScoreComparison {
  let change = right.average - left.average
  let direction = if change < -2.0 {
    Improving
  } else if change > 2.0 {
    Worsening
  } else {
    Stable
  }
  {
    left_average: left.average,
    right_average: right.average,
    change,
    change_percent: percentage_change(left.average, right.average),
    dominant_left: if left.profiles.length() == 0 {
      "none"
    } else {
      left.profiles[left.profiles.length() - 1].dominant_component
    },
    dominant_right: if right.profiles.length() == 0 {
      "none"
    } else {
      right.profiles[right.profiles.length() - 1].dominant_component
    },
    direction,
    conclusion: if change < -2.0 {
      "risk burden decreased"
    } else if change > 2.0 {
      "risk burden increased"
    } else {
      "risk burden is stable"
    },
  }
}

///|
pub fn risk_score_component(
  profile : RiskScoreProfile,
  name : String,
) -> RiskScoreComponent? {
  for component in profile.components {
    if component.name == name {
      return Some(component)
    }
  }
  None
}

///|
pub fn risk_score_component_names(profile : RiskScoreProfile) -> Array[String] {
  profile.components.map(component => component.name)
}

///|
pub fn risk_score_component_values(profile : RiskScoreProfile) -> Array[Double] {
  profile.components.map(component => component.value)
}

///|
pub fn risk_score_component_contributions(
  profile : RiskScoreProfile,
) -> Array[Double] {
  profile.components.map(component => component.contribution)
}

///|
pub fn risk_score_component_total(profile : RiskScoreProfile) -> Double {
  profile.components.fold(init=0.0, (total, item) => total + item.contribution)
}

///|
pub fn risk_score_component_count(profile : RiskScoreProfile) -> Int {
  profile.components.length()
}

///|
pub fn risk_score_profile_actionable(profile : RiskScoreProfile) -> Bool {
  risk_score_band_rank(profile.band) >= risk_score_band_rank(ScoreAction)
}

///|
pub fn risk_score_profile_credible(profile : RiskScoreProfile) -> Bool {
  profile.confidence >= 0.7 && profile.components.length() >= 3
}

///|
pub fn risk_score_profile_valid(profile : RiskScoreProfile) -> Bool {
  profile.date != "" &&
  profile.total >= 0.0 &&
  profile.total <= 100.0 &&
  profile.confidence >= 0.0 &&
  profile.confidence <= 1.0 &&
  profile.components.all(component => {
    component.value >= 0.0 &&
    component.value <= 100.0 &&
    component.weight >= 0.0
  })
}

///|
pub fn risk_score_window_valid(window : RiskScoreWindow) -> Bool {
  window.average >= 0.0 &&
  window.maximum >= window.minimum &&
  window.standard_deviation >= 0.0 &&
  window.profiles.all(profile => risk_score_profile_valid(profile))
}

///|
pub fn risk_score_distribution_valid(
  distribution : RiskScoreDistribution,
) -> Bool {
  distribution.total_count >= 0 &&
  distribution.low_count +
  distribution.watch_count +
  distribution.action_count +
  distribution.escalate_count ==
  distribution.total_count &&
  distribution.low_percent >= 0.0 &&
  distribution.escalate_percent <= 100.0
}

///|
pub fn risk_score_policy_valid(policy : RiskScorePolicy) -> Bool {
  policy.watch_floor >= 0.0 &&
  policy.watch_floor <= policy.action_floor &&
  policy.action_floor <= policy.escalate_floor &&
  policy.escalate_floor <= 100.0 &&
  policy.risk_weight >= 0.0 &&
  policy.readiness_weight >= 0.0 &&
  policy.load_weight >= 0.0 &&
  policy.recovery_weight >= 0.0 &&
  policy.quality_weight >= 0.0
}

///|
pub fn risk_score_policy_weight_total(policy : RiskScorePolicy) -> Double {
  policy.risk_weight +
  policy.readiness_weight +
  policy.load_weight +
  policy.recovery_weight +
  policy.quality_weight
}

///|
pub fn risk_score_policy_normalized(
  policy : RiskScorePolicy,
) -> RiskScorePolicy {
  let total = risk_score_policy_weight_total(policy)
  if total == 0.0 {
    default_risk_score_policy()
  } else {
    {
      watch_floor: policy.watch_floor,
      action_floor: policy.action_floor,
      escalate_floor: policy.escalate_floor,
      risk_weight: policy.risk_weight / total,
      readiness_weight: policy.readiness_weight / total,
      load_weight: policy.load_weight / total,
      recovery_weight: policy.recovery_weight / total,
      quality_weight: policy.quality_weight / total,
    }
  }
}

///|
pub fn risk_score_text(profile : RiskScoreProfile) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "date=" +
    profile.date +
    " total=" +
    profile.total.to_string() +
    " band=" +
    risk_score_band_name(profile.band),
  )
  builder.write_string(
    " dominant=" +
    profile.dominant_component +
    " confidence=" +
    profile.confidence.to_string(),
  )
  builder.write_string(" recommendation=" + profile.recommendation)
  for component in profile.components {
    builder.write_string(
      "\n" +
      component.name +
      " value=" +
      component.value.to_string() +
      " contribution=" +
      component.contribution.to_string() +
      " evidence=" +
      component.evidence,
    )
  }
  builder.to_string()
}

///|
pub fn risk_score_window_text(window : RiskScoreWindow) -> String {
  "window=" +
  window.start_date +
  ".." +
  window.end_date +
  " count=" +
  window.profiles.length().to_string() +
  " average=" +
  window.average.to_string() +
  " minimum=" +
  window.minimum.to_string() +
  " maximum=" +
  window.maximum.to_string() +
  " deviation=" +
  window.standard_deviation.to_string() +
  " status=" +
  window.status
}

///|
pub fn risk_score_comparison_text(comparison : RiskScoreComparison) -> String {
  "left=" +
  comparison.left_average.to_string() +
  " right=" +
  comparison.right_average.to_string() +
  " change=" +
  comparison.change.to_string() +
  " change_percent=" +
  comparison.change_percent.to_string() +
  " direction=" +
  comparison.conclusion
}

///|
pub fn risk_score_distribution_text(
  distribution : RiskScoreDistribution,
) -> String {
  "total=" +
  distribution.total_count.to_string() +
  " low=" +
  distribution.low_percent.to_string() +
  "% watch=" +
  distribution.watch_percent.to_string() +
  "% action=" +
  distribution.action_percent.to_string() +
  "% escalate=" +
  distribution.escalate_percent.to_string() +
  "%"
}

///|
pub fn risk_score_csv_header() -> String {
  "date,total,band,dominant_component,dominant_contribution,confidence,recommendation"
}

///|
pub fn risk_score_csv(profile : RiskScoreProfile) -> String {
  profile.date +
  "," +
  profile.total.to_string() +
  "," +
  risk_score_band_name(profile.band) +
  "," +
  profile.dominant_component +
  "," +
  profile.dominant_contribution.to_string() +
  "," +
  profile.confidence.to_string() +
  "," +
  profile.recommendation
}

///|
pub fn risk_score_window_csv(window : RiskScoreWindow) -> String {
  let builder = StringBuilder::new()
  builder.write_string(risk_score_csv_header())
  for profile in window.profiles {
    builder.write_string("\n" + risk_score_csv(profile))
  }
  builder.to_string()
}

///|
pub fn risk_score_distribution_csv_header() -> String {
  "low_count,watch_count,action_count,escalate_count,total_count,low_percent,watch_percent,action_percent,escalate_percent"
}

///|
pub fn risk_score_distribution_csv(
  distribution : RiskScoreDistribution,
) -> String {
  distribution.low_count.to_string() +
  "," +
  distribution.watch_count.to_string() +
  "," +
  distribution.action_count.to_string() +
  "," +
  distribution.escalate_count.to_string() +
  "," +
  distribution.total_count.to_string() +
  "," +
  distribution.low_percent.to_string() +
  "," +
  distribution.watch_percent.to_string() +
  "," +
  distribution.action_percent.to_string() +
  "," +
  distribution.escalate_percent.to_string()
}

///|
pub fn risk_score_band_names() -> Array[String] {
  [
    risk_score_band_name(ScoreLow),
    risk_score_band_name(ScoreWatch),
    risk_score_band_name(ScoreAction),
    risk_score_band_name(ScoreEscalate),
  ]
}

///|
pub fn risk_score_action_threshold(policy : RiskScorePolicy) -> Double {
  policy.action_floor
}

///|
pub fn risk_score_escalation_threshold(policy : RiskScorePolicy) -> Double {
  policy.escalate_floor
}

///|
pub fn risk_score_watch_threshold(policy : RiskScorePolicy) -> Double {
  policy.watch_floor
}

///|
pub fn risk_score_bands_at_or_above(
  profiles : Array[RiskScoreProfile],
  band : RiskScoreBand,
) -> Int {
  profiles
  .filter(profile => {
    risk_score_band_rank(profile.band) >= risk_score_band_rank(band)
  })
  .length()
}

///|
pub fn risk_score_highest_profile(
  profiles : Array[RiskScoreProfile],
) -> RiskScoreProfile? {
  if profiles.length() == 0 {
    None
  } else {
    let mut result = profiles[0]
    for profile in profiles {
      if profile.total > result.total {
        result = profile
      }
    }
    Some(result)
  }
}

///|
pub fn risk_score_latest_profile(
  profiles : Array[RiskScoreProfile],
) -> RiskScoreProfile? {
  if profiles.length() == 0 {
    None
  } else {
    Some(profiles[profiles.length() - 1])
  }
}

///|
pub fn risk_score_first_profile(
  profiles : Array[RiskScoreProfile],
) -> RiskScoreProfile? {
  if profiles.length() == 0 {
    None
  } else {
    Some(profiles[0])
  }
}

///|
pub fn risk_score_latest_band(
  profiles : Array[RiskScoreProfile],
) -> RiskScoreBand? {
  match risk_score_latest_profile(profiles) {
    Some(profile) => Some(profile.band)
    None => None
  }
}

///|
pub fn risk_score_latest_action(profiles : Array[RiskScoreProfile]) -> String {
  match risk_score_latest_profile(profiles) {
    Some(profile) => profile.recommendation
    None => "no score is available"
  }
}

///|
pub fn risk_score_improving(profiles : Array[RiskScoreProfile]) -> Bool {
  if profiles.length() < 2 {
    false
  } else {
    profiles[profiles.length() - 1].total < profiles[0].total
  }
}

///|
pub fn risk_score_worsening(profiles : Array[RiskScoreProfile]) -> Bool {
  if profiles.length() < 2 {
    false
  } else {
    profiles[profiles.length() - 1].total > profiles[0].total
  }
}

///|
pub fn risk_score_stable(profiles : Array[RiskScoreProfile]) -> Bool {
  !risk_score_improving(profiles) && !risk_score_worsening(profiles)
}

///|
pub fn risk_score_alert_count(profiles : Array[RiskScoreProfile]) -> Int {
  profiles.filter(profile => risk_score_profile_actionable(profile)).length()
}

///|
pub fn risk_score_confidence_average(
  profiles : Array[RiskScoreProfile],
) -> Double {
  mean_load_values(profiles.map(profile => profile.confidence * 100.0))
}

///|
pub fn risk_score_dominant_components(
  profiles : Array[RiskScoreProfile],
) -> Array[String] {
  profiles.map(profile => profile.dominant_component)
}

///|
pub fn risk_score_component_frequency(
  profiles : Array[RiskScoreProfile],
  name : String,
) -> Int {
  profiles.filter(profile => profile.dominant_component == name).length()
}

///|
pub fn risk_score_component_share(
  profiles : Array[RiskScoreProfile],
  name : String,
) -> Double {
  if profiles.length() == 0 {
    0.0
  } else {
    risk_score_component_frequency(profiles, name).to_double() /
    profiles.length().to_double() *
    100.0
  }
}

///|
pub fn risk_score_window_status(window : RiskScoreWindow) -> String {
  window.status
}

///|
pub fn risk_score_window_trend(window : RiskScoreWindow) -> LoadTrend {
  window.trend
}

///|
pub fn risk_score_window_dates(window : RiskScoreWindow) -> Array[String] {
  window.profiles.map(profile => profile.date)
}

///|
pub fn risk_score_window_totals(window : RiskScoreWindow) -> Array[Double] {
  window.profiles.map(profile => profile.total)
}

///|
pub fn risk_score_window_actionable_dates(
  window : RiskScoreWindow,
) -> Array[String] {
  window.profiles
  .filter(profile => risk_score_profile_actionable(profile))
  .map(profile => profile.date)
}

///|
pub fn risk_score_window_profile_count(window : RiskScoreWindow) -> Int {
  window.profiles.length()
}

///|
pub fn risk_score_window_confidence(window : RiskScoreWindow) -> Double {
  risk_score_confidence_average(window.profiles)
}

///|
pub fn risk_score_window_requires_review(window : RiskScoreWindow) -> Bool {
  window.status == "action" ||
  window.status == "escalate" ||
  window.profiles.any(profile => !risk_score_profile_credible(profile))
}

///|
pub fn risk_score_window_recommendation(window : RiskScoreWindow) -> String {
  if window.status == "escalate" {
    "escalate the window for review"
  } else if window.status == "action" {
    "apply the action plan and repeat monitoring"
  } else if window.status == "watch" {
    "keep the next review close"
  } else {
    "continue the planned monitoring cadence"
  }
}

///|
pub fn risk_score_window_metric(
  window : RiskScoreWindow,
  name : String,
) -> Double {
  match name {
    "average" => window.average
    "minimum" => window.minimum
    "maximum" => window.maximum
    "standard_deviation" => window.standard_deviation
    "confidence" => risk_score_window_confidence(window)
    "count" => window.profiles.length().to_double()
    _ => 0.0
  }
}

///|
pub fn risk_score_profile_metric(
  profile : RiskScoreProfile,
  name : String,
) -> Double {
  match name {
    "total" => profile.total
    "confidence" => profile.confidence * 100.0
    "dominant_contribution" => profile.dominant_contribution
    "components" => profile.components.length().to_double()
    _ =>
      match risk_score_component(profile, name) {
        Some(component) => component.value
        None => 0.0
      }
  }
}

///|
pub fn risk_score_metric_names() -> Array[String] {
  [
    "total", "confidence", "dominant_contribution", "components", "composite_risk",
    "readiness_gap", "load_ratio", "recovery_gap", "quality_gap",
  ]
}

///|
pub fn risk_score_component_evidence(
  profile : RiskScoreProfile,
  name : String,
) -> String {
  match risk_score_component(profile, name) {
    Some(component) => component.evidence
    None => ""
  }
}

///|
pub fn risk_score_component_band(
  profile : RiskScoreProfile,
  name : String,
) -> RiskScoreBand? {
  match risk_score_component(profile, name) {
    Some(component) => Some(component.band)
    None => None
  }
}

///|
pub fn risk_score_component_is_actionable(
  profile : RiskScoreProfile,
  name : String,
) -> Bool {
  match risk_score_component_band(profile, name) {
    Some(band) =>
      risk_score_band_rank(band) >= risk_score_band_rank(ScoreAction)
    None => false
  }
}

///|
pub fn risk_score_component_valid(component : RiskScoreComponent) -> Bool {
  component.name != "" &&
  component.value >= 0.0 &&
  component.value <= 100.0 &&
  component.weight >= 0.0 &&
  component.contribution >= 0.0 &&
  component.evidence != ""
}

///|
pub fn risk_score_components_valid(profile : RiskScoreProfile) -> Bool {
  profile.components.all(component => risk_score_component_valid(component))
}

///|
pub fn risk_score_recommendation(profile : RiskScoreProfile) -> String {
  profile.recommendation
}

///|
pub fn risk_score_status(profile : RiskScoreProfile) -> String {
  risk_score_band_name(profile.band)
}

///|
pub fn risk_score_profile_checksum(profile : RiskScoreProfile) -> String {
  let mut value = profile.date.length() + profile.components.length()
  for character in risk_score_csv(profile) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn risk_score_window_checksum(window : RiskScoreWindow) -> String {
  let mut value = window.start_date.length() + window.end_date.length()
  for character in risk_score_window_csv(window) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn risk_score_profile_reproducible(
  left : RiskScoreProfile,
  right : RiskScoreProfile,
) -> Bool {
  risk_score_profile_checksum(left) == risk_score_profile_checksum(right)
}

///|
pub fn risk_score_window_reproducible(
  left : RiskScoreWindow,
  right : RiskScoreWindow,
) -> Bool {
  risk_score_window_checksum(left) == risk_score_window_checksum(right)
}

///|
pub fn risk_score_profile_projection(
  profile : RiskScoreProfile,
  names : Array[String],
) -> Array[Double] {
  names.map(name => risk_score_profile_metric(profile, name))
}

///|
pub fn risk_score_window_projection(
  window : RiskScoreWindow,
  name : String,
) -> Array[Double] {
  window.profiles.map(profile => risk_score_profile_metric(profile, name))
}

///|
pub fn risk_score_threshold_crossings(
  profiles : Array[RiskScoreProfile],
  threshold : Double,
) -> Int {
  let mut count = 0
  for index in 1..<profiles.length() {
    if (
        profiles[index - 1].total < threshold &&
        profiles[index].total >= threshold
      ) ||
      (
        profiles[index - 1].total >= threshold &&
        profiles[index].total < threshold
      ) {
      count += 1
    }
  }
  count
}

///|
pub fn risk_score_consecutive_action_days(
  profiles : Array[RiskScoreProfile],
) -> Int {
  let mut current = 0
  let mut longest = 0
  for profile in profiles {
    if risk_score_profile_actionable(profile) {
      current += 1
      longest = longest.max(current)
    } else {
      current = 0
    }
  }
  longest
}

///|
pub fn risk_score_consecutive_escalation_days(
  profiles : Array[RiskScoreProfile],
) -> Int {
  let mut current = 0
  let mut longest = 0
  for profile in profiles {
    if profile.band == ScoreEscalate {
      current += 1
      longest = longest.max(current)
    } else {
      current = 0
    }
  }
  longest
}

///|
pub fn risk_score_recent_average(
  profiles : Array[RiskScoreProfile],
  count : Int,
) -> Double {
  if count <= 0 {
    0.0
  } else {
    let start = (profiles.length() - count).max(0)
    let values = []
    for index in start..<profiles.length() {
      values.push(profiles[index].total)
    }
    mean_load_values(values)
  }
}

///|
pub fn risk_score_recent_band(
  profiles : Array[RiskScoreProfile],
  count : Int,
  policy : RiskScorePolicy,
) -> RiskScoreBand {
  risk_score_band(risk_score_recent_average(profiles, count), policy)
}

///|
pub fn risk_score_trend_label(trend : LoadTrend) -> String {
  match trend {
    Rising => "rising"
    Stable => "stable"
    Falling => "falling"
    Volatile => "volatile"
    InsufficientData => "insufficient_data"
  }
}

///|
pub fn risk_score_window_summary(window : RiskScoreWindow) -> Array[String] {
  [
    window.start_date,
    window.end_date,
    window.profiles.length().to_string(),
    window.average.to_string(),
    window.minimum.to_string(),
    window.maximum.to_string(),
    risk_score_trend_label(window.trend),
    window.status,
  ]
}

///|
pub fn risk_score_summary_header() -> Array[String] {
  [
    "start_date", "end_date", "count", "average", "minimum", "maximum", "trend",
    "status",
  ]
}

///|
pub fn risk_score_summary_csv(window : RiskScoreWindow) -> String {
  risk_score_summary_header().join(",") +
  "\n" +
  risk_score_window_summary(window).join(",")
}

///|
pub fn risk_score_scorecard(window : RiskScoreWindow) -> Array[String] {
  [
    "risk_average=" + window.average.to_string(),
    "risk_range=" + risk_score_range(window.profiles).to_string(),
    "action_days=" +
    risk_score_consecutive_action_days(window.profiles).to_string(),
    "escalation_days=" +
    risk_score_consecutive_escalation_days(window.profiles).to_string(),
    "review=" + risk_score_window_requires_review(window).to_string(),
  ]
}

///|
pub fn risk_score_profile_count_by_name(
  profiles : Array[RiskScoreProfile],
  name : String,
) -> Int {
  profiles.filter(profile => profile.dominant_component == name).length()
}

///|
pub fn risk_score_profile_count_at_or_above(
  profiles : Array[RiskScoreProfile],
  floor : Double,
) -> Int {
  profiles.filter(profile => profile.total >= floor).length()
}

///|
pub fn risk_score_profile_percent_at_or_above(
  profiles : Array[RiskScoreProfile],
  floor : Double,
) -> Double {
  if profiles.length() == 0 {
    0.0
  } else {
    risk_score_profile_count_at_or_above(profiles, floor).to_double() /
    profiles.length().to_double() *
    100.0
  }
}

///|
pub fn risk_score_profile_score_delta(
  left : RiskScoreProfile,
  right : RiskScoreProfile,
) -> Double {
  right.total - left.total
}

///|
pub fn risk_score_profile_band_changed(
  left : RiskScoreProfile,
  right : RiskScoreProfile,
) -> Bool {
  left.band != right.band
}

///|
pub fn risk_score_profile_confidence_delta(
  left : RiskScoreProfile,
  right : RiskScoreProfile,
) -> Double {
  right.confidence - left.confidence
}

///|
pub fn risk_score_profile_dominant_changed(
  left : RiskScoreProfile,
  right : RiskScoreProfile,
) -> Bool {
  left.dominant_component != right.dominant_component
}

///|
pub fn risk_score_profile_has_component(
  profile : RiskScoreProfile,
  name : String,
) -> Bool {
  risk_score_component(profile, name) is Some(_)
}

///|
pub fn risk_score_profile_component_average(
  profiles : Array[RiskScoreProfile],
  name : String,
) -> Double {
  mean_load_values(
    profiles.map(profile => risk_score_profile_metric(profile, name)),
  )
}

///|
pub fn risk_score_profile_component_maximum(
  profiles : Array[RiskScoreProfile],
  name : String,
) -> Double {
  maximum_load_values(
    profiles.map(profile => risk_score_profile_metric(profile, name)),
  )
}

///|
pub fn risk_score_profile_component_minimum(
  profiles : Array[RiskScoreProfile],
  name : String,
) -> Double {
  minimum_load_values(
    profiles.map(profile => risk_score_profile_metric(profile, name)),
  )
}

///|
pub fn risk_score_profile_component_range(
  profiles : Array[RiskScoreProfile],
  name : String,
) -> Double {
  risk_score_profile_component_maximum(profiles, name) -
  risk_score_profile_component_minimum(profiles, name)
}

///|
pub fn risk_score_window_component_average(
  window : RiskScoreWindow,
  name : String,
) -> Double {
  risk_score_profile_component_average(window.profiles, name)
}

///|
pub fn risk_score_window_component_maximum(
  window : RiskScoreWindow,
  name : String,
) -> Double {
  risk_score_profile_component_maximum(window.profiles, name)
}

///|
pub fn risk_score_window_component_minimum(
  window : RiskScoreWindow,
  name : String,
) -> Double {
  risk_score_profile_component_minimum(window.profiles, name)
}

///|
pub fn risk_score_window_component_range(
  window : RiskScoreWindow,
  name : String,
) -> Double {
  risk_score_profile_component_range(window.profiles, name)
}

///|
pub fn risk_score_window_crossings(
  window : RiskScoreWindow,
  threshold : Double,
) -> Int {
  risk_score_threshold_crossings(window.profiles, threshold)
}

///|
pub fn risk_score_window_action_days(window : RiskScoreWindow) -> Int {
  window.profiles
  .filter(profile => risk_score_profile_actionable(profile))
  .length()
}

///|
pub fn risk_score_window_escalation_days(window : RiskScoreWindow) -> Int {
  window.profiles.filter(profile => profile.band == ScoreEscalate).length()
}

///|
pub fn risk_score_window_low_days(window : RiskScoreWindow) -> Int {
  window.profiles.filter(profile => profile.band == ScoreLow).length()
}

///|
pub fn risk_score_window_watch_days(window : RiskScoreWindow) -> Int {
  window.profiles.filter(profile => profile.band == ScoreWatch).length()
}

///|
pub fn risk_score_window_distribution(
  window : RiskScoreWindow,
) -> RiskScoreDistribution {
  risk_score_distribution(window.profiles)
}

///|
pub fn risk_score_window_has_escalation(window : RiskScoreWindow) -> Bool {
  window.profiles.any(profile => profile.band == ScoreEscalate)
}

///|
pub fn risk_score_window_has_data(window : RiskScoreWindow) -> Bool {
  window.profiles.length() > 0
}

///|
pub fn risk_score_window_empty(window : RiskScoreWindow) -> Bool {
  window.profiles.length() == 0
}

///|
pub fn risk_score_window_quality(window : RiskScoreWindow) -> String {
  if window.profiles.length() < 3 {
    "limited"
  } else if risk_score_window_confidence(window) < 70.0 {
    "review"
  } else {
    "usable"
  }
}

///|
pub fn risk_score_profile_quality(profile : RiskScoreProfile) -> String {
  if !risk_score_profile_valid(profile) {
    "invalid"
  } else if !risk_score_profile_credible(profile) {
    "limited"
  } else {
    "usable"
  }
}

///|
pub fn risk_score_profile_action(profile : RiskScoreProfile) -> String {
  if risk_score_profile_actionable(profile) {
    profile.recommendation
  } else {
    "no immediate action"
  }
}

///|
pub fn risk_score_policy_status(policy : RiskScorePolicy) -> String {
  if risk_score_policy_valid(policy) &&
    (risk_score_policy_weight_total(policy) - 1.0).abs() < 0.01 {
    "valid"
  } else if risk_score_policy_valid(policy) {
    "valid_unscaled"
  } else {
    "invalid"
  }
}

///|
pub fn risk_score_policy_text(policy : RiskScorePolicy) -> String {
  "watch=" +
  policy.watch_floor.to_string() +
  " action=" +
  policy.action_floor.to_string() +
  " escalate=" +
  policy.escalate_floor.to_string() +
  " weights=" +
  risk_score_policy_weight_total(policy).to_string() +
  " status=" +
  risk_score_policy_status(policy)
}

///|
pub fn risk_score_window_policy_text(
  window : RiskScoreWindow,
  policy : RiskScorePolicy,
) -> String {
  risk_score_window_text(window) +
  " thresholds=" +
  risk_score_policy_text(policy)
}

///|
pub fn risk_score_component_sort_key(component : RiskScoreComponent) -> Double {
  component.contribution
}

///|
pub fn risk_score_profile_sort_key(profile : RiskScoreProfile) -> Double {
  profile.total
}

///|
pub fn risk_score_component_names_csv(profile : RiskScoreProfile) -> String {
  profile.components.map(component => component.name).join(",")
}

///|
pub fn risk_score_component_values_csv(profile : RiskScoreProfile) -> String {
  profile.components.map(component => component.value.to_string()).join(",")
}

///|
pub fn risk_score_profile_to_json_line(profile : RiskScoreProfile) -> String {
  risk_score_csv(profile)
}

///|
pub fn risk_score_window_to_json_lines(
  window : RiskScoreWindow,
) -> Array[String] {
  window.profiles.map(profile => risk_score_profile_to_json_line(profile))
}

///|
pub fn risk_score_component_to_text(component : RiskScoreComponent) -> String {
  component.name +
  "=" +
  component.value.to_string() +
  " contribution=" +
  component.contribution.to_string() +
  " band=" +
  risk_score_band_name(component.band)
}

///|
pub fn risk_score_components_text(profile : RiskScoreProfile) -> String {
  profile.components
  .map(component => risk_score_component_to_text(component))
  .join("; ")
}

///|
pub fn risk_score_window_components_text(window : RiskScoreWindow) -> String {
  window.profiles.map(profile => risk_score_components_text(profile)).join("\n")
}

///|
pub fn risk_score_profile_note(profile : RiskScoreProfile) -> String {
  profile.date +
  ": " +
  risk_score_profile_quality(profile) +
  ", " +
  profile.recommendation
}

///|
pub fn risk_score_window_notes(window : RiskScoreWindow) -> Array[String] {
  window.profiles.map(profile => risk_score_profile_note(profile))
}

///|
pub fn risk_score_profile_is_low(profile : RiskScoreProfile) -> Bool {
  profile.band == ScoreLow
}

///|
pub fn risk_score_profile_is_watch(profile : RiskScoreProfile) -> Bool {
  profile.band == ScoreWatch
}

///|
pub fn risk_score_profile_is_action(profile : RiskScoreProfile) -> Bool {
  profile.band == ScoreAction
}

///|
pub fn risk_score_profile_is_escalate(profile : RiskScoreProfile) -> Bool {
  profile.band == ScoreEscalate
}

///|
pub fn risk_score_profile_bucket(profile : RiskScoreProfile) -> String {
  risk_score_band_name(profile.band)
}

///|
pub fn risk_score_profile_weight_total(profile : RiskScoreProfile) -> Double {
  score_component_weight(profile.components)
}

///|
pub fn risk_score_profile_weighted_total(profile : RiskScoreProfile) -> Double {
  score_component_total(profile.components)
}

///|
pub fn risk_score_profile_recalculated_total(
  profile : RiskScoreProfile,
) -> Double {
  score_component_normalized_total(profile.components)
}

///|
pub fn risk_score_profile_consistent(profile : RiskScoreProfile) -> Bool {
  (profile.total - risk_score_profile_recalculated_total(profile)).abs() <
  0.0001
}

///|
pub fn risk_score_window_consistent(window : RiskScoreWindow) -> Bool {
  window.profiles.all(profile => risk_score_profile_consistent(profile))
}

///|
pub fn risk_score_profile_evidence_count(profile : RiskScoreProfile) -> Int {
  profile.components.filter(component => component.evidence != "").length()
}

///|
pub fn risk_score_profile_missing_evidence(
  profile : RiskScoreProfile,
) -> Array[String] {
  profile.components
  .filter(component => component.evidence == "")
  .map(component => component.name)
}

///|
pub fn risk_score_profile_actionable_component_count(
  profile : RiskScoreProfile,
) -> Int {
  profile.components
  .filter(component => {
    risk_score_band_rank(component.band) >= risk_score_band_rank(ScoreAction)
  })
  .length()
}

///|
pub fn risk_score_profile_actionable_components(
  profile : RiskScoreProfile,
) -> Array[String] {
  profile.components
  .filter(component => {
    risk_score_band_rank(component.band) >= risk_score_band_rank(ScoreAction)
  })
  .map(component => component.name)
}

///|
pub fn risk_score_window_actionable_components(
  window : RiskScoreWindow,
) -> Array[String] {
  let names = []
  for profile in window.profiles {
    for name in risk_score_profile_actionable_components(profile) {
      if !names.contains(name) {
        names.push(name)
      }
    }
  }
  names
}

///|
pub fn risk_score_window_evidence_count(window : RiskScoreWindow) -> Int {
  window.profiles.fold(init=0, (total, profile) => {
    total + risk_score_profile_evidence_count(profile)
  })
}

///|
pub fn risk_score_window_actionable_component_count(
  window : RiskScoreWindow,
) -> Int {
  risk_score_window_actionable_components(window).length()
}

///|
pub fn risk_score_window_recommendations(
  window : RiskScoreWindow,
) -> Array[String] {
  window.profiles
  .filter(profile => risk_score_profile_actionable(profile))
  .map(profile => profile.recommendation)
}

///|
pub fn risk_score_window_unique_recommendations(
  window : RiskScoreWindow,
) -> Array[String] {
  let values = []
  for recommendation in risk_score_window_recommendations(window) {
    if !values.contains(recommendation) {
      values.push(recommendation)
    }
  }
  values
}

///|
pub fn risk_score_window_recommendation_count(window : RiskScoreWindow) -> Int {
  risk_score_window_unique_recommendations(window).length()
}

///|
pub fn risk_score_profile_has_high_risk(profile : RiskScoreProfile) -> Bool {
  profile.components.any(component => {
    component.name == "composite_risk" && component.value >= 70.0
  })
}

///|
pub fn risk_score_profile_has_low_readiness(profile : RiskScoreProfile) -> Bool {
  profile.components.any(component => {
    component.name == "readiness_gap" && component.value >= 35.0
  })
}

///|
pub fn risk_score_profile_has_load_spike(profile : RiskScoreProfile) -> Bool {
  profile.components.any(component => {
    component.name == "load_ratio" && component.value >= 50.0
  })
}

///|
pub fn risk_score_profile_has_recovery_gap(profile : RiskScoreProfile) -> Bool {
  profile.components.any(component => {
    component.name == "recovery_gap" && component.value >= 35.0
  })
}

///|
pub fn risk_score_profile_has_quality_gap(profile : RiskScoreProfile) -> Bool {
  profile.components.any(component => {
    component.name == "quality_gap" && component.value >= 20.0
  })
}

///|
pub fn risk_score_profile_reason_codes(
  profile : RiskScoreProfile,
) -> Array[String] {
  let codes = []
  if risk_score_profile_has_high_risk(profile) {
    codes.push("high_risk")
  }
  if risk_score_profile_has_low_readiness(profile) {
    codes.push("low_readiness")
  }
  if risk_score_profile_has_load_spike(profile) {
    codes.push("load_spike")
  }
  if risk_score_profile_has_recovery_gap(profile) {
    codes.push("recovery_gap")
  }
  if risk_score_profile_has_quality_gap(profile) {
    codes.push("quality_gap")
  }
  codes
}

///|
pub fn risk_score_profile_reason_text(profile : RiskScoreProfile) -> String {
  let codes = risk_score_profile_reason_codes(profile)
  if codes.length() == 0 {
    "no dominant reason code"
  } else {
    codes.join(",")
  }
}

///|
pub fn risk_score_window_reason_codes(
  window : RiskScoreWindow,
) -> Array[String] {
  let codes = []
  for profile in window.profiles {
    for code in risk_score_profile_reason_codes(profile) {
      if !codes.contains(code) {
        codes.push(code)
      }
    }
  }
  codes
}

///|
pub fn risk_score_window_reason_text(window : RiskScoreWindow) -> String {
  risk_score_window_reason_codes(window).join(",")
}

///|
pub fn risk_score_profile_audit_line(profile : RiskScoreProfile) -> String {
  profile.date +
  "|" +
  profile.total.to_string() +
  "|" +
  risk_score_profile_reason_text(profile) +
  "|" +
  risk_score_profile_checksum(profile)
}

///|
pub fn risk_score_window_audit_lines(window : RiskScoreWindow) -> Array[String] {
  window.profiles.map(profile => risk_score_profile_audit_line(profile))
}

///|
pub fn risk_score_window_audit_text(window : RiskScoreWindow) -> String {
  risk_score_window_audit_lines(window).join("\n")
}

///|
pub fn risk_score_profile_requires_human(profile : RiskScoreProfile) -> Bool {
  risk_score_profile_actionable(profile) ||
  profile.confidence < 0.5 ||
  risk_score_profile_reason_codes(profile).length() > 2
}

///|
pub fn risk_score_window_requires_human(window : RiskScoreWindow) -> Bool {
  window.profiles.any(profile => risk_score_profile_requires_human(profile))
}

///|
pub fn risk_score_window_human_dates(window : RiskScoreWindow) -> Array[String] {
  window.profiles
  .filter(profile => risk_score_profile_requires_human(profile))
  .map(profile => profile.date)
}

///|
pub fn risk_score_window_human_count(window : RiskScoreWindow) -> Int {
  risk_score_window_human_dates(window).length()
}

///|
pub fn risk_score_window_human_percent(window : RiskScoreWindow) -> Double {
  if window.profiles.length() == 0 {
    0.0
  } else {
    risk_score_window_human_count(window).to_double() /
    window.profiles.length().to_double() *
    100.0
  }
}

///|
pub fn risk_score_profile_status_line(profile : RiskScoreProfile) -> String {
  profile.date +
  " " +
  risk_score_band_name(profile.band) +
  " score=" +
  profile.total.to_string() +
  " confidence=" +
  profile.confidence.to_string()
}

///|
pub fn risk_score_window_status_lines(
  window : RiskScoreWindow,
) -> Array[String] {
  window.profiles.map(profile => risk_score_profile_status_line(profile))
}

///|
pub fn risk_score_window_status_text(window : RiskScoreWindow) -> String {
  risk_score_window_status_lines(window).join("\n")
}

///|
pub fn risk_score_profile_label(profile : RiskScoreProfile) -> String {
  profile.date + ":" + risk_score_band_name(profile.band)
}

///|
pub fn risk_score_window_labels(window : RiskScoreWindow) -> Array[String] {
  window.profiles.map(profile => risk_score_profile_label(profile))
}

///|
pub fn risk_score_profile_deviation(
  profile : RiskScoreProfile,
  baseline : Double,
) -> Double {
  profile.total - baseline
}

///|
pub fn risk_score_window_deviations(
  window : RiskScoreWindow,
  baseline : Double,
) -> Array[Double] {
  window.profiles.map(profile => risk_score_profile_deviation(profile, baseline))
}

///|
pub fn risk_score_window_positive_deviations(
  window : RiskScoreWindow,
  baseline : Double,
) -> Array[Double] {
  risk_score_window_deviations(window, baseline).filter(value => value > 0.0)
}

///|
pub fn risk_score_window_negative_deviations(
  window : RiskScoreWindow,
  baseline : Double,
) -> Array[Double] {
  risk_score_window_deviations(window, baseline).filter(value => value < 0.0)
}

///|
pub fn risk_score_window_deviation_average(
  window : RiskScoreWindow,
  baseline : Double,
) -> Double {
  mean_load_values(risk_score_window_deviations(window, baseline))
}

///|
pub fn risk_score_window_deviation_maximum(
  window : RiskScoreWindow,
  baseline : Double,
) -> Double {
  maximum_load_values(risk_score_window_deviations(window, baseline))
}

///|
pub fn risk_score_window_deviation_minimum(
  window : RiskScoreWindow,
  baseline : Double,
) -> Double {
  minimum_load_values(risk_score_window_deviations(window, baseline))
}

///|
pub fn risk_score_window_above_baseline_count(
  window : RiskScoreWindow,
  baseline : Double,
) -> Int {
  window.profiles.filter(profile => profile.total > baseline).length()
}

///|
pub fn risk_score_window_below_baseline_count(
  window : RiskScoreWindow,
  baseline : Double,
) -> Int {
  window.profiles.filter(profile => profile.total < baseline).length()
}

///|
pub fn risk_score_window_at_baseline_count(
  window : RiskScoreWindow,
  baseline : Double,
) -> Int {
  window.profiles
  .filter(profile => (profile.total - baseline).abs() < 0.001)
  .length()
}

///|
pub fn risk_score_window_baseline_status(
  window : RiskScoreWindow,
  baseline : Double,
) -> String {
  if risk_score_window_above_baseline_count(window, baseline) >
    risk_score_window_below_baseline_count(window, baseline) {
    "above_baseline"
  } else if risk_score_window_below_baseline_count(window, baseline) >
    risk_score_window_above_baseline_count(window, baseline) {
    "below_baseline"
  } else {
    "balanced"
  }
}

///|
pub fn risk_score_profile_next_review_days(profile : RiskScoreProfile) -> Int {
  match profile.band {
    ScoreEscalate => 0
    ScoreAction => 1
    ScoreWatch => 3
    ScoreLow => 7
  }
}

///|
pub fn risk_score_window_next_review_days(window : RiskScoreWindow) -> Int {
  if window.profiles.length() == 0 {
    7
  } else {
    risk_score_profile_next_review_days(
      window.profiles[window.profiles.length() - 1],
    )
  }
}

///|
pub fn risk_score_profile_review_label(profile : RiskScoreProfile) -> String {
  "review_in_" +
  risk_score_profile_next_review_days(profile).to_string() +
  "_days"
}

///|
pub fn risk_score_window_review_label(window : RiskScoreWindow) -> String {
  "review_in_" +
  risk_score_window_next_review_days(window).to_string() +
  "_days"
}

///|
pub fn risk_score_profile_data_quality(profile : RiskScoreProfile) -> Double {
  profile.confidence * 100.0
}

///|
pub fn risk_score_window_data_quality(window : RiskScoreWindow) -> Double {
  risk_score_confidence_average(window.profiles)
}

///|
pub fn risk_score_profile_signal_count(profile : RiskScoreProfile) -> Int {
  profile.components.filter(component => component.value > 0.0).length()
}

///|
pub fn risk_score_window_signal_count(window : RiskScoreWindow) -> Int {
  window.profiles.fold(init=0, (total, profile) => {
    total + risk_score_profile_signal_count(profile)
  })
}

///|
pub fn risk_score_profile_zero_signal(profile : RiskScoreProfile) -> Bool {
  risk_score_profile_signal_count(profile) == 0
}

///|
pub fn risk_score_window_zero_signal_days(window : RiskScoreWindow) -> Int {
  window.profiles
  .filter(profile => risk_score_profile_zero_signal(profile))
  .length()
}

///|
pub fn risk_score_profile_source_summary(profile : RiskScoreProfile) -> String {
  profile.components
  .map(component => component.name + ":" + component.evidence)
  .join("; ")
}

///|
pub fn risk_score_window_source_summary(window : RiskScoreWindow) -> String {
  window.profiles
  .map(profile => risk_score_profile_source_summary(profile))
  .join("\n")
}

///|
pub fn risk_score_profile_json_fields(
  profile : RiskScoreProfile,
) -> Array[String] {
  [
    profile.date,
    profile.total.to_string(),
    risk_score_band_name(profile.band),
    profile.dominant_component,
    profile.confidence.to_string(),
    profile.recommendation,
  ]
}

///|
pub fn risk_score_profile_json_line(profile : RiskScoreProfile) -> String {
  risk_score_profile_json_fields(profile).join("|")
}

///|
pub fn risk_score_window_json_lines(window : RiskScoreWindow) -> Array[String] {
  window.profiles.map(profile => risk_score_profile_json_line(profile))
}

///|
pub fn risk_score_window_json_text(window : RiskScoreWindow) -> String {
  risk_score_window_json_lines(window).join("\n")
}

///|
pub fn risk_score_profile_exportable(profile : RiskScoreProfile) -> Bool {
  risk_score_profile_valid(profile) && profile.recommendation != ""
}

///|
pub fn risk_score_window_exportable(window : RiskScoreWindow) -> Bool {
  risk_score_window_valid(window) &&
  window.profiles.all(profile => risk_score_profile_exportable(profile))
}

///|
pub fn risk_score_profile_export_status(profile : RiskScoreProfile) -> String {
  if risk_score_profile_exportable(profile) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn risk_score_window_export_status(window : RiskScoreWindow) -> String {
  if risk_score_window_exportable(window) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn risk_score_profile_reasons(profile : RiskScoreProfile) -> Array[String] {
  risk_score_profile_reason_codes(profile)
}

///|
pub fn risk_score_window_reasons(window : RiskScoreWindow) -> Array[String] {
  risk_score_window_reason_codes(window)
}

///|
pub fn risk_score_profile_urgency(profile : RiskScoreProfile) -> Int {
  risk_score_band_rank(profile.band)
}

///|
pub fn risk_score_window_urgency(window : RiskScoreWindow) -> Int {
  if window.profiles.length() == 0 {
    0
  } else {
    window.profiles
    .map(profile => risk_score_profile_urgency(profile))
    .fold(init=0, (maximum, value) => maximum.max(value))
  }
}

///|
pub fn risk_score_profile_priority(profile : RiskScoreProfile) -> String {
  match risk_score_profile_urgency(profile) {
    3 => "critical"
    2 => "high"
    1 => "medium"
    _ => "routine"
  }
}

///|
pub fn risk_score_window_priority(window : RiskScoreWindow) -> String {
  match risk_score_window_urgency(window) {
    3 => "critical"
    2 => "high"
    1 => "medium"
    _ => "routine"
  }
}

///|
pub fn risk_score_profile_priority_code(profile : RiskScoreProfile) -> Int {
  risk_score_profile_urgency(profile) + 1
}

///|
pub fn risk_score_window_priority_code(window : RiskScoreWindow) -> Int {
  risk_score_window_urgency(window) + 1
}

///|
pub fn risk_score_profile_impact(profile : RiskScoreProfile) -> Double {
  profile.total * profile.confidence
}

///|
pub fn risk_score_window_impact(window : RiskScoreWindow) -> Double {
  mean_load_values(
    window.profiles.map(profile => risk_score_profile_impact(profile)),
  )
}

///|
pub fn risk_score_profile_actionable_impact(
  profile : RiskScoreProfile,
) -> Double {
  if risk_score_profile_actionable(profile) {
    risk_score_profile_impact(profile)
  } else {
    0.0
  }
}

///|
pub fn risk_score_window_actionable_impact(window : RiskScoreWindow) -> Double {
  mean_load_values(
    window.profiles.map(profile => risk_score_profile_actionable_impact(profile)),
  )
}

///|
pub fn risk_score_profile_coverage(profile : RiskScoreProfile) -> Double {
  if profile.components.length() == 0 {
    0.0
  } else {
    profile.components
    .filter(component => component.evidence != "")
    .length()
    .to_double() /
    profile.components.length().to_double() *
    100.0
  }
}

///|
pub fn risk_score_window_coverage(window : RiskScoreWindow) -> Double {
  mean_load_values(
    window.profiles.map(profile => risk_score_profile_coverage(profile)),
  )
}

///|
pub fn risk_score_profile_complete(profile : RiskScoreProfile) -> Bool {
  risk_score_profile_coverage(profile) >= 80.0
}

///|
pub fn risk_score_window_complete(window : RiskScoreWindow) -> Bool {
  risk_score_window_coverage(window) >= 80.0
}

///|
pub fn risk_score_profile_contract(profile : RiskScoreProfile) -> Array[String] {
  [
    risk_score_profile_quality(profile),
    risk_score_profile_export_status(profile),
    risk_score_profile_priority(profile),
    risk_score_profile_review_label(profile),
  ]
}

///|
pub fn risk_score_window_contract(window : RiskScoreWindow) -> Array[String] {
  [
    risk_score_window_quality(window),
    risk_score_window_export_status(window),
    risk_score_window_priority(window),
    risk_score_window_review_label(window),
  ]
}
