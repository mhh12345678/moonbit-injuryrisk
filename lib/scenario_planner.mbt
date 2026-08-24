///|
/// What-if planning across load, recovery, and progression constraints.
pub(all) enum ScenarioIntent {
  ScenarioMaintain
  ScenarioProgress
  ScenarioDeload
  ScenarioReturn
  ScenarioCompetition
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ScenarioInput {
  name : String
  intent : ScenarioIntent
  days : Int
  load_change_percent : Double
  intensity_change : Double
  recovery_score : Double
  sleep_hours : Double
  pain_level : Double
  include_recovery_day : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ScenarioDay {
  day_index : Int
  planned_load : Double
  planned_intensity : Double
  recovery_score : Double
  readiness_score : Double
  risk_score : Double
  safe : Bool
  note : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ScenarioResult {
  input : ScenarioInput
  days : Array[ScenarioDay]
  average_load : Double
  peak_load : Double
  minimum_readiness : Double
  maximum_risk : Double
  safe_day_count : Int
  safe : Bool
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub fn scenario_intent_name(intent : ScenarioIntent) -> String {
  match intent {
    ScenarioMaintain => "maintain"
    ScenarioProgress => "progress"
    ScenarioDeload => "deload"
    ScenarioReturn => "return"
    ScenarioCompetition => "competition"
  }
}

///|
pub fn scenario_input(
  name : String,
  intent : ScenarioIntent,
  days : Int,
  load_change_percent : Double,
  intensity_change : Double,
  recovery_score : Double,
  sleep_hours : Double,
  pain_level : Double,
  include_recovery_day : Bool,
) -> ScenarioInput {
  {
    name,
    intent,
    days: days.max(0),
    load_change_percent,
    intensity_change,
    recovery_score,
    sleep_hours,
    pain_level,
    include_recovery_day,
  }
}

///|
fn scenario_base_load(summary : LoadModelSummary) -> Double {
  if summary.points.length() == 0 {
    0.0
  } else {
    summary.points[summary.points.length() - 1].modeled_load
  }
}

///|
fn scenario_recovery(input : ScenarioInput, day : Int) -> Double {
  let recovery = input.recovery_score + (day.to_double() * 1.5).min(10.0)
  let sleep_effect = (input.sleep_hours - 7.0) * 4.0
  (recovery + sleep_effect - input.pain_level * 4.0).min(100.0).max(0.0)
}

///|
fn scenario_load(input : ScenarioInput, base : Double, day : Int) -> Double {
  let progress = if input.days <= 1 {
    0.0
  } else {
    day.to_double() / (input.days - 1).to_double()
  }
  let change = input.load_change_percent / 100.0 * progress
  let intensity = (1.0 + input.intensity_change / 10.0).max(0.0)
  if input.include_recovery_day && day % 5 == 4 {
    0.0
  } else {
    base * (1.0 + change).max(0.0) * intensity
  }
}

///|
fn scenario_readiness(
  load : Double,
  base : Double,
  recovery : Double,
  pain : Double,
) -> Double {
  let load_penalty = if base <= 0.0 {
    0.0
  } else {
    (load / base - 1.0).max(0.0) * 45.0
  }
  (recovery - load_penalty - pain * 5.0).min(100.0).max(0.0)
}

///|
fn scenario_risk(
  load : Double,
  base : Double,
  readiness : Double,
  pain : Double,
) -> Double {
  let ratio = if base <= 0.0 {
    if load == 0.0 {
      0.0
    } else {
      100.0
    }
  } else {
    load / base
  }
  ((ratio - 1.0).max(0.0) * 80.0 + (100.0 - readiness) * 0.5 + pain * 5.0).min(
    100.0,
  )
}

///|
pub fn run_scenario(
  summary : LoadModelSummary,
  input : ScenarioInput,
  maximum_risk : Double,
) -> ScenarioResult {
  let base = scenario_base_load(summary)
  let days = []
  for index in 0..<input.days {
    let load = scenario_load(input, base, index)
    let recovery = scenario_recovery(input, index)
    let readiness = scenario_readiness(load, base, recovery, input.pain_level)
    let risk = scenario_risk(load, base, readiness, input.pain_level)
    let safe = risk <= maximum_risk && readiness >= 60.0
    days.push({
      day_index: index,
      planned_load: load,
      planned_intensity: (5.0 + input.intensity_change).min(10.0).max(0.0),
      recovery_score: recovery,
      readiness_score: readiness,
      risk_score: risk,
      safe,
      note: if safe {
        "within scenario guardrails"
      } else {
        "requires load or recovery adjustment"
      },
    })
  }
  let loads = days.map(day => day.planned_load)
  let readiness = days.map(day => day.readiness_score)
  let risks = days.map(day => day.risk_score)
  let safe = days.filter(day => day.safe).length()
  {
    input,
    days,
    average_load: mean_load_values(loads),
    peak_load: maximum_load_values(loads),
    minimum_readiness: minimum_load_values(readiness),
    maximum_risk: maximum_load_values(risks),
    safe_day_count: safe,
    safe: safe == days.length(),
    recommendation: if safe == days.length() {
      "scenario can be considered for scheduling"
    } else {
      "reduce planned load or increase recovery margin"
    },
  }
}

///|
pub fn default_scenario_set() -> Array[ScenarioInput] {
  [
    scenario_input(
      "maintain",
      ScenarioMaintain,
      7,
      0.0,
      0.0,
      75.0,
      8.0,
      1.0,
      true,
    ),
    scenario_input(
      "progress",
      ScenarioProgress,
      7,
      10.0,
      0.3,
      75.0,
      8.0,
      1.0,
      true,
    ),
    scenario_input(
      "deload",
      ScenarioDeload,
      7,
      -30.0,
      -1.0,
      70.0,
      8.0,
      1.0,
      true,
    ),
    scenario_input(
      "return",
      ScenarioReturn,
      10,
      -50.0,
      -2.0,
      80.0,
      8.0,
      0.0,
      true,
    ),
    scenario_input(
      "competition",
      ScenarioCompetition,
      5,
      12.0,
      1.0,
      80.0,
      8.0,
      0.0,
      false,
    ),
  ]
}

///|
pub fn compare_scenarios(
  summary : LoadModelSummary,
  inputs : Array[ScenarioInput],
  maximum_risk : Double,
) -> Array[ScenarioResult] {
  inputs.map(input => run_scenario(summary, input, maximum_risk))
}

///|
pub fn safe_scenario_results(
  results : Array[ScenarioResult],
) -> Array[ScenarioResult] {
  results.filter(result => result.safe)
}

///|
pub fn unsafe_scenario_results(
  results : Array[ScenarioResult],
) -> Array[ScenarioResult] {
  results.filter(result => !result.safe)
}

///|
pub fn best_scenario(results : Array[ScenarioResult]) -> ScenarioResult? {
  let safe = safe_scenario_results(results)
  if safe.length() == 0 {
    return None
  }
  let mut best = safe[0]
  for result in safe {
    if result.average_load > best.average_load &&
      result.maximum_risk <= best.maximum_risk {
      best = result
    }
  }
  Some(best)
}

///|
pub fn scenario_result_for_name(
  results : Array[ScenarioResult],
  name : String,
) -> ScenarioResult? {
  for result in results {
    if result.input.name == name {
      return Some(result)
    }
  }
  None
}

///|
pub fn scenario_safe_percent(result : ScenarioResult) -> Double {
  if result.days.length() == 0 {
    0.0
  } else {
    result.safe_day_count.to_double() / result.days.length().to_double() * 100.0
  }
}

///|
pub fn scenario_readiness_drop(result : ScenarioResult) -> Double {
  if result.days.length() == 0 {
    0.0
  } else {
    result.days[0].readiness_score - result.minimum_readiness
  }
}

///|
pub fn scenario_risk_margin(
  result : ScenarioResult,
  maximum_risk : Double,
) -> Double {
  maximum_risk - result.maximum_risk
}

///|
pub fn scenario_load_change(result : ScenarioResult, base : Double) -> Double {
  percentage_change(base, result.average_load)
}

///|
pub fn scenario_day(result : ScenarioResult, index : Int) -> ScenarioDay? {
  if index < 0 || index >= result.days.length() {
    None
  } else {
    Some(result.days[index])
  }
}

///|
pub fn scenario_action_days(result : ScenarioResult) -> Array[Int] {
  result.days.filter(day => !day.safe).map(day => day.day_index)
}

///|
pub fn scenario_recovery_days(result : ScenarioResult) -> Array[Int] {
  result.days.filter(day => day.planned_load == 0.0).map(day => day.day_index)
}

///|
pub fn scenario_input_valid(input : ScenarioInput) -> Bool {
  input.name != "" &&
  input.days >= 0 &&
  input.recovery_score >= 0.0 &&
  input.recovery_score <= 100.0 &&
  input.sleep_hours >= 0.0 &&
  input.pain_level >= 0.0
}

///|
pub fn scenario_result_valid(result : ScenarioResult) -> Bool {
  scenario_input_valid(result.input) &&
  result.average_load >= 0.0 &&
  result.peak_load >= 0.0 &&
  result.minimum_readiness >= 0.0 &&
  result.minimum_readiness <= 100.0 &&
  result.maximum_risk >= 0.0 &&
  result.maximum_risk <= 100.0
}

///|
pub fn scenario_result_text(result : ScenarioResult) -> String {
  "name=" +
  result.input.name +
  " intent=" +
  scenario_intent_name(result.input.intent) +
  " days=" +
  result.days.length().to_string() +
  " average_load=" +
  result.average_load.to_string() +
  " peak_load=" +
  result.peak_load.to_string() +
  " minimum_readiness=" +
  result.minimum_readiness.to_string() +
  " maximum_risk=" +
  result.maximum_risk.to_string() +
  " safe=" +
  result.safe.to_string() +
  " recommendation=" +
  result.recommendation
}

///|
pub fn scenario_day_csv_header() -> String {
  "scenario,day_index,planned_load,planned_intensity,recovery_score,readiness_score,risk_score,safe,note"
}

///|
pub fn scenario_day_csv(result : ScenarioResult, day : ScenarioDay) -> String {
  result.input.name +
  "," +
  day.day_index.to_string() +
  "," +
  day.planned_load.to_string() +
  "," +
  day.planned_intensity.to_string() +
  "," +
  day.recovery_score.to_string() +
  "," +
  day.readiness_score.to_string() +
  "," +
  day.risk_score.to_string() +
  "," +
  day.safe.to_string() +
  "," +
  day.note
}

///|
pub fn scenario_results_csv(results : Array[ScenarioResult]) -> String {
  let builder = StringBuilder()
  builder.write_string(scenario_day_csv_header())
  for result in results {
    for day in result.days {
      builder.write_string("\n")
      builder.write_string(scenario_day_csv(result, day))
    }
  }
  builder.to_string()
}
