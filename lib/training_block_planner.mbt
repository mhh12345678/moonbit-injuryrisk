///|
/// Training block planner with explicit daily caps and review checkpoints.
pub(all) struct BlockPlanDay {
  date : String
  target_load : Double
  target_intensity : Double
  rest : Bool
  phase : PlanPhase
  cap_reason : String
  review_required : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct BlockPlan {
  name : String
  start_date : String
  days : Array[BlockPlanDay]
  target_total_load : Double
  maximum_day_load : Double
  rest_days : Int
  review_days : Int
  safe : Bool
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
fn block_phase_for_index(index : Int, count : Int) -> PlanPhase {
  if count <= 1 {
    Base
  } else if index >= count - 2 {
    Peak
  } else if index >= count / 2 {
    Build
  } else {
    Base
  }
}

///|
fn block_day_date(start_date : String, offset : Int) -> String {
  match parse_date(start_date) {
    Some(date) =>
      match add_days(date, offset) {
        Some(value) => format_date(value)
        None => start_date
      }
    None => start_date
  }
}

///|
fn block_target_for_day(
  base : Double,
  phase : PlanPhase,
  index : Int,
  count : Int,
  include_rest : Bool,
) -> Double {
  let multiplier = phase_load_multiplier(phase)
  if include_rest && index % 5 == 4 {
    0.0
  } else if count == 0 {
    0.0
  } else {
    base * multiplier / (count - count / 5).max(1).to_double()
  }
}

///|
pub fn plan_block(
  name : String,
  start_date : String,
  base_daily_load : Double,
  day_count : Int,
  phase : PlanPhase,
  maximum_change_percent : Double,
  include_rest : Bool,
) -> BlockPlan {
  let count = day_count.max(0)
  let days = []
  let cap = base_daily_load.max(0.0) *
    (1.0 + maximum_change_percent / 100.0).max(0.0)
  for index in 0..<count {
    let day_phase = if phase == Base {
      block_phase_for_index(index, count)
    } else {
      phase
    }
    let target = block_target_for_day(
      base_daily_load.max(0.0),
      day_phase,
      index,
      count,
      include_rest,
    ).min(cap)
    let rest = target == 0.0
    days.push({
      date: block_day_date(start_date, index),
      target_load: target,
      target_intensity: if rest {
        0.0
      } else if day_phase == Peak {
        7.0
      } else {
        5.0
      },
      rest,
      phase: day_phase,
      cap_reason: if target == cap {
        "daily cap applied"
      } else if rest {
        "planned recovery day"
      } else {
        "phase target"
      },
      review_required: target == cap || day_phase == Peak,
    })
  }
  let total = total_load_values(days.map(day => day.target_load))
  let maximum = maximum_load_values(days.map(day => day.target_load))
  let reviews = days.filter(day => day.review_required).length()
  {
    name,
    start_date,
    days,
    target_total_load: total,
    maximum_day_load: maximum,
    rest_days: days.filter(day => day.rest).length(),
    review_days: reviews,
    safe: maximum <= cap && maximum_change_percent <= 10.0,
    recommendation: if maximum_change_percent > 10.0 {
      "reduce requested block increase"
    } else if reviews > 0 {
      "review capped and peak days"
    } else {
      "block is ready for execution"
    },
  }
}

///|
pub fn block_plan_from_policy(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  name : String,
  start_date : String,
  day_count : Int,
) -> BlockPlan {
  let block = summarize_load_window(records, policy.chronic_window)
  plan_block(
    name,
    start_date,
    block.average_load.max(0.0),
    day_count,
    Base,
    10.0,
    true,
  )
}

///|
pub fn block_plan_targets(plan : BlockPlan) -> Array[TrainingTarget] {
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
        SessionKind::Recovery
      } else {
        SessionKind::Mixed
      },
      day.rest,
    )
  })
}

///|
pub fn block_plan_day(plan : BlockPlan, date : String) -> BlockPlanDay? {
  for day in plan.days {
    if day.date == date {
      return Some(day)
    }
  }
  None
}

///|
pub fn block_plan_rest_dates(plan : BlockPlan) -> Array[String] {
  plan.days.filter(day => day.rest).map(day => day.date)
}

///|
pub fn block_plan_review_dates(plan : BlockPlan) -> Array[String] {
  plan.days.filter(day => day.review_required).map(day => day.date)
}

