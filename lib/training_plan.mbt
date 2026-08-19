///|
/// A multi-phase training plan built on top of the workload guardrails.
pub(all) enum PlanPhase {
  Base
  Build
  Peak
  Deload
  Recovery
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PlannedDay {
  date : String
  phase : PlanPhase
  target_load : Double
  target_intensity : Double
  rest : Bool
  rationale : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct TrainingPlan {
  name : String
  start_date : String
  phase : PlanPhase
  days : Array[PlannedDay]
  target_total_load : Double
  max_target_load : Double
  risk_guardrail : ProgressionGuardrail
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PlanReview {
  plan_name : String
  expected_load : Double
  actual_load : Double
  variance_percent : Double
  rest_compliance : Double
  risk_level : RiskLevel
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub fn plan_phase_name(phase : PlanPhase) -> String {
  match phase {
    Base => "base"
    Build => "build"
    Peak => "peak"
    Deload => "deload"
    Recovery => "recovery"
  }
}

///|
pub fn phase_load_multiplier(phase : PlanPhase) -> Double {
  match phase {
    Base => 1.0
    Build => 1.05
    Peak => 1.10
    Deload => 0.70
    Recovery => 0.45
  }
}

///|
pub fn build_training_plan(
  name : String,
  start_date : String,
  phase : PlanPhase,
  baseline_load : Double,
  days : Int,
  policy : RiskPolicy,
  records : Array[DailyRecord],
) -> TrainingPlan {
  let count = days.max(0)
  let start = parse_date(start_date)
  let target = baseline_load * phase_load_multiplier(phase)
  let guardrail = progression_guardrail(
    records,
    policy,
    (phase_load_multiplier(phase) - 1.0) * 100.0,
  )
  let planned = []
  for index in 0..<count {
    let rest = phase is Deload || phase is Recovery || index % 5 == 4
    let active_days = (count - count / 5).max(1)
    let daily = if rest { 0.0 } else { target / active_days.to_double() }
    let date = match start {
      Some(value) => format_date(add_days(value, index).unwrap())
      None => start_date
    }
    planned.push({
      date,
      phase,
      target_load: daily,
      target_intensity: if rest {
        0.0
      } else if phase is Peak {
        7.0
      } else {
        5.0
      },
      rest,
      rationale: if rest {
        "planned recovery or deload day"
      } else {
        "phase-controlled training day"
      },
    })
  }
  {
    name,
    start_date,
    phase,
    days: planned,
    target_total_load: total_load_values(planned.map(day => day.target_load)),
    max_target_load: maximum_load_values(planned.map(day => day.target_load)),
    risk_guardrail: guardrail,
  }
}

///|
pub fn plan_targets(plan : TrainingPlan) -> Array[TrainingTarget] {
  plan.days.map(day => {
    training_target(
      day.date,
      if day.target_intensity == 0.0 {
        0.0
      } else {
        day.target_load / day.target_intensity
      },
      day.target_intensity,
      if day.rest {
        Recovery
      } else {
        Mixed
      },
      day.rest,
    )
  })
}

///|
pub fn review_training_plan(
  plan : TrainingPlan,
  records : Array[DailyRecord],
) -> PlanReview {
  let targets = plan_targets(plan)
  let adherence = adherence_report(targets, records, 60.0)
  let actual = total_load_values(training_loads(records))
  let adherence_percent = adherence.adherence_percent
  let variance = if plan.target_total_load == 0.0 {
    0.0
  } else {
    (actual - plan.target_total_load) / plan.target_total_load * 100.0
  }
  let risk = if variance > 30.0 || adherence_percent < 50.0 {
    High
  } else if variance > 15.0 || adherence_percent < 75.0 {
    Medium
  } else {
    Low
  }
  {
    plan_name: plan.name,
    expected_load: plan.target_total_load,
    actual_load: actual,
    variance_percent: variance,
    rest_compliance: if plan.days.length() == 0 {
      0.0
    } else {
      let expected = plan.days.filter(day => day.rest).length()
      let observed = records
        .filter(record => daily_training_load(record) == 0.0)
        .length()
      observed.to_double() / expected.max(1).to_double() * 100.0
    },
    risk_level: risk,
    recommendation: if risk == High {
      "reduce the next phase target"
    } else if risk == Medium {
      "hold the current phase and monitor"
    } else {
      "plan variance is acceptable"
    },
  }
}

///|
pub fn plan_is_safe(plan : TrainingPlan) -> Bool {
  plan.risk_guardrail.allowed && plan.max_target_load >= 0.0
}

///|
pub fn plan_rest_days(plan : TrainingPlan) -> Array[String] {
  plan.days.filter(day => day.rest).map(day => day.date)
}

///|
pub fn plan_text(plan : TrainingPlan) -> String {
  "plan=" +
  plan.name +
  " phase=" +
  plan_phase_name(plan.phase) +
  " days=" +
  plan.days.length().to_string() +
  " target_load=" +
  plan.target_total_load.to_string() +
  " max_day=" +
  plan.max_target_load.to_string() +
  " safe=" +
  plan_is_safe(plan).to_string()
}
