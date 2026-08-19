///|
/// A named athlete data set for batch screening.
pub(all) struct AthleteSeries {
  athlete_id : String
  records : Array[DailyRecord]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct AthleteScreening {
  athlete_id : String
  assessment : ComprehensiveAssessment?
  risk_level : RiskLevel
  risk_score : Double
  readiness_score : Double
  data_quality_score : Double
} derive(Debug, Eq, ToJson)

///|
pub(all) struct CohortSummary {
  athlete_count : Int
  screened_count : Int
  high_risk_count : Int
  medium_risk_count : Int
  low_risk_count : Int
  high_risk_rate : Double
  average_risk_score : Double
  average_readiness : Double
  average_acwr : Double
  average_quality : Double
  screenings : Array[AthleteScreening]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct CohortDelta {
  risk_rate_change : Double
  readiness_change : Double
  quality_change : Double
  improved_athletes : Int
  worsened_athletes : Int
} derive(Debug, Eq, ToJson)

///|
pub fn athlete_series(
  athlete_id : String,
  records : Array[DailyRecord],
) -> AthleteSeries {
  { athlete_id, records }
}

///|
pub fn screen_athlete(
  athlete : AthleteSeries,
  policy : RiskPolicy,
) -> AthleteScreening {
  let assessment = assess_latest(athlete.records, policy)
  match assessment {
    Some(value) =>
      {
        athlete_id: athlete.athlete_id,
        assessment: Some(value),
        risk_level: value.risk_level,
        risk_score: value.risk_score,
        readiness_score: value.readiness_score,
        data_quality_score: value.quality.score,
      }
    None =>
      {
        athlete_id: athlete.athlete_id,
        assessment: None,
        risk_level: Low,
        risk_score: 0.0,
        readiness_score: 0.0,
        data_quality_score: 0.0,
      }
  }
}

///|
pub fn screen_cohort(
  athletes : Array[AthleteSeries],
  policy : RiskPolicy,
) -> Array[AthleteScreening] {
  athletes.map(athlete => screen_athlete(athlete, policy))
}

///|
pub fn summarize_cohort(
  athletes : Array[AthleteSeries],
  policy : RiskPolicy,
) -> CohortSummary {
  let screenings = screen_cohort(athletes, policy)
  let screened = screenings.filter(item => item.assessment is Some(_))
  let high = screenings.filter(item => item.risk_level == High).length()
  let medium = screenings.filter(item => item.risk_level == Medium).length()
  let low = screenings.filter(item => item.risk_level == Low).length()
  let risk_scores = screened.map(item => item.risk_score)
  let readiness_scores = screened.map(item => item.readiness_score)
  let quality_scores = screened.map(item => item.data_quality_score)
  let acwr_values = []
  for item in screened {
    match item.assessment {
      Some(assessment) => acwr_values.push(assessment.load.acwr)
      None => ()
    }
  }
  {
    athlete_count: athletes.length(),
    screened_count: screened.length(),
    high_risk_count: high,
    medium_risk_count: medium,
    low_risk_count: low,
    high_risk_rate: if screened.length() == 0 {
      0.0
    } else {
      high.to_double() / screened.length().to_double() * 100.0
    },
    average_risk_score: mean_load_values(risk_scores),
    average_readiness: mean_load_values(readiness_scores),
    average_acwr: mean_load_values(acwr_values),
    average_quality: mean_load_values(quality_scores),
    screenings,
  }
}

///|
pub fn highest_risk_athletes(
  summary : CohortSummary,
  minimum : RiskLevel,
) -> Array[AthleteScreening] {
  summary.screenings.filter(item => {
    item.risk_level.max(minimum) == item.risk_level
  })
}

///|
pub fn sort_screenings_by_risk(
  screenings : Array[AthleteScreening],
) -> Array[AthleteScreening] {
  let sorted = screenings.copy()
  for i in 1..<sorted.length() {
    let current = sorted[i]
    let mut position = i
    while position > 0 && sorted[position - 1].risk_score < current.risk_score {
      sorted[position] = sorted[position - 1]
      position -= 1
    }
    sorted[position] = current
  }
  sorted
}

///|
pub fn cohort_readiness_band(summary : CohortSummary) -> String {
  if summary.average_readiness >= 80.0 {
    "ready"
  } else if summary.average_readiness >= 60.0 {
    "mixed"
  } else {
    "depleted"
  }
}

///|
pub fn compare_cohorts(
  previous : CohortSummary,
  current : CohortSummary,
) -> CohortDelta {
  let previous_risk = previous.high_risk_rate
  let current_risk = current.high_risk_rate
  let improved = current.screenings
    .filter(current_item => {
      let previous_item = previous.screenings.filter(item => {
        item.athlete_id == current_item.athlete_id
      })
      match previous_item.get(0) {
        Some(previous_item) =>
          current_item.risk_score < previous_item.risk_score
        None => false
      }
    })
    .length()
  let worsened = current.screenings
    .filter(current_item => {
      let previous_item = previous.screenings.filter(item => {
        item.athlete_id == current_item.athlete_id
      })
      match previous_item.get(0) {
        Some(previous_item) =>
          current_item.risk_score > previous_item.risk_score
        None => false
      }
    })
    .length()
  {
    risk_rate_change: current_risk - previous_risk,
    readiness_change: current.average_readiness - previous.average_readiness,
    quality_change: current.average_quality - previous.average_quality,
    improved_athletes: improved,
    worsened_athletes: worsened,
  }
}

///|
pub fn cohort_summary_text(summary : CohortSummary) -> String {
  "athletes=" +
  summary.athlete_count.to_string() +
  " screened=" +
  summary.screened_count.to_string() +
  " high_risk_rate=" +
  summary.high_risk_rate.to_string() +
  "% readiness=" +
  summary.average_readiness.to_string() +
  " quality=" +
  summary.average_quality.to_string()
}

///|
pub fn athlete_ids_by_priority(summary : CohortSummary) -> Array[String] {
  sort_screenings_by_risk(summary.screenings).map(item => item.athlete_id)
}
