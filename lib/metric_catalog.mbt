///|
/// Metadata for a metric exposed by the rule engine.
pub(all) struct MetricDescription {
  metric : Metric
  name : String
  unit : String
  direction : String
  default_window : Int
  explanation : String
} derive(Debug, Eq, ToJson)

///|
pub fn metric_description(metric : Metric) -> MetricDescription {
  match metric {
    AcuteLoad =>
      {
        metric,
        name: "Acute workload",
        unit: "load/day",
        direction: "lower-is-safer",
        default_window: 7,
        explanation: "mean session load in the recent acute window",
      }
    ChronicLoad =>
      {
        metric,
        name: "Chronic workload",
        unit: "load/day",
        direction: "context-dependent",
        default_window: 28,
        explanation: "mean session load in the chronic baseline window",
      }
    ACWR =>
      {
        metric,
        name: "Acute:chronic workload ratio",
        unit: "ratio",
        direction: "near-one-is-stable",
        default_window: 28,
        explanation: "acute mean load divided by chronic mean load",
      }
    SleepHours =>
      {
        metric,
        name: "Sleep duration",
        unit: "hours",
        direction: "higher-is-better",
        default_window: 7,
        explanation: "mean sleep duration in the recent window",
      }
    SleepQuality =>
      {
        metric,
        name: "Sleep quality",
        unit: "score/5",
        direction: "higher-is-better",
        default_window: 7,
        explanation: "mean subjective sleep quality",
      }
    PainLevel =>
      {
        metric,
        name: "Pain level",
        unit: "score/10",
        direction: "lower-is-better",
        default_window: 3,
        explanation: "maximum reported pain in the recent window",
      }
    FatigueLevel =>
      {
        metric,
        name: "Fatigue level",
        unit: "score/10",
        direction: "lower-is-better",
        default_window: 7,
        explanation: "mean subjective fatigue",
      }
    LoadSpike =>
      {
        metric,
        name: "Workload spike",
        unit: "percent",
        direction: "lower-is-better",
        default_window: 7,
        explanation: "acute change against the preceding week",
      }
  }
}

///|
pub fn metric_catalog() -> Array[MetricDescription] {
  [
    AcuteLoad,
    ChronicLoad,
    ACWR,
    SleepHours,
    SleepQuality,
    PainLevel,
    FatigueLevel,
    LoadSpike,
  ].map(metric => metric_description(metric))
}

///|
pub fn metric_name_public(metric : Metric) -> String {
  metric_description(metric).name
}

///|
pub fn metric_unit(metric : Metric) -> String {
  metric_description(metric).unit
}

///|
pub fn metric_default_window(metric : Metric) -> Int {
  metric_description(metric).default_window
}

///|
pub fn metric_value_at(
  records : Array[DailyRecord],
  date : String,
  metric : Metric,
) -> Double? {
  match find_record_index(records, date) {
    Some(index) =>
      Some(
        policy_metric_value(
          records,
          index,
          metric,
          metric_default_window(metric),
        ),
      )
    None => None
  }
}

///|
pub fn metric_direction_is_positive(metric : Metric, change : Double) -> Bool {
  match metric {
    SleepHours | SleepQuality => change > 0.0
    AcuteLoad | ChronicLoad | ACWR | PainLevel | FatigueLevel | LoadSpike =>
      change < 0.0
  }
}

///|
pub fn metric_catalog_text() -> String {
  let builder = StringBuilder::new()
  for description in metric_catalog() {
    builder.write_string(
      description.name +
      " [" +
      description.unit +
      "] window=" +
      description.default_window.to_string() +
      "\n",
    )
  }
  builder.to_string()
}