///|
pub fn block_plan_phase_dates(
  plan : BlockPlan,
  phase : PlanPhase,
) -> Array[String] {
  plan.days.filter(day => day.phase == phase).map(day => day.date)
}

///|
pub fn block_plan_loads(plan : BlockPlan) -> Array[Double] {
  plan.days.map(day => day.target_load)
}

///|
pub fn block_plan_intensities(plan : BlockPlan) -> Array[Double] {
  plan.days.map(day => day.target_intensity)
}

///|
pub fn block_plan_monotony(plan : BlockPlan) -> Double {
  workload_monotony(block_plan_loads(plan))
}

///|
pub fn block_plan_strain(plan : BlockPlan) -> Double {
  workload_strain(block_plan_loads(plan))
}

///|
pub fn block_plan_completion(
  plan : BlockPlan,
  records : Array[DailyRecord],
) -> Double {
  adherence_report(block_plan_targets(plan), records, 60.0).adherence_percent
}

///|
pub fn block_plan_actual_load(
  plan : BlockPlan,
  records : Array[DailyRecord],
) -> Double {
  total_load_values(
    training_loads(
      records_in_date_range(records, {
        start: parse_date(plan.start_date).unwrap(),
        end: parse_date(plan.days[plan.days.length() - 1].date).unwrap(),
      }),
    ),
  )
}

///|
pub fn block_plan_variance(
  plan : BlockPlan,
  records : Array[DailyRecord],
) -> Double {
  percentage_change(
    plan.target_total_load,
    block_plan_actual_load(plan, records),
  )
}

///|
pub fn block_plan_is_balanced(plan : BlockPlan) -> Bool {
  plan.rest_days > 0 &&
  block_plan_monotony(plan) < 2.0 &&
  plan.maximum_day_load >= 0.0
}

///|
pub fn block_plan_needs_review(plan : BlockPlan) -> Bool {
  !plan.safe || plan.review_days > 0 || !block_plan_is_balanced(plan)
}

///|
pub fn block_plan_next_action(plan : BlockPlan) -> String {
  if !plan.safe {
    "reduce block load cap"
  } else if plan.review_days > 0 {
    "review marked checkpoint days"
  } else if plan.rest_days == 0 {
    "insert a recovery day"
  } else {
    "execute block and monitor"
  }
}

///|
pub fn block_plan_text(plan : BlockPlan) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "name=" +
    plan.name +
    " start=" +
    plan.start_date +
    " days=" +
    plan.days.length().to_string() +
    " target_load=" +
    plan.target_total_load.to_string() +
    " max_day=" +
    plan.maximum_day_load.to_string() +
    " rest_days=" +
    plan.rest_days.to_string() +
    " review_days=" +
    plan.review_days.to_string() +
    " safe=" +
    plan.safe.to_string() +
    " action=" +
    block_plan_next_action(plan),
  )
  for day in plan.days {
    builder.write_string(
      "\n" +
      day.date +
      " load=" +
      day.target_load.to_string() +
      " intensity=" +
      day.target_intensity.to_string() +
      " phase=" +
      plan_phase_name(day.phase) +
      " rest=" +
      day.rest.to_string(),
    )
  }
  builder.to_string()
}

///|
pub fn block_plan_csv_header() -> String {
  "date,target_load,target_intensity,rest,phase,cap_reason,review_required"
}

///|
pub fn block_plan_day_csv(day : BlockPlanDay) -> String {
  day.date +
  "," +
  day.target_load.to_string() +
  "," +
  day.target_intensity.to_string() +
  "," +
  day.rest.to_string() +
  "," +
  plan_phase_name(day.phase) +
  "," +
  day.cap_reason +
  "," +
  day.review_required.to_string()
}

///|
pub fn block_plan_csv(plan : BlockPlan) -> String {
  let builder = StringBuilder()
  builder.write_string(block_plan_csv_header())
  for day in plan.days {
    builder.write_string("\n")
    builder.write_string(block_plan_day_csv(day))
  }
  builder.to_string()
}

///|
pub fn block_plan_valid(plan : BlockPlan) -> Bool {
  plan.name != "" &&
  plan.start_date != "" &&
  plan.target_total_load >= 0.0 &&
  plan.maximum_day_load >= 0.0 &&
  plan.rest_days >= 0 &&
  plan.review_days >= 0 &&
  plan.days.all(day => {
    day.date != "" &&
    day.target_load >= 0.0 &&
    day.target_intensity >= 0.0 &&
    day.target_intensity <= 10.0
  })
}
