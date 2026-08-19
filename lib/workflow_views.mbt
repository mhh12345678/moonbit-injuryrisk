///|
/// Stable view models for dashboards and API responses.
pub(all) struct WorkflowView {
  run_id : String
  status : String
  latest_date : String
  risk_level : String
  risk_score : Double
  readiness : Double
  quality : Double
  alert_count : Int
  event_count : Int
  action_count : Int
  next_action : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct WorkflowTrendView {
  dates : Array[String]
  risk_scores : Array[Double]
  readiness_scores : Array[Double]
  recovery_scores : Array[Double]
  loads : Array[Double]
  action_dates : Array[String]
  trend : LoadTrend
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct WorkflowExportView {
  summary : WorkflowView
  trend : WorkflowTrendView
  manifest : String
  text : String
  valid : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn workflow_view(run : DecisionRun) -> WorkflowView {
  let latest_date = run.monitoring.generated_for
  let risk_level = match run.latest {
    Some(value) => risk_level_name(value.risk_level)
    None => "unknown"
  }
  {
    run_id: run.config.run_id,
    status: run.status,
    latest_date,
    risk_level,
    risk_score: decision_run_latest_risk(run),
    readiness: decision_run_latest_readiness(run),
    quality: run.quality.report.score,
    alert_count: decision_run_alert_count(run),
    event_count: decision_run_event_count(run),
    action_count: decision_run_action_count(run),
    next_action: decision_run_recommendation(run),
  }
}

///|
pub fn workflow_trend_view(run : DecisionRun) -> WorkflowTrendView {
  let monitors = run.monitoring.monitors
  let dates = monitors.map(monitor => monitor.date)
  let risks = monitors.map(monitor => {
    match monitor.assessment {
      Some(value) => value.risk_score
      None => 0.0
    }
  })
  let readiness = monitors.map(monitor => {
    match monitor.assessment {
      Some(value) => value.readiness_score
      None => 0.0
    }
  })
  let recovery = monitors.map(monitor => {
    match monitor.assessment {
      Some(value) => value.recovery.recovery_score
      None => 0.0
    }
  })
  let loads = monitors.map(monitor => {
    match monitor.assessment {
      Some(value) => value.load.average_load
      None => 0.0
    }
  })
  {
    dates,
    risk_scores: risks,
    readiness_scores: readiness,
    recovery_scores: recovery,
    loads,
    action_dates: monitoring_action_dates(run.monitoring),
    trend: load_trend(risks, 0.1),
    status: if monitoring_requires_review(run.monitoring) {
      "review"
    } else {
      "stable"
    },
  }
}

///|
pub fn workflow_export_view(run : DecisionRun) -> WorkflowExportView {
  let bundle = decision_run_export(run)
  {
    summary: workflow_view(run),
    trend: workflow_trend_view(run),
    manifest: export_bundle_manifest(bundle),
    text: export_bundle_text(bundle),
    valid: export_bundle_valid(bundle),
  }
}

///|
pub fn workflow_view_status(view : WorkflowView) -> String {
  if view.status == "critical" || view.status == "quality_rejected" {
    "red"
  } else if view.status == "action_required" || view.status == "review" {
    "amber"
  } else if view.status == "accepted" {
    "green"
  } else {
    "grey"
  }
}

///|
pub fn workflow_view_requires_action(view : WorkflowView) -> Bool {
  view.action_count > 0 || view.status == "critical" || view.quality < 80.0
}

///|
pub fn workflow_view_is_ready(view : WorkflowView) -> Bool {
  view.status == "accepted" && view.quality >= 80.0 && view.action_count == 0
}

///|
pub fn workflow_trend_latest_risk(view : WorkflowTrendView) -> Double {
  if view.risk_scores.length() == 0 {
    0.0
  } else {
    view.risk_scores[view.risk_scores.length() - 1]
  }
}

///|
pub fn workflow_trend_peak_risk(view : WorkflowTrendView) -> Double {
  maximum_load_values(view.risk_scores)
}

///|
pub fn workflow_trend_min_readiness(view : WorkflowTrendView) -> Double {
  minimum_load_values(view.readiness_scores)
}

///|
pub fn workflow_trend_average_load(view : WorkflowTrendView) -> Double {
  mean_load_values(view.loads)
}

///|
pub fn workflow_trend_days(view : WorkflowTrendView) -> Int {
  view.dates.length()
}

///|
pub fn workflow_trend_action_ratio(view : WorkflowTrendView) -> Double {
  if view.dates.length() == 0 {
    0.0
  } else {
    view.action_dates.length().to_double() / view.dates.length().to_double()
  }
}

///|
pub fn workflow_trend_is_improving(view : WorkflowTrendView) -> Bool {
  view.trend is Rising
}

///|
pub fn workflow_trend_is_worsening(view : WorkflowTrendView) -> Bool {
  view.trend is Falling
}

///|
pub fn workflow_view_text(view : WorkflowView) -> String {
  "run=" +
  view.run_id +
  " status=" +
  view.status +
  " latest=" +
  view.latest_date +
  " risk_level=" +
  view.risk_level +
  " risk=" +
  view.risk_score.to_string() +
  " readiness=" +
  view.readiness.to_string() +
  " quality=" +
  view.quality.to_string() +
  " alerts=" +
  view.alert_count.to_string() +
  " events=" +
  view.event_count.to_string() +
  " actions=" +
  view.action_count.to_string() +
  " next=" +
  view.next_action
}

///|
pub fn workflow_trend_text(view : WorkflowTrendView) -> String {
  "days=" +
  workflow_trend_days(view).to_string() +
  " peak_risk=" +
  workflow_trend_peak_risk(view).to_string() +
  " minimum_readiness=" +
  workflow_trend_min_readiness(view).to_string() +
  " average_load=" +
  workflow_trend_average_load(view).to_string() +
  " action_ratio=" +
  workflow_trend_action_ratio(view).to_string() +
  " trend=" +
  load_trend_label(view.trend) +
  " status=" +
  view.status
}

///|
fn load_trend_label(trend : LoadTrend) -> String {
  match trend {
    Rising => "rising"
    Stable => "stable"
    Falling => "falling"
    Volatile => "volatile"
    InsufficientData => "insufficient_data"
  }
}

///|
pub fn workflow_view_csv_header() -> String {
  "run_id,status,latest_date,risk_level,risk_score,readiness,quality,alert_count,event_count,action_count,next_action"
}

///|
pub fn workflow_view_csv(view : WorkflowView) -> String {
  view.run_id +
  "," +
  view.status +
  "," +
  view.latest_date +
  "," +
  view.risk_level +
  "," +
  view.risk_score.to_string() +
  "," +
  view.readiness.to_string() +
  "," +
  view.quality.to_string() +
  "," +
  view.alert_count.to_string() +
  "," +
  view.event_count.to_string() +
  "," +
  view.action_count.to_string() +
  "," +
  view.next_action
}

///|
pub fn workflow_trend_csv_header() -> String {
  "date,risk_score,readiness_score,recovery_score,load,action"
}

///|
pub fn workflow_trend_csv(view : WorkflowTrendView) -> String {
  let builder = StringBuilder::new()
  builder.write_string(workflow_trend_csv_header())
  for index in 0..<view.dates.length() {
    let action = view.action_dates.contains(view.dates[index])
    builder.write_string(
      "\n" +
      view.dates[index] +
      "," +
      view.risk_scores[index].to_string() +
      "," +
      view.readiness_scores[index].to_string() +
      "," +
      view.recovery_scores[index].to_string() +
      "," +
      view.loads[index].to_string() +
      "," +
      action.to_string(),
    )
  }
  builder.to_string()
}

///|
pub fn workflow_view_valid(view : WorkflowView) -> Bool {
  view.run_id != "" &&
  view.latest_date != "" &&
  view.risk_score >= 0.0 &&
  view.risk_score <= 100.0 &&
  view.readiness >= 0.0 &&
  view.readiness <= 100.0 &&
  view.quality >= 0.0 &&
  view.quality <= 100.0 &&
  view.alert_count >= 0 &&
  view.event_count >= 0 &&
  view.action_count >= 0
}

///|
pub fn workflow_trend_valid(view : WorkflowTrendView) -> Bool {
  view.dates.length() == view.risk_scores.length() &&
  view.dates.length() == view.readiness_scores.length() &&
  view.dates.length() == view.recovery_scores.length() &&
  view.dates.length() == view.loads.length() &&
  view.risk_scores.all(value => value >= 0.0 && value <= 100.0) &&
  view.readiness_scores.all(value => value >= 0.0 && value <= 100.0)
}
