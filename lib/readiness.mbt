///|
/// Readiness status for an individual training day.
pub(all) enum ReadinessBand {
  Green
  Amber
  Red
  Unknown
} derive(Debug, Eq, ToJson)

///|
pub(all) enum ReadinessComponentKind {
  Sleep
  Fatigue
  Pain
  Load
  Consistency
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ReadinessComponent {
  kind : ReadinessComponentKind
  score : Double
  weight : Double
  evidence : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ReadinessSnapshot {
  date : String
  score : Double
  band : ReadinessBand
  components : Array[ReadinessComponent]
  suggestion : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ReadinessSummary {
  average_score : Double
  minimum_score : Double
  maximum_score : Double
  green_days : Int
  amber_days : Int
  red_days : Int
  trend : TrendSummary
  latest : ReadinessSnapshot?
} derive(Debug, Eq, ToJson)

///|
pub fn readiness_band(score : Double) -> ReadinessBand {
  if score >= 75.0 {
    Green
  } else if score >= 50.0 {
    Amber
  } else if score >= 0.0 {
    Red
  } else {
    Unknown
  }
}

///|
pub fn readiness_band_name(band : ReadinessBand) -> String {
  match band {
    Green => "green"
    Amber => "amber"
    Red => "red"
    Unknown => "unknown"
  }
}

///|
pub fn readiness_component_name(kind : ReadinessComponentKind) -> String {
  match kind {
    Sleep => "sleep"
    Fatigue => "fatigue"
    Pain => "pain"
    Load => "load"
    Consistency => "consistency"
  }
}

///|
pub fn readiness_suggestion(band : ReadinessBand) -> String {
  match band {
    Green =>
      "normal progression is appropriate when technique and symptoms remain stable"
    Amber =>
      "keep intensity moderate and reassess recovery before adding volume"
    Red =>
      "use recovery or low-load movement and review symptoms before training"
    Unknown =>
      "collect more complete telemetry before making a training decision"
  }
}

///|
pub fn readiness_for_record(
  record : DailyRecord,
  recent_load : Double,
  baseline_load : Double,
  target_sleep : Double,
) -> ReadinessSnapshot {
  let sleep = sleep_score(record.sleep_hours, target_sleep) * 100.0
  let fatigue = fatigue_score(record.fatigue, 10.0) * 100.0
  let pain = pain_score(record.pain_level, 10.0) * 100.0
  let load = if baseline_load <= 0.0 {
    if recent_load == 0.0 {
      100.0
    } else {
      40.0
    }
  } else {
    (100.0 - (recent_load / baseline_load - 1.0).abs() * 100.0).max(0.0)
  }
  let consistency = if record.sleep_quality >= 3.0 {
    100.0
  } else {
    record.sleep_quality / 3.0 * 100.0
  }
  let components = [
    {
      kind: Sleep,
      score: sleep,
      weight: 0.30,
      evidence: "sleep=" + record.sleep_hours.to_string(),
    },
    {
      kind: Fatigue,
      score: fatigue,
      weight: 0.25,
      evidence: "fatigue=" + record.fatigue.to_string(),
    },
    {
      kind: Pain,
      score: pain,
      weight: 0.25,
      evidence: "pain=" + record.pain_level.to_string(),
    },
    {
      kind: Load,
      score: load,
      weight: 0.15,
      evidence: "recent_load=" + recent_load.to_string(),
    },
    {
      kind: Consistency,
      score: consistency,
      weight: 0.05,
      evidence: "sleep_quality=" + record.sleep_quality.to_string(),
    },
  ]
  let mut total = 0.0
  let mut weight = 0.0
  for component in components {
    total += component.score * component.weight
    weight += component.weight
  }
  let score = if weight == 0.0 { 0.0 } else { total / weight }
  let band = readiness_band(score)
  {
    date: record.date,
    score,
    band,
    components,
    suggestion: readiness_suggestion(band),
  }
}

///|
pub fn readiness_history(
  records : Array[DailyRecord],
  window_size : Int,
  target_sleep : Double,
) -> Array[ReadinessSnapshot] {
  let snapshots = []
  for index, record in records {
    let recent = chronic_load_average(records, index, window_size)
    let baseline_end = index - window_size
    let baseline = if baseline_end < 0 {
      recent
    } else {
      chronic_load_average(records, baseline_end, window_size)
    }
    snapshots.push(readiness_for_record(record, recent, baseline, target_sleep))
  }
  snapshots
}

///|
pub fn readiness_scores(snapshots : Array[ReadinessSnapshot]) -> Array[Double] {
  snapshots.map(snapshot => snapshot.score)
}

///|
pub fn summarize_readiness(
  snapshots : Array[ReadinessSnapshot],
) -> ReadinessSummary {
  let scores = readiness_scores(snapshots)
  {
    average_score: mean_load_values(scores),
    minimum_score: minimum_load_values(scores),
    maximum_score: maximum_load_values(scores),
    green_days: snapshots.filter(snapshot => snapshot.band == Green).length(),
    amber_days: snapshots.filter(snapshot => snapshot.band == Amber).length(),
    red_days: snapshots.filter(snapshot => snapshot.band == Red).length(),
    trend: summarize_trend(scores, 0.5, 2),
    latest: if snapshots.length() == 0 {
      None
    } else {
      Some(snapshots[snapshots.length() - 1])
    },
  }
}

///|
pub fn readiness_alerts(
  snapshots : Array[ReadinessSnapshot],
) -> Array[ReadinessSnapshot] {
  snapshots.filter(snapshot => snapshot.band == Red)
}

///|
pub fn stable_readiness_streak(
  snapshots : Array[ReadinessSnapshot],
  band : ReadinessBand,
) -> Int {
  let mut longest = 0
  let mut current = 0
  for snapshot in snapshots {
    if snapshot.band == band {
      current += 1
      longest = longest.max(current)
    } else {
      current = 0
    }
  }
  longest
}

///|
pub fn readiness_summary_text(summary : ReadinessSummary) -> String {
  "average=" +
  summary.average_score.to_string() +
  " min=" +
  summary.minimum_score.to_string() +
  " max=" +
  summary.maximum_score.to_string() +
  " green=" +
  summary.green_days.to_string() +
  " amber=" +
  summary.amber_days.to_string() +
  " red=" +
  summary.red_days.to_string() +
  " trend=" +
  trend_direction_name(summary.trend.direction)
}
