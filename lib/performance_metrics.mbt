///|
/// Operational performance measures used to monitor pipeline behavior.
pub(all) struct PerformanceSnapshot {
  record_count : Int
  session_count : Int
  assessment_count : Int
  alert_count : Int
  event_count : Int
  intervention_count : Int
  quality_score : Double
  coverage_percent : Double
  risk_mean : Double
  readiness_mean : Double
  load_mean : Double
  recovery_mean : Double
  processing_units : Int
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PerformanceComparison {
  left_units : Int
  right_units : Int
  unit_change_percent : Double
  left_alerts : Int
  right_alerts : Int
  alert_change : Int
  left_risk : Double
  right_risk : Double
  risk_change : Double
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
pub fn performance_snapshot(
  records : Array[DailyRecord],
  sessions : Array[TrainingSession],
  run : DecisionRun,
) -> PerformanceSnapshot {
  let assessments = run.monitoring.monitors
    .filter(monitor => monitor.assessment is Some(_))
    .length()
  let risks = run.monitoring.monitors.map(monitor => {
    match monitor.assessment {
      Some(value) => value.risk_score
      None => 0.0
    }
  })
  let readiness = run.monitoring.monitors.map(monitor => {
    match monitor.assessment {
      Some(value) => value.readiness_score
      None => 0.0
    }
  })
  let load = run.monitoring.monitors.map(monitor => {
    match monitor.assessment {
      Some(value) => value.load.average_load
      None => 0.0
    }
  })
  let recovery = run.monitoring.monitors.map(monitor => {
    match monitor.assessment {
      Some(value) => value.recovery.recovery_score
      None => 0.0
    }
  })
  {
    record_count: records.length(),
    session_count: sessions.length(),
    assessment_count: assessments,
    alert_count: run.monitoring.summary.alert_count,
    event_count: run.events.events.length(),
    intervention_count: decision_run_intervention_count(run),
    quality_score: run.quality.report.score,
    coverage_percent: run.quality.report.record_count.to_double() /
    records.length().max(1).to_double() *
    100.0,
    risk_mean: mean_load_values(risks),
    readiness_mean: mean_load_values(readiness),
    load_mean: mean_load_values(load),
    recovery_mean: mean_load_values(recovery),
    processing_units: records.length() + sessions.length() + assessments,
    status: run.status,
  }
}

///|
pub fn performance_throughput(snapshot : PerformanceSnapshot) -> Double {
  if snapshot.processing_units <= 0 {
    0.0
  } else {
    snapshot.record_count.to_double() / snapshot.processing_units.to_double()
  }
}

///|
pub fn performance_alert_rate(snapshot : PerformanceSnapshot) -> Double {
  if snapshot.record_count == 0 {
    0.0
  } else {
    snapshot.alert_count.to_double() / snapshot.record_count.to_double() * 100.0
  }
}

///|
pub fn performance_event_rate(snapshot : PerformanceSnapshot) -> Double {
  if snapshot.record_count == 0 {
    0.0
  } else {
    snapshot.event_count.to_double() / snapshot.record_count.to_double() * 100.0
  }
}

///|
pub fn performance_intervention_rate(snapshot : PerformanceSnapshot) -> Double {
  if snapshot.assessment_count == 0 {
    0.0
  } else {
    snapshot.intervention_count.to_double() /
    snapshot.assessment_count.to_double() *
    100.0
  }
}

///|
pub fn performance_action_density(snapshot : PerformanceSnapshot) -> Double {
  (
    performance_alert_rate(snapshot) +
    performance_event_rate(snapshot) +
    performance_intervention_rate(snapshot)
  ) /
  3.0
}

///|
pub fn performance_quality_ready(snapshot : PerformanceSnapshot) -> Bool {
  snapshot.quality_score >= 80.0 && snapshot.coverage_percent >= 80.0
}

///|
pub fn performance_stable(snapshot : PerformanceSnapshot) -> Bool {
  snapshot.status == "accepted" || snapshot.status == "stable"
}

///|
pub fn performance_score(snapshot : PerformanceSnapshot) -> Double {
  let data = snapshot.quality_score * 0.35 +
    snapshot.coverage_percent * 0.25 +
    (100.0 - performance_action_density(snapshot).min(100.0)) * 0.20 +
    (if performance_stable(snapshot) { 20.0 } else { 0.0 })
  data.min(100.0).max(0.0)
}

///|
pub fn compare_performance(
  left : PerformanceSnapshot,
  right : PerformanceSnapshot,
) -> PerformanceComparison {
  {
    left_units: left.processing_units,
    right_units: right.processing_units,
    unit_change_percent: percentage_change(
      left.processing_units.to_double(),
      right.processing_units.to_double(),
    ),
    left_alerts: left.alert_count,
    right_alerts: right.alert_count,
    alert_change: right.alert_count - left.alert_count,
    left_risk: left.risk_mean,
    right_risk: right.risk_mean,
    risk_change: right.risk_mean - left.risk_mean,
    conclusion: if right.risk_mean < left.risk_mean &&
      right.quality_score >= left.quality_score {
      "quality and risk improved"
    } else if right.risk_mean > left.risk_mean {
      "risk increased"
    } else {
      "performance changes are mixed"
    },
  }
}

///|
pub fn performance_recommendation(snapshot : PerformanceSnapshot) -> String {
  if !performance_quality_ready(snapshot) {
    "improve data coverage and quality"
  } else if snapshot.status == "critical" {
    "route critical decisions for review"
  } else if performance_action_density(snapshot) > 50.0 {
    "reduce operational load and inspect intervention follow-up"
  } else {
    "continue the current pipeline cadence"
  }
}

///|
pub fn performance_text(snapshot : PerformanceSnapshot) -> String {
  "status=" +
  snapshot.status +
  " records=" +
  snapshot.record_count.to_string() +
  " sessions=" +
  snapshot.session_count.to_string() +
  " assessments=" +
  snapshot.assessment_count.to_string() +
  " alerts=" +
  snapshot.alert_count.to_string() +
  " events=" +
  snapshot.event_count.to_string() +
  " interventions=" +
  snapshot.intervention_count.to_string() +
  " quality=" +
  snapshot.quality_score.to_string() +
  " coverage=" +
  snapshot.coverage_percent.to_string() +
  "% score=" +
  performance_score(snapshot).to_string() +
  " recommendation=" +
  performance_recommendation(snapshot)
}

///|
pub fn performance_snapshot_csv_header() -> String {
  "record_count,session_count,assessment_count,alert_count,event_count,intervention_count,quality_score,coverage_percent,risk_mean,readiness_mean,load_mean,recovery_mean,processing_units,status"
}

///|
pub fn performance_snapshot_csv(snapshot : PerformanceSnapshot) -> String {
  snapshot.record_count.to_string() +
  "," +
  snapshot.session_count.to_string() +
  "," +
  snapshot.assessment_count.to_string() +
  "," +
  snapshot.alert_count.to_string() +
  "," +
  snapshot.event_count.to_string() +
  "," +
  snapshot.intervention_count.to_string() +
  "," +
  snapshot.quality_score.to_string() +
  "," +
  snapshot.coverage_percent.to_string() +
  "," +
  snapshot.risk_mean.to_string() +
  "," +
  snapshot.readiness_mean.to_string() +
  "," +
  snapshot.load_mean.to_string() +
  "," +
  snapshot.recovery_mean.to_string() +
  "," +
  snapshot.processing_units.to_string() +
  "," +
  snapshot.status
}

///|
pub fn performance_snapshot_valid(snapshot : PerformanceSnapshot) -> Bool {
  snapshot.record_count >= 0 &&
  snapshot.session_count >= 0 &&
  snapshot.assessment_count >= 0 &&
  snapshot.alert_count >= 0 &&
  snapshot.event_count >= 0 &&
  snapshot.intervention_count >= 0 &&
  snapshot.quality_score >= 0.0 &&
  snapshot.quality_score <= 100.0 &&
  snapshot.coverage_percent >= 0.0 &&
  snapshot.coverage_percent <= 100.0 &&
  snapshot.processing_units >= 0
}
