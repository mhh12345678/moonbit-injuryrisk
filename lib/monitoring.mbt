///|
/// Thresholds used by the daily operational monitor.
pub(all) struct MonitoringThresholds {
  high_risk_score : Double
  medium_risk_score : Double
  minimum_readiness : Double
  maximum_pain : Double
  maximum_acwr : Double
  minimum_sleep_hours : Double
  maximum_fatigue : Double
  quality_floor : Double
  consecutive_days : Int
} derive(Debug, Eq, ToJson)

///|
pub fn default_monitoring_thresholds() -> MonitoringThresholds {
  {
    high_risk_score: 70.0,
    medium_risk_score: 40.0,
    minimum_readiness: 65.0,
    maximum_pain: 5.0,
    maximum_acwr: 1.5,
    minimum_sleep_hours: 7.0,
    maximum_fatigue: 7.0,
    quality_floor: 80.0,
    consecutive_days: 3,
  }
}

///|
pub(all) enum MonitorAlertKind {
  RiskScore
  Readiness
  Pain
  LoadRatio
  Sleep
  Fatigue
  Quality
  TrainingStreak
  MissingTelemetry
  DataConflict
} derive(Debug, Eq, ToJson)

///|
pub(all) enum MonitorAlertSeverity {
  Info
  Watch
  Action
  Escalate
} derive(Debug, Eq, ToJson)

