///|
/// A planned daily load inside a training microcycle.
pub(all) struct MicrocycleDay {
  date : String
  target_load : Double
  target_intensity : Double
  kind : SessionKind
  is_rest : Bool
  rationale : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct MicrocyclePlan {
  name : String
  start_date : String
  days : Array[MicrocycleDay]
  total_target_load : Double
  maximum_target_load : Double
  rest_day_count : Int
  guardrail : ProgressionGuardrail
} derive(Debug, Eq, ToJson)

///|
pub(all) struct MicrocycleReview {
  target_load : Double
  actual_load : Double
  adherence_percent : Double
  rest_days_planned : Int
  rest_days_observed : Int
  risk_note : String
} derive(Debug, Eq, ToJson)

///|
pub fn microcycle_day(
  date : String,
  target_load : Double,
  target_intensity : Double,
  kind : SessionKind,
  is_rest : Bool,
  rationale : String,
) -> MicrocycleDay {
  { date, target_load, target_intensity, kind, is_rest, rationale }
}

///|
pub fn propose_microcycle(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  start_date : String,
  days : Int,
  change_percent : Double,
) -> MicrocyclePlan {
  let count = days.max(0)
  let start = parse_date(start_date)
  let recent = if records.length() == 0 {
    0.0
  } else {
    chronic_load_average(records, records.length() - 1, policy.acute_window)
  }
  let target = recent * (1.0 + change_percent / 100.0)
  let guardrail = progression_guardrail(records, policy, change_percent)
  let planned = []
  for index in 0..<count {
    let date = match start {
      Some(start) => format_date(add_days(start, index).unwrap())
      None => start_date
    }
    let is_rest = index == count - 1 || index % 4 == 3
    let day_load = if is_rest {
      0.0
    } else {
      target / (count - 2).max(1).to_double()
    }
    let kind = if is_rest {
      SessionKind::Recovery
    } else if index % 3 == 0 {
      SessionKind::Endurance
    } else {
      SessionKind::Mixed
    }
    planned.push(
      microcycle_day(
        date,
        day_load,
        if is_rest {
          0.0
        } else {
          5.0 + (change_percent / 20.0).min(2.0)
        },
        kind,
        is_rest,
        if is_rest {
          "planned recovery"
        } else {
          "controlled progression"
        },
      ),
    )
  }
  {
    name: "guardrailed microcycle",
    start_date,
    days: planned,
    total_target_load: total_load_values(planned.map(day => day.target_load)),
    maximum_target_load: maximum_load_values(
      planned.map(day => day.target_load),
    ),
    rest_day_count: planned.filter(day => day.is_rest).length(),
    guardrail,
  }
}

///|
pub fn review_microcycle(
  plan : MicrocyclePlan,
  records : Array[DailyRecord],
) -> MicrocycleReview {
  let targets = plan.days.map(day => {
    training_target(day.date, day.target_load / 5.0, 5.0, day.kind, day.is_rest)
  })
  let adherence = adherence_report(targets, records, 60.0)
  let observed_rest = records
    .filter(record => daily_training_load(record) == 0.0)
    .length()
  let actual = total_load_values(training_loads(records))
  {
    target_load: plan.total_target_load,
    actual_load: actual,
    adherence_percent: adherence.adherence_percent,
    rest_days_planned: plan.rest_day_count,
    rest_days_observed: observed_rest,
    risk_note: if plan.guardrail.allowed {
      "plan remains inside the progression guardrail"
    } else {
      "plan should be reduced before delivery"
    },
  }
}

///|
pub fn microcycle_rest_ratio(plan : MicrocyclePlan) -> Double {
  if plan.days.length() == 0 {
    0.0
  } else {
    plan.rest_day_count.to_double() / plan.days.length().to_double()
  }
}

///|
pub fn microcycle_load_profile(plan : MicrocyclePlan) -> Array[Double] {
  plan.days.map(day => day.target_load)
}

///|
pub fn microcycle_is_balanced(plan : MicrocyclePlan) -> Bool {
  let profile = microcycle_load_profile(plan)
  workload_monotony(profile) < 3.0 && microcycle_rest_ratio(plan) >= 0.20
}

///|
pub fn microcycle_text(plan : MicrocyclePlan) -> String {
  "name=" +
  plan.name +
  " start=" +
  plan.start_date +
  " days=" +
  plan.days.length().to_string() +
  " target_load=" +
  plan.total_target_load.to_string() +
  " rest_days=" +
  plan.rest_day_count.to_string() +
  " balanced=" +
  microcycle_is_balanced(plan).to_string()
}
