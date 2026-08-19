///|
/// Outcome tracking for checking whether recommendations changed the observed state.
pub(all) struct OutcomeObservation {
  date : String
  risk_score : Double
  readiness_score : Double
  recovery_score : Double
  load : Double
  pain : Double
  intervention_id : String?
} derive(Debug, Eq, ToJson)

///|
pub(all) struct OutcomeEffect {
  intervention_id : String
  observation_count : Int
  risk_change : Double
  readiness_change : Double
  recovery_change : Double
  pain_change : Double
  load_change : Double
  effective : Bool
  confidence : Double
  note : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct OutcomeReport {
  observations : Array[OutcomeObservation]
  effects : Array[OutcomeEffect]
  improving_count : Int
  worsening_count : Int
  stable_count : Int
  status : String
} derive(Debug, Eq, ToJson)

///|
pub fn outcome_observation(
  assessment : ComprehensiveAssessment,
  intervention_id : String?,
) -> OutcomeObservation {
  {
    date: assessment.date,
    risk_score: assessment.risk_score,
    readiness_score: assessment.readiness_score,
    recovery_score: assessment.recovery.recovery_score,
    load: assessment.load.average_load,
    pain: assessment.recovery.maximum_pain,
    intervention_id,
  }
}

///|
pub fn outcome_observations(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> Array[OutcomeObservation] {
  let sorted = sort_records_by_date(records)
  let output = []
  for record in sorted {
    match assess_comprehensive(sorted, record.date, policy) {
      Some(assessment) => output.push(outcome_observation(assessment, None))
      None => ()
    }
  }
  output
}

///|
fn effect_for_pair(
  left : OutcomeObservation,
  right : OutcomeObservation,
  id : String,
) -> OutcomeEffect {
  let risk_change = right.risk_score - left.risk_score
  let readiness_change = right.readiness_score - left.readiness_score
  let recovery_change = right.recovery_score - left.recovery_score
  let pain_change = right.pain - left.pain
  let load_change = right.load - left.load
  {
    intervention_id: id,
    observation_count: 2,
    risk_change,
    readiness_change,
    recovery_change,
    pain_change,
    load_change,
    effective: risk_change <= 0.0 &&
    readiness_change >= -5.0 &&
    pain_change <= 1.0,
    confidence: 0.50,
    note: if risk_change <= 0.0 {
      "risk did not increase"
    } else {
      "risk increased; review adherence"
    },
  }
}

///|
pub fn evaluate_outcome_effects(
  observations : Array[OutcomeObservation],
) -> Array[OutcomeEffect] {
  let effects = []
  for index in 1..<observations.length() {
    let id = match observations[index].intervention_id {
      Some(value) => value
      None => "observation-" + index.to_string()
    }
    effects.push(
      effect_for_pair(observations[index - 1], observations[index], id),
    )
  }
  effects
}

///|
pub fn build_outcome_report(
  records : Array[DailyRecord],
  policy : RiskPolicy,
) -> OutcomeReport {
  let observations = outcome_observations(records, policy)
  let effects = evaluate_outcome_effects(observations)
  let improving = effects.filter(effect => effect.effective).length()
  let worsening = effects.filter(effect => effect.risk_change > 10.0).length()
  {
    observations,
    effects,
    improving_count: improving,
    worsening_count: worsening,
    stable_count: (effects.length() - improving - worsening).max(0),
    status: if worsening > improving {
      "worsening"
    } else if improving > 0 {
      "improving"
    } else {
      "stable"
    },
  }
}

///|
pub fn outcome_latest(report : OutcomeReport) -> OutcomeObservation? {
  if report.observations.length() == 0 {
    None
  } else {
    Some(report.observations[report.observations.length() - 1])
  }
}

///|
pub fn outcome_first(report : OutcomeReport) -> OutcomeObservation? {
  if report.observations.length() == 0 {
    None
  } else {
    Some(report.observations[0])
  }
}

///|
pub fn outcome_risk_change(report : OutcomeReport) -> Double {
  match (outcome_first(report), outcome_latest(report)) {
    (Some(first), Some(last)) => last.risk_score - first.risk_score
    _ => 0.0
  }
}

///|
pub fn outcome_readiness_change(report : OutcomeReport) -> Double {
  match (outcome_first(report), outcome_latest(report)) {
    (Some(first), Some(last)) => last.readiness_score - first.readiness_score
    _ => 0.0
  }
}

///|
pub fn outcome_effective_ids(report : OutcomeReport) -> Array[String] {
  report.effects
  .filter(effect => effect.effective)
  .map(effect => effect.intervention_id)
}

///|
pub fn outcome_ineffective_ids(report : OutcomeReport) -> Array[String] {
  report.effects
  .filter(effect => !effect.effective)
  .map(effect => effect.intervention_id)
}

///|
pub fn outcome_effect_average(report : OutcomeReport) -> Double {
  mean_load_values(
    report.effects.map(effect => if effect.effective { 1.0 } else { 0.0 }),
  ) *
  100.0
}

///|
pub fn outcome_requires_review(report : OutcomeReport) -> Bool {
  report.status == "worsening" || report.worsening_count > 0
}

///|
pub fn outcome_recommendation(report : OutcomeReport) -> String {
  if outcome_requires_review(report) {
    "review intervention choice and adherence"
  } else if report.improving_count > 0 {
    "retain effective recovery behavior"
  } else {
    "collect more post-intervention observations"
  }
}

///|
pub fn outcome_observation_text(observation : OutcomeObservation) -> String {
  observation.date +
  " risk=" +
  observation.risk_score.to_string() +
  " readiness=" +
  observation.readiness_score.to_string() +
  " recovery=" +
  observation.recovery_score.to_string() +
  " load=" +
  observation.load.to_string() +
  " pain=" +
  observation.pain.to_string()
}

///|
pub fn outcome_report_text(report : OutcomeReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "status=" +
    report.status +
    " observations=" +
    report.observations.length().to_string() +
    " improving=" +
    report.improving_count.to_string() +
    " worsening=" +
    report.worsening_count.to_string() +
    " effect_rate=" +
    outcome_effect_average(report).to_string() +
    "% action=" +
    outcome_recommendation(report),
  )
  for observation in report.observations {
    builder.write_string("\n" + outcome_observation_text(observation))
  }
  builder.to_string()
}

///|
pub fn outcome_observation_csv_header() -> String {
  "date,risk_score,readiness_score,recovery_score,load,pain,intervention_id"
}

///|
pub fn outcome_observation_csv(observation : OutcomeObservation) -> String {
  let intervention = match observation.intervention_id {
    Some(value) => value
    None => ""
  }
  observation.date +
  "," +
  observation.risk_score.to_string() +
  "," +
  observation.readiness_score.to_string() +
  "," +
  observation.recovery_score.to_string() +
  "," +
  observation.load.to_string() +
  "," +
  observation.pain.to_string() +
  "," +
  intervention
}

///|
pub fn outcome_report_csv(report : OutcomeReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string(outcome_observation_csv_header())
  for observation in report.observations {
    builder.write_string("\n")
    builder.write_string(outcome_observation_csv(observation))
  }
  builder.to_string()
}

///|
pub fn outcome_observation_valid(observation : OutcomeObservation) -> Bool {
  observation.date != "" &&
  observation.risk_score >= 0.0 &&
  observation.risk_score <= 100.0 &&
  observation.readiness_score >= 0.0 &&
  observation.readiness_score <= 100.0 &&
  observation.recovery_score >= 0.0 &&
  observation.recovery_score <= 100.0 &&
  observation.load >= 0.0 &&
  observation.pain >= 0.0
}