///|
pub(all) struct MonitoringAlert {
  id : String
  date : String
  kind : MonitorAlertKind
  severity : MonitorAlertSeverity
  value : Double
  threshold : Double
  title : String
  explanation : String
  recommended_action : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct DailyMonitor {
  date : String
  assessment : ComprehensiveAssessment?
  alerts : Array[MonitoringAlert]
  alert_score : Double
  actionable : Bool
  data_complete : Bool
  next_review : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct MonitoringSummary {
  day_count : Int
  alert_count : Int
  actionable_day_count : Int
  escalation_count : Int
  average_alert_score : Double
  highest_alert_date : String?
  highest_alert_score : Double
  data_complete_percent : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct MonitoringRun {
  monitors : Array[DailyMonitor]
  summary : MonitoringSummary
  thresholds : MonitoringThresholds
  generated_for : String
} derive(Debug, Eq, ToJson)

///|
pub fn monitor_alert_kind_name(kind : MonitorAlertKind) -> String {
  match kind {
    RiskScore => "risk_score"
    Readiness => "readiness"
    Pain => "pain"
    LoadRatio => "load_ratio"
    Sleep => "sleep"
    Fatigue => "fatigue"
    Quality => "quality"
    TrainingStreak => "training_streak"
    MissingTelemetry => "missing_telemetry"
    DataConflict => "data_conflict"
  }
}

///|
pub fn monitor_alert_severity_name(severity : MonitorAlertSeverity) -> String {
  match severity {
    Info => "info"
    Watch => "watch"
    Action => "action"
    Escalate => "escalate"
  }
}

///|
fn severity_rank(severity : MonitorAlertSeverity) -> Int {
  match severity {
    Info => 0
    Watch => 1
    Action => 2
    Escalate => 3
  }
}

///|
fn max_alert_severity(
  left : MonitorAlertSeverity,
  right : MonitorAlertSeverity,
) -> MonitorAlertSeverity {
  if severity_rank(left) >= severity_rank(right) {
    left
  } else {
    right
  }
}

///|
fn monitor_alert(
  date : String,
  kind : MonitorAlertKind,
  severity : MonitorAlertSeverity,
  value : Double,
  threshold : Double,
  title : String,
  explanation : String,
  action : String,
) -> MonitoringAlert {
  {
    id: "monitor-" + date + "-" + monitor_alert_kind_name(kind),
    date,
    kind,
    severity,
    value,
    threshold,
    title,
    explanation,
    recommended_action: action,
  }
}

///|
fn score_alert(alert : MonitoringAlert) -> Double {
  match alert.severity {
    Info => 0.0
    Watch => 25.0
    Action => 60.0
    Escalate => 100.0
  }
}

///|
fn risk_score_alert(
  assessment : ComprehensiveAssessment,
  thresholds : MonitoringThresholds,
) -> MonitoringAlert? {
  if assessment.risk_score >= thresholds.high_risk_score {
    Some(
      monitor_alert(
        assessment.date,
        RiskScore,
        Escalate,
        assessment.risk_score,
        thresholds.high_risk_score,
        "risk score requires escalation",
        "the composite signal score is above the escalation threshold",
        "pause automatic progression and review the contributing signals",
      ),
    )
  } else if assessment.risk_score >= thresholds.medium_risk_score {
    Some(
      monitor_alert(
        assessment.date,
        RiskScore,
        Action,
        assessment.risk_score,
        thresholds.medium_risk_score,
        "risk score is elevated",
        "the composite signal score entered the operational action band",
        "stabilize the next session and inspect the signal evidence",
      ),
    )
  } else {
    None
  }
}

///|
fn readiness_alert(
  assessment : ComprehensiveAssessment,
  thresholds : MonitoringThresholds,
) -> MonitoringAlert? {
  if assessment.readiness_score < thresholds.minimum_readiness {
    let severity = if assessment.readiness_score <
      thresholds.minimum_readiness - 15.0 {
      Action
    } else {
      Watch
    }
    Some(
      monitor_alert(
        assessment.date,
        Readiness,
        severity,
        assessment.readiness_score,
        thresholds.minimum_readiness,
        "readiness is below the training floor",
        "the combined load, recovery, pain, and quality score is below the configured floor",
        "use the action plan before increasing training load",
      ),
    )
  } else {
    None
  }
}

///|
fn pain_alert(
  assessment : ComprehensiveAssessment,
  thresholds : MonitoringThresholds,
) -> MonitoringAlert? {
  let pain_signals = assessment.signals.signals.filter(signal => {
    signal.kind == Pain
  })
  let pain = if pain_signals.length() == 0 {
    0.0
  } else {
    pain_signals[0].value
  }
  if pain >= thresholds.maximum_pain {
    Some(
      monitor_alert(
        assessment.date,
        Pain,
        if pain >= thresholds.maximum_pain + 2.0 {
          Escalate
        } else {
          Action
        },
        pain,
        thresholds.maximum_pain,
        "pain signal needs review",
        "pain is at or above the configured operational threshold",
        "record the pain site and route the case for qualified review",
      ),
    )
  } else {
    None
  }
}

///|
fn load_ratio_alert(
  assessment : ComprehensiveAssessment,
  thresholds : MonitoringThresholds,
) -> MonitoringAlert? {
  let ratio = assessment.load.acwr
  if ratio > thresholds.maximum_acwr {
    Some(
      monitor_alert(
        assessment.date,
        LoadRatio,
        if ratio >= thresholds.maximum_acwr + 0.35 {
          Action
        } else {
          Watch
        },
        ratio,
        thresholds.maximum_acwr,
        "acute load is high relative to chronic load",
        "the workload ratio exceeds the configured progression guardrail",
        "reduce the next load step and compare against the prior microcycle",
      ),
    )
  } else {
    None
  }
}

///|
fn sleep_alert(
  record : DailyRecord,
  thresholds : MonitoringThresholds,
) -> MonitoringAlert? {
  if record.sleep_hours < thresholds.minimum_sleep_hours {
    Some(
      monitor_alert(
        record.date,
        Sleep,
        if record.sleep_hours < thresholds.minimum_sleep_hours - 1.5 {
          Action
        } else {
          Watch
        },
        record.sleep_hours,
        thresholds.minimum_sleep_hours,
        "sleep duration is below the recovery floor",
        "the daily sleep duration is below the configured target",
        "protect recovery time and avoid using this day as a progression baseline",
      ),
    )
  } else {
    None
  }
}

///|
fn fatigue_alert(
  record : DailyRecord,
  thresholds : MonitoringThresholds,
) -> MonitoringAlert? {
  if record.fatigue > thresholds.maximum_fatigue {
    Some(
      monitor_alert(
        record.date,
        Fatigue,
        if record.fatigue >= thresholds.maximum_fatigue + 2.0 {
          Action
        } else {
          Watch
        },
        record.fatigue,
        thresholds.maximum_fatigue,
        "subjective fatigue is elevated",
        "the daily fatigue report exceeds the configured operational threshold",
        "select a lower-intensity session or schedule recovery",
      ),
    )
  } else {
    None
  }
}

///|
fn quality_alert(
  assessment : ComprehensiveAssessment,
  thresholds : MonitoringThresholds,
) -> MonitoringAlert? {
  if assessment.quality.score < thresholds.quality_floor {
    Some(
      monitor_alert(
        assessment.date,
        Quality,
        if assessment.quality.blocking_issue_count > 0 {
          Action
        } else {
          Watch
        },
        assessment.quality.score,
        thresholds.quality_floor,
        "telemetry quality is below the analysis floor",
        "missing, invalid, or duplicate records reduce confidence in the assessment",
        "repair the input record before interpreting a trend",
      ),
    )
  } else {
    None
  }
}

///|
fn collect_assessment_alerts(
  assessment : ComprehensiveAssessment,
  record : DailyRecord?,
  thresholds : MonitoringThresholds,
) -> Array[MonitoringAlert] {
  let alerts = []
  match risk_score_alert(assessment, thresholds) {
    Some(alert) => alerts.push(alert)
    None => ()
  }
  match readiness_alert(assessment, thresholds) {
    Some(alert) => alerts.push(alert)
    None => ()
  }
  match pain_alert(assessment, thresholds) {
    Some(alert) => alerts.push(alert)
    None => ()
  }
  match load_ratio_alert(assessment, thresholds) {
    Some(alert) => alerts.push(alert)
    None => ()
  }
  match quality_alert(assessment, thresholds) {
    Some(alert) => alerts.push(alert)
    None => ()
  }
  match record {
    Some(record) => {
      match sleep_alert(record, thresholds) {
        Some(alert) => alerts.push(alert)
        None => ()
      }
      match fatigue_alert(record, thresholds) {
        Some(alert) => alerts.push(alert)
        None => ()
      }
    }
    None => ()
  }
  alerts
}

///|
fn record_for_date(records : Array[DailyRecord], date : String) -> DailyRecord? {
  for record in records {
    if record.date == date {
      return Some(record)
    }
  }
  None
}

///|
fn training_streak_at(records : Array[DailyRecord], index : Int) -> Int {
  if index < 0 || index >= records.length() {
    return 0
  }
  let mut count = 0
  let mut cursor = index
  while cursor >= 0 && daily_training_load(records[cursor]) > 0.0 {
    count += 1
    cursor -= 1
  }
  count
}

///|
fn streak_alert(
  record : DailyRecord,
  streak : Int,
  thresholds : MonitoringThresholds,
) -> MonitoringAlert? {
  if streak >= thresholds.consecutive_days {
    Some(
      monitor_alert(
        record.date,
        TrainingStreak,
        if streak >= thresholds.consecutive_days + 2 {
          Action
        } else {
          Watch
        },
        streak.to_double(),
        thresholds.consecutive_days.to_double(),
        "consecutive training days are accumulating",
        "the current training streak is above the configured monitoring limit",
        "insert a recovery day or document why the streak is intentional",
      ),
    )
  } else {
    None
  }
}

///|
fn merge_alerts(alerts : Array[MonitoringAlert]) -> Array[MonitoringAlert] {
  let merged : Array[MonitoringAlert] = []
  for alert in alerts {
    let mut found = false
    for index, existing in merged {
      if existing.kind == alert.kind && existing.date == alert.date {
        found = true
        if severity_rank(alert.severity) > severity_rank(existing.severity) {
          merged[index] = alert
        }
      }
    }
    if !found {
      merged.push(alert)
    }
  }
  merged
}

///|
fn daily_monitor(
  date : String,
  assessment : ComprehensiveAssessment?,
  alerts : Array[MonitoringAlert],
  data_complete : Bool,
) -> DailyMonitor {
  let score = alerts.fold(init=0.0, (total, alert) => total + score_alert(alert))
  let actionable = alerts.any(alert => {
    match alert.severity {
      Action | Escalate => true
      _ => false
    }
  })
  {
    date,
    assessment,
    alerts,
    alert_score: score.min(100.0),
    actionable,
    data_complete,
    next_review: if actionable {
      "before_next_session"
    } else {
      "next_daily_checkin"
    },
  }
}

///|
pub fn monitor_day(
  records : Array[DailyRecord],
  date : String,
  policy : RiskPolicy,
  thresholds : MonitoringThresholds,
) -> DailyMonitor {
  let assessment = assess_comprehensive(records, date, policy)
  match assessment {
    Some(assessment) => {
      let record = record_for_date(records, date)
      let base = collect_assessment_alerts(assessment, record, thresholds)
      let streak = match find_record_index(records, date) {
        Some(index) => training_streak_at(sort_records_by_date(records), index)
        None => 0
      }
      let alerts = match record {
        Some(record) =>
          match streak_alert(record, streak, thresholds) {
            Some(alert) => merge_alerts(base + [alert])
            None => merge_alerts(base)
          }
        None => merge_alerts(base)
      }
      daily_monitor(
        date,
        Some(assessment),
        alerts,
        assessment.quality.score >= thresholds.quality_floor,
      )
    }
    None =>
      daily_monitor(
        date,
        None,
        [
          monitor_alert(
            date,
            MissingTelemetry,
            Escalate,
            0.0,
            1.0,
            "daily telemetry is unavailable",
            "no assessment can be built for the requested date",
            "collect a valid daily record before making a training decision",
          ),
        ],
        false,
      )
  }
}

///|
fn monitoring_dates(records : Array[DailyRecord]) -> Array[String] {
  sort_records_by_date(records).map(record => record.date)
}

///|
fn monitoring_status(summary : MonitoringSummary) -> String {
  if summary.escalation_count > 0 {
    "escalate"
  } else if summary.actionable_day_count > 0 {
    "action_required"
  } else if summary.alert_count > 0 {
    "watch"
  } else {
    "stable"
  }
}

///|
fn build_monitoring_summary(
  monitors : Array[DailyMonitor],
) -> MonitoringSummary {
  let alert_count = monitors.fold(init=0, (total, monitor) => {
    total + monitor.alerts.length()
  })
  let actionable = monitors.filter(monitor => monitor.actionable).length()
  let escalation = monitors.fold(init=0, (total, monitor) => {
    total + monitor.alerts.filter(alert => alert.severity == Escalate).length()
  })
  let score = monitors.fold(init=0.0, (total, monitor) => {
    total + monitor.alert_score
  })
  let complete = monitors.filter(monitor => monitor.data_complete).length()
  let mut highest_date : String? = None
  let mut highest_score = 0.0
  for monitor in monitors {
    if monitor.alert_score > highest_score {
      highest_score = monitor.alert_score
      highest_date = Some(monitor.date)
    }
  }
  let base_summary : MonitoringSummary = {
    day_count: monitors.length(),
    alert_count,
    actionable_day_count: actionable,
    escalation_count: escalation,
    average_alert_score: if monitors.length() == 0 {
      0.0
    } else {
      score / monitors.length().to_double()
    },
    highest_alert_date: highest_date,
    highest_alert_score: highest_score,
    data_complete_percent: if monitors.length() == 0 {
      0.0
    } else {
      complete.to_double() / monitors.length().to_double() * 100.0
    },
    status: "stable",
  }
  {
    day_count: base_summary.day_count,
    alert_count: base_summary.alert_count,
    actionable_day_count: base_summary.actionable_day_count,
    escalation_count: base_summary.escalation_count,
    average_alert_score: base_summary.average_alert_score,
    highest_alert_date: base_summary.highest_alert_date,
    highest_alert_score: base_summary.highest_alert_score,
    data_complete_percent: base_summary.data_complete_percent,
    status: monitoring_status(base_summary),
  }
}

///|
pub fn run_monitoring(
  records : Array[DailyRecord],
  policy : RiskPolicy,
  thresholds : MonitoringThresholds,
) -> MonitoringRun {
  let sorted = sort_records_by_date(records)
  let monitors = []
  for date in monitoring_dates(sorted) {
    monitors.push(monitor_day(sorted, date, policy, thresholds))
  }
  let summary = build_monitoring_summary(monitors)
  {
    monitors,
    summary,
    thresholds,
    generated_for: if sorted.length() == 0 {
      "empty_dataset"
    } else {
      sorted[sorted.length() - 1].date
    },
  }
}

///|
pub fn monitoring_action_dates(run : MonitoringRun) -> Array[String] {
  run.monitors
  .filter(monitor => monitor.actionable)
  .map(monitor => monitor.date)
}

///|
pub fn monitoring_escalation_dates(run : MonitoringRun) -> Array[String] {
  run.monitors
  .filter(monitor => monitor.alerts.any(alert => alert.severity == Escalate))
  .map(monitor => monitor.date)
}

///|
pub fn monitoring_alerts(run : MonitoringRun) -> Array[MonitoringAlert] {
  let alerts = []
  for monitor in run.monitors {
    for alert in monitor.alerts {
      alerts.push(alert)
    }
  }
  alerts
}

///|
pub fn monitoring_alerts_for_date(
  run : MonitoringRun,
  date : String,
) -> Array[MonitoringAlert] {
  for monitor in run.monitors {
    if monitor.date == date {
      return monitor.alerts
    }
  }
  []
}

///|
pub fn monitoring_alert_count_by_kind(
  run : MonitoringRun,
  kind : MonitorAlertKind,
) -> Int {
  monitoring_alerts(run).filter(alert => alert.kind == kind).length()
}

///|
pub fn monitoring_highest_severity(run : MonitoringRun) -> MonitorAlertSeverity {
  let mut highest = Info
  for alert in monitoring_alerts(run) {
    highest = max_alert_severity(highest, alert.severity)
  }
  highest
}

///|
pub fn monitoring_is_stable(run : MonitoringRun) -> Bool {
  run.summary.status == "stable"
}

///|
pub fn monitoring_requires_review(run : MonitoringRun) -> Bool {
  run.summary.actionable_day_count > 0 || run.summary.escalation_count > 0
}

///|
pub fn monitoring_alert_text(alert : MonitoringAlert) -> String {
  alert.date +
  " " +
  monitor_alert_severity_name(alert.severity) +
  " " +
  monitor_alert_kind_name(alert.kind) +
  " value=" +
  alert.value.to_string() +
  " threshold=" +
  alert.threshold.to_string() +
  " action=" +
  alert.recommended_action
}

///|
pub fn monitoring_summary_text(summary : MonitoringSummary) -> String {
  "status=" +
  summary.status +
  " days=" +
  summary.day_count.to_string() +
  " alerts=" +
  summary.alert_count.to_string() +
  " actionable_days=" +
  summary.actionable_day_count.to_string() +
  " escalations=" +
  summary.escalation_count.to_string() +
  " complete=" +
  summary.data_complete_percent.to_string() +
  "%"
}

///|
pub fn monitoring_run_text(run : MonitoringRun) -> String {
  let builder = StringBuilder::new()
  builder.write_string(monitoring_summary_text(run.summary))
  for alert in monitoring_alerts(run) {
    builder.write_string("\n")
    builder.write_string(monitoring_alert_text(alert))
  }
  builder.to_string()
}

///|
pub fn monitoring_alert_csv_header() -> String {
  "date,id,kind,severity,value,threshold,title,action"
}

///|
pub fn monitoring_alert_csv(alert : MonitoringAlert) -> String {
  alert.date +
  "," +
  alert.id +
  "," +
  monitor_alert_kind_name(alert.kind) +
  "," +
  monitor_alert_severity_name(alert.severity) +
  "," +
  alert.value.to_string() +
  "," +
  alert.threshold.to_string() +
  "," +
  alert.title +
  "," +
  alert.recommended_action
}

///|
pub fn monitoring_run_csv(run : MonitoringRun) -> String {
  let builder = StringBuilder::new()
  builder.write_string(monitoring_alert_csv_header())
  for alert in monitoring_alerts(run) {
    builder.write_string("\n")
    builder.write_string(monitoring_alert_csv(alert))
  }
  builder.to_string()
}

///|
pub fn monitoring_window(
  run : MonitoringRun,
  start : String,
  end : String,
) -> Array[DailyMonitor] {
  match (parse_date(start), parse_date(end)) {
    (Some(start), Some(end)) =>
      match make_date_range(start, end) {
        Some(range) =>
          run.monitors.filter(monitor => {
            match parse_date(monitor.date) {
              Some(date) => date_is_in_range(date, range)
              None => false
            }
          })
        None => []
      }
    _ => []
  }
}

///|
pub fn monitoring_window_summary(
  run : MonitoringRun,
  start : String,
  end : String,
) -> MonitoringSummary {
  build_monitoring_summary(monitoring_window(run, start, end))
}

///|
pub fn monitoring_gap_dates(
  records : Array[DailyRecord],
  run : MonitoringRun,
) -> Array[String] {
  let known = records.map(record => record.date)
  run.monitors
  .filter(monitor => !known.contains(monitor.date))
  .map(monitor => monitor.date)
}

///|
pub fn monitoring_score_trend(run : MonitoringRun) -> LoadTrend {
  let scores = run.monitors.map(monitor => monitor.alert_score)
  load_trend(scores, 0.1)
}

///|
pub fn monitoring_completion_ratio(run : MonitoringRun) -> Double {
  if run.monitors.length() == 0 {
    0.0
  } else {
    run.summary.data_complete_percent / 100.0
  }
}

///|
pub fn monitoring_recommended_next_step(run : MonitoringRun) -> String {
  match run.summary.status {
    "escalate" => "route the latest escalation to a qualified reviewer"
    "action_required" =>
      "apply the latest action plan and review before progression"
    "watch" => "continue daily collection and inspect the next trend point"
    _ => "continue the planned monitoring cadence"
  }
}

///|
pub fn monitoring_config_valid(thresholds : MonitoringThresholds) -> Bool {
  thresholds.high_risk_score >= thresholds.medium_risk_score &&
  thresholds.medium_risk_score >= 0.0 &&
  thresholds.minimum_readiness >= 0.0 &&
  thresholds.minimum_readiness <= 100.0 &&
  thresholds.maximum_pain >= 0.0 &&
  thresholds.maximum_acwr >= 0.0 &&
  thresholds.minimum_sleep_hours >= 0.0 &&
  thresholds.maximum_fatigue >= 0.0 &&
  thresholds.quality_floor >= 0.0 &&
  thresholds.quality_floor <= 100.0 &&
  thresholds.consecutive_days > 0
}
