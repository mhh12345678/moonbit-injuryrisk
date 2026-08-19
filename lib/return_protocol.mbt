///|
/// Conservative staged return-to-training state machine.
pub(all) enum ReturnStage {
  ReturnRest
  ReturnCheck
  ReturnLowLoad
  ReturnModerateLoad
  ReturnNormalLoad
  ReturnProgression
  ReturnCleared
  ReturnPaused
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ReturnCriteria {
  maximum_pain : Double
  minimum_sleep_hours : Double
  minimum_recovery_score : Double
  minimum_readiness_score : Double
  maximum_load_change_percent : Double
  required_stable_days : Int
  require_quality_pass : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ReturnObservation {
  date : String
  stage : ReturnStage
  pain : Double
  sleep_hours : Double
  recovery_score : Double
  readiness_score : Double
  load : Double
  quality_score : Double
  criteria_met : Bool
  reasons : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ReturnPlan {
  athlete_label : String
  start_date : String
  current_stage : ReturnStage
  target_stage : ReturnStage
  criteria : ReturnCriteria
  observations : Array[ReturnObservation]
  next_review_date : String
  paused : Bool
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ReturnDecision {
  allowed : Bool
  from_stage : ReturnStage
  to_stage : ReturnStage
  reasons : Array[String]
  load_cap_percent : Double
  review_after_days : Int
} derive(Debug, Eq, ToJson)

///|
pub fn return_stage_name(stage : ReturnStage) -> String {
  match stage {
    ReturnRest => "rest"
    ReturnCheck => "check"
    ReturnLowLoad => "low_load"
    ReturnModerateLoad => "moderate_load"
    ReturnNormalLoad => "normal_load"
    ReturnProgression => "progression"
    ReturnCleared => "cleared"
    ReturnPaused => "paused"
  }
}

///|
fn return_stage_rank(stage : ReturnStage) -> Int {
  match stage {
    ReturnRest => 0
    ReturnCheck => 1
    ReturnLowLoad => 2
    ReturnModerateLoad => 3
    ReturnNormalLoad => 4
    ReturnProgression => 5
    ReturnCleared => 6
    ReturnPaused => -1
  }
}

///|
pub fn default_return_criteria() -> ReturnCriteria {
  {
    maximum_pain: 2.0,
    minimum_sleep_hours: 7.0,
    minimum_recovery_score: 70.0,
    minimum_readiness_score: 70.0,
    maximum_load_change_percent: 10.0,
    required_stable_days: 3,
    require_quality_pass: true,
  }
}

///|
pub fn return_stage_load_cap(stage : ReturnStage) -> Double {
  match stage {
    ReturnRest => 0.0
    ReturnCheck => 20.0
    ReturnLowLoad => 40.0
    ReturnModerateLoad => 60.0
    ReturnNormalLoad => 80.0
    ReturnProgression => 100.0
    ReturnCleared => 120.0
    ReturnPaused => 0.0
  }
}

///|
pub fn return_stage_review_days(stage : ReturnStage) -> Int {
  match stage {
    ReturnRest => 1
    ReturnCheck => 1
    ReturnLowLoad => 2
    ReturnModerateLoad => 2
    ReturnNormalLoad => 3
    ReturnProgression => 3
    ReturnCleared => 7
    ReturnPaused => 1
  }
}

///|
fn next_return_stage(stage : ReturnStage) -> ReturnStage {
  match stage {
    ReturnRest => ReturnCheck
    ReturnCheck => ReturnLowLoad
    ReturnLowLoad => ReturnModerateLoad
    ReturnModerateLoad => ReturnNormalLoad
    ReturnNormalLoad => ReturnProgression
    ReturnProgression => ReturnCleared
    ReturnCleared => ReturnCleared
    ReturnPaused => ReturnCheck
  }
}

///|
fn previous_return_stage(stage : ReturnStage) -> ReturnStage {
  match stage {
    ReturnRest => ReturnRest
    ReturnCheck => ReturnRest
    ReturnLowLoad => ReturnCheck
    ReturnModerateLoad => ReturnLowLoad
    ReturnNormalLoad => ReturnModerateLoad
    ReturnProgression => ReturnNormalLoad
    ReturnCleared => ReturnProgression
    ReturnPaused => ReturnPaused
  }
}

///|
fn observation_reasons(
  record : DailyRecord,
  assessment : ComprehensiveAssessment?,
  criteria : ReturnCriteria,
) -> Array[String] {
  let reasons = []
  if record.pain_level > criteria.maximum_pain {
    reasons.push("pain exceeds return threshold")
  }
  if record.sleep_hours < criteria.minimum_sleep_hours {
    reasons.push("sleep is below return threshold")
  }
  match assessment {
    Some(assessment) => {
      if assessment.recovery.recovery_score < criteria.minimum_recovery_score {
        reasons.push("recovery score is below return threshold")
      }
      if assessment.readiness_score < criteria.minimum_readiness_score {
        reasons.push("readiness is below return threshold")
      }
      if criteria.require_quality_pass &&
        assessment.quality.blocking_issue_count > 0 {
        reasons.push("blocking quality issue remains")
      }
    }
    None => reasons.push("no assessment is available")
  }
  reasons
}

///|
fn observation_for(
  record : DailyRecord,
  stage : ReturnStage,
  assessment : ComprehensiveAssessment?,
  criteria : ReturnCriteria,
) -> ReturnObservation {
  let reasons = observation_reasons(record, assessment, criteria)
  let recovery = match assessment {
    Some(value) => value.recovery.recovery_score
    None => 0.0
  }
  let readiness = match assessment {
    Some(value) => value.readiness_score
    None => 0.0
  }
  let quality = match assessment {
    Some(value) => value.quality.score
    None => 0.0
  }
  {
    date: record.date,
    stage,
    pain: record.pain_level,
    sleep_hours: record.sleep_hours,
    recovery_score: recovery,
    readiness_score: readiness,
    load: daily_training_load(record),
    quality_score: quality,
    criteria_met: reasons.length() == 0,
    reasons,
  }
}

///|
pub fn return_observation_is_safe(observation : ReturnObservation) -> Bool {
  observation.criteria_met && observation.stage != ReturnPaused
}

///|
pub fn return_plan_from_assessment(
  assessment : ComprehensiveAssessment,
  athlete_label : String,
) -> ReturnPlan {
  let stage = if assessment.risk_level == High {
    ReturnRest
  } else if assessment.risk_level == Medium {
    ReturnCheck
  } else {
    ReturnLowLoad
  }
  let criteria = default_return_criteria()
  {
    athlete_label,
    start_date: assessment.date,
    current_stage: stage,
    target_stage: ReturnCleared,
    criteria,
    observations: [],
    next_review_date: assessment.date,
    paused: stage == ReturnRest,
    recommendation: if stage == ReturnRest {
      "rest and obtain qualified review"
    } else {
      "begin with a controlled load"
    },
  }
}

///|
pub fn return_plan_from_records(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  athlete_label : String,
) -> ReturnPlan? {
  match assess_latest(records, policy) {
    Some(assessment) =>
      Some(return_plan_from_assessment(assessment, athlete_label))
    None => None
  }
}

///|
fn return_date_after(date : String, days : Int) -> String {
  match parse_date(date) {
    Some(date) =>
      match add_days(date, days) {
        Some(value) => format_date(value)
        None => format_date(date)
      }
    None => date
  }
}

///|
fn criteria_reasons(
  assessment : ComprehensiveAssessment?,
  record : DailyRecord?,
  criteria : ReturnCriteria,
) -> Array[String] {
  let reasons = []
  match record {
    Some(record) => {
      if record.pain_level > criteria.maximum_pain {
        reasons.push("pain exceeds threshold")
      }
      if record.sleep_hours < criteria.minimum_sleep_hours {
        reasons.push("sleep is below threshold")
      }
    }
    None => reasons.push("daily record is missing")
  }
  match assessment {
    Some(assessment) => {
      if assessment.recovery.recovery_score < criteria.minimum_recovery_score {
        reasons.push("recovery is insufficient")
      }
      if assessment.readiness_score < criteria.minimum_readiness_score {
        reasons.push("readiness is insufficient")
      }
      if criteria.require_quality_pass &&
        assessment.quality.blocking_issue_count > 0 {
        reasons.push("quality contract is not satisfied")
      }
    }
    None => reasons.push("assessment is missing")
  }
  reasons
}

///|
pub fn decide_return_stage(
  plan : ReturnPlan,
  record : DailyRecord?,
  assessment : ComprehensiveAssessment?,
) -> ReturnDecision {
  let reasons = criteria_reasons(assessment, record, plan.criteria)
  let current = plan.current_stage
  if plan.paused {
    return {
      allowed: false,
      from_stage: current,
      to_stage: ReturnPaused,
      reasons: ["plan is paused"] + reasons,
      load_cap_percent: 0.0,
      review_after_days: 1,
    }
  }
  if reasons.length() > 0 {
    return {
      allowed: false,
      from_stage: current,
      to_stage: previous_return_stage(current),
      reasons,
      load_cap_percent: return_stage_load_cap(previous_return_stage(current)),
      review_after_days: 1,
    }
  }
  let next = next_return_stage(current)
  {
    allowed: true,
    from_stage: current,
    to_stage: next,
    reasons: ["all configured return criteria are met"],
    load_cap_percent: return_stage_load_cap(next),
    review_after_days: return_stage_review_days(next),
  }
}

///|
fn updated_return_plan(
  plan : ReturnPlan,
  decision : ReturnDecision,
  observation : ReturnObservation,
) -> ReturnPlan {
  let paused = !decision.allowed || decision.to_stage == ReturnPaused
  let stage = if paused { ReturnPaused } else { decision.to_stage }
  {
    athlete_label: plan.athlete_label,
    start_date: plan.start_date,
    current_stage: stage,
    target_stage: plan.target_stage,
    criteria: plan.criteria,
    observations: plan.observations + [observation],
    next_review_date: return_date_after(
      observation.date,
      decision.review_after_days,
    ),
    paused,
    recommendation: if paused {
      "hold current training and review failed criteria"
    } else {
      "use the new stage load cap and collect another observation"
    },
  }
}

///|
pub fn advance_return_plan(
  plan : ReturnPlan,
  record : DailyRecord,
  assessment : ComprehensiveAssessment?,
) -> ReturnPlan {
  let decision = decide_return_stage(plan, Some(record), assessment)
  let observation = observation_for(
    record,
    plan.current_stage,
    assessment,
    plan.criteria,
  )
  updated_return_plan(plan, decision, observation)
}

///|
pub fn pause_return_plan(
  plan : ReturnPlan,
  date : String,
  reason : String,
) -> ReturnPlan {
  {
    athlete_label: plan.athlete_label,
    start_date: plan.start_date,
    current_stage: ReturnPaused,
    target_stage: plan.target_stage,
    criteria: plan.criteria,
    observations: plan.observations +
    [
      {
        date,
        stage: ReturnPaused,
        pain: 0.0,
        sleep_hours: 0.0,
        recovery_score: 0.0,
        readiness_score: 0.0,
        load: 0.0,
        quality_score: 0.0,
        criteria_met: false,
        reasons: [reason],
      },
    ],
    next_review_date: return_date_after(date, 1),
    paused: true,
    recommendation: reason,
  }
}

///|
pub fn resume_return_plan(plan : ReturnPlan, date : String) -> ReturnPlan {
  let stage = if plan.current_stage == ReturnPaused {
    ReturnCheck
  } else {
    plan.current_stage
  }
  {
    athlete_label: plan.athlete_label,
    start_date: plan.start_date,
    current_stage: stage,
    target_stage: plan.target_stage,
    criteria: plan.criteria,
    observations: plan.observations,
    next_review_date: date,
    paused: false,
    recommendation: "collect a fresh check-in before progressing",
  }
}

///|
pub fn return_plan_completion_percent(plan : ReturnPlan) -> Double {
  let target = return_stage_rank(plan.target_stage)
  let current = return_stage_rank(plan.current_stage).max(0)
  if target <= 0 {
    0.0
  } else {
    current.to_double() / target.to_double() * 100.0
  }
}

///|
pub fn return_plan_is_cleared(plan : ReturnPlan) -> Bool {
  !plan.paused && plan.current_stage == ReturnCleared
}

///|
pub fn return_plan_has_recent_failure(plan : ReturnPlan) -> Bool {
  if plan.observations.length() == 0 {
    false
  } else {
    !plan.observations[plan.observations.length() - 1].criteria_met
  }
}

///|
pub fn return_stable_observation_count(plan : ReturnPlan) -> Int {
  let mut count = 0
  for observation in plan.observations {
    if observation.criteria_met {
      count += 1
    } else {
      count = 0
    }
  }
  count
}

///|
pub fn return_plan_load_cap(plan : ReturnPlan) -> Double {
  return_stage_load_cap(plan.current_stage)
}

///|
pub fn return_plan_reason_codes(plan : ReturnPlan) -> Array[String] {
  let reasons = []
  for observation in plan.observations {
    for reason in observation.reasons {
      if !reasons.contains(reason) {
        reasons.push(reason)
      }
    }
  }
  reasons
}

///|
pub fn return_plan_text(plan : ReturnPlan) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "athlete=" +
    plan.athlete_label +
    " stage=" +
    return_stage_name(plan.current_stage),
  )
  builder.write_string(
    " target=" +
    return_stage_name(plan.target_stage) +
    " cap=" +
    return_plan_load_cap(plan).to_string() +
    "%",
  )
  builder.write_string(
    " completion=" +
    return_plan_completion_percent(plan).to_string() +
    "% review=" +
    plan.next_review_date,
  )
  builder.write_string("\nrecommendation=" + plan.recommendation)
  for observation in plan.observations {
    builder.write_string(
      "\n- " +
      observation.date +
      " criteria=" +
      observation.criteria_met.to_string() +
      " reasons=" +
      observation.reasons.join(";"),
    )
  }
  builder.to_string()
}

///|
pub fn return_observation_csv_header() -> String {
  "date,stage,pain,sleep_hours,recovery,readiness,load,quality,criteria_met,reasons"
}

///|
pub fn return_observation_csv(observation : ReturnObservation) -> String {
  observation.date +
  "," +
  return_stage_name(observation.stage) +
  "," +
  observation.pain.to_string() +
  "," +
  observation.sleep_hours.to_string() +
  "," +
  observation.recovery_score.to_string() +
  "," +
  observation.readiness_score.to_string() +
  "," +
  observation.load.to_string() +
  "," +
  observation.quality_score.to_string() +
  "," +
  observation.criteria_met.to_string() +
  "," +
  observation.reasons.join("|")
}

///|
pub fn return_plan_csv(plan : ReturnPlan) -> String {
  let builder = StringBuilder::new()
  builder.write_string(return_observation_csv_header())
  for observation in plan.observations {
    builder.write_string("\n")
    builder.write_string(return_observation_csv(observation))
  }
  builder.to_string()
}

///|
pub fn return_criteria_valid(criteria : ReturnCriteria) -> Bool {
  criteria.maximum_pain >= 0.0 &&
  criteria.minimum_sleep_hours >= 0.0 &&
  criteria.minimum_recovery_score >= 0.0 &&
  criteria.minimum_recovery_score <= 100.0 &&
  criteria.minimum_readiness_score >= 0.0 &&
  criteria.minimum_readiness_score <= 100.0 &&
  criteria.maximum_load_change_percent >= 0.0 &&
  criteria.required_stable_days > 0
}

///|
pub fn return_plan_valid(plan : ReturnPlan) -> Bool {
  plan.athlete_label != "" &&
  plan.start_date != "" &&
  return_criteria_valid(plan.criteria) &&
  plan.next_review_date != "" &&
  plan.observations.all(observation => observation.date != "")
}

///|
pub fn return_stage_catalog() -> Array[String] {
  [
    return_stage_name(ReturnRest),
    return_stage_name(ReturnCheck),
    return_stage_name(ReturnLowLoad),
    return_stage_name(ReturnModerateLoad),
    return_stage_name(ReturnNormalLoad),
    return_stage_name(ReturnProgression),
    return_stage_name(ReturnCleared),
    return_stage_name(ReturnPaused),
  ]
}
