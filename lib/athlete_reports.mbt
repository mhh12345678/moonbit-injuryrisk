///|
/// Compact athlete reports provide a stable presentation layer for applications.
pub(all) enum AthleteReportSectionKind {
  ReportOverview
  ReportRisk
  ReportLoad
  ReportRecovery
  ReportQuality
  ReportActions
  ReportTrend
  ReportData
} derive(Debug, Eq, ToJson)

///|
pub(all) struct AthleteReportSection {
  kind : AthleteReportSectionKind
  title : String
  status : String
  priority : Int
  metrics : Array[String]
  narrative : String
  actions : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct AthleteReport {
  report_id : String
  athlete_label : String
  generated_for : String
  status : String
  priority : Int
  sections : Array[AthleteReportSection]
  headline : String
  recommendation : String
  checksum : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct AthleteReportComparison {
  left_id : String
  right_id : String
  left_priority : Int
  right_priority : Int
  risk_change : Double
  readiness_change : Double
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct AthleteReportBundle {
  reports : Array[AthleteReport]
  latest : AthleteReport?
  critical_count : Int
  review_count : Int
  accepted_count : Int
  status : String
} derive(Debug, Eq, ToJson)

///|
pub fn athlete_report_section_name(kind : AthleteReportSectionKind) -> String {
  match kind {
    ReportOverview => "overview"
    ReportRisk => "risk"
    ReportLoad => "load"
    ReportRecovery => "recovery"
    ReportQuality => "quality"
    ReportActions => "actions"
    ReportTrend => "trend"
    ReportData => "data"
  }
}

///|
pub fn athlete_report_section_kinds() -> Array[AthleteReportSectionKind] {
  [
    ReportOverview,
    ReportRisk,
    ReportLoad,
    ReportRecovery,
    ReportQuality,
    ReportActions,
    ReportTrend,
    ReportData,
  ]
}

///|
fn report_priority(run : DecisionRun) -> Int {
  if run.status == "critical" {
    3
  } else if decision_run_requires_action(run) {
    2
  } else if run.status == "review" {
    1
  } else {
    0
  }
}

///|
fn report_status(run : DecisionRun) -> String {
  if run.status == "critical" {
    "critical"
  } else if decision_run_requires_action(run) {
    "action"
  } else if run.status == "review" {
    "review"
  } else {
    "accepted"
  }
}

///|
fn report_section(
  kind : AthleteReportSectionKind,
  title : String,
  status : String,
  priority : Int,
  metrics : Array[String],
  narrative : String,
  actions : Array[String],
) -> AthleteReportSection {
  { kind, title, status, priority, metrics, narrative, actions }
}

///|
fn report_overview(
  run : DecisionRun,
  performance : PerformanceSnapshot,
) -> AthleteReportSection {
  report_section(
    ReportOverview,
    "Overview",
    report_status(run),
    report_priority(run),
    [
      "status=" + run.status,
      "accepted=" + run.accepted.to_string(),
      "records=" + performance.record_count.to_string(),
      "quality=" + performance.quality_score.to_string(),
    ],
    decision_run_summary(run),
    [decision_run_recommendation(run)],
  )
}

///|
fn report_risk(run : DecisionRun) -> AthleteReportSection {
  let score = decision_run_latest_risk(run)
  report_section(
    ReportRisk,
    "Risk",
    if score >= 70.0 {
      "critical"
    } else if score >= 40.0 {
      "watch"
    } else {
      "stable"
    },
    if score >= 70.0 {
      3
    } else if score >= 40.0 {
      1
    } else {
      0
    },
    [
      "risk_score=" + score.to_string(),
      "alerts=" + decision_run_alert_count(run).to_string(),
      "events=" + decision_run_event_count(run).to_string(),
    ],
    if score >= 70.0 {
      "composite risk is above the escalation band"
    } else if score >= 40.0 {
      "composite risk is in the operational watch band"
    } else {
      "composite risk is within the low band"
    },
    if score >= 40.0 {
      ["review contributing risk signals"]
    } else {
      []
    },
  )
}

///|
fn report_load(run : DecisionRun) -> AthleteReportSection {
  match run.latest {
    Some(assessment) =>
      report_section(
        ReportLoad,
        "Load",
        if assessment.load.acwr > 1.5 {
          "action"
        } else {
          "stable"
        },
        if assessment.load.acwr > 1.5 {
          2
        } else {
          0
        },
        [
          "acute=" + assessment.load.acute_load.to_string(),
          "chronic=" + assessment.load.chronic_load.to_string(),
          "acwr=" + assessment.load.acwr.to_string(),
          "strain=" + assessment.load.strain.to_string(),
        ],
        "load distribution is evaluated against the configured acute and chronic windows",
        if assessment.load.acwr > 1.5 {
          ["hold or reduce the next load increase"]
        } else {
          ["continue gradual progression"]
        },
      )
    None =>
      report_section(
        ReportLoad,
        "Load",
        "unknown",
        1,
        ["no assessment"],
        "load is unavailable",
        ["collect more records"],
      )
  }
}

///|
fn report_recovery(run : DecisionRun) -> AthleteReportSection {
  match run.latest {
    Some(assessment) =>
      report_section(
        ReportRecovery,
        "Recovery",
        if assessment.recovery.recovery_score < 60.0 {
          "action"
        } else if assessment.recovery.recovery_score < 75.0 {
          "watch"
        } else {
          "stable"
        },
        if assessment.recovery.recovery_score < 60.0 {
          2
        } else {
          0
        },
        [
          "recovery=" + assessment.recovery.recovery_score.to_string(),
          "sleep=" + assessment.recovery.average_sleep_hours.to_string(),
          "fatigue=" + assessment.recovery.average_fatigue.to_string(),
          "pain=" + assessment.recovery.average_pain.to_string(),
        ],
        "recovery and symptom telemetry are combined with load before progression",
        if assessment.recovery.recovery_score < 60.0 {
          ["prioritize recovery and recheck before progression"]
        } else {
          []
        },
      )
    None =>
      report_section(
        ReportRecovery,
        "Recovery",
        "unknown",
        1,
        ["no assessment"],
        "recovery is unavailable",
        ["collect more records"],
      )
  }
}

///|
fn report_quality(run : DecisionRun) -> AthleteReportSection {
  let score = run.quality.report.score
  report_section(
    ReportQuality,
    "Data quality",
    if !run.quality.passed {
      "blocked"
    } else if score < 90.0 {
      "watch"
    } else {
      "stable"
    },
    if !run.quality.passed {
      3
    } else {
      0
    },
    [
      "quality=" + score.to_string(),
      "issues=" + run.quality.report.issue_count.to_string(),
      "blocking=" + run.quality.report.blocking_issue_count.to_string(),
      "coverage=" + quality_gate_coverage(run.quality).to_string(),
    ],
    if run.quality.passed {
      "input passed the configured quality gate"
    } else {
      run.quality.recommendation
    },
    if run.quality.passed {
      []
    } else {
      ["repair input before using the decision"]
    },
  )
}

///|
fn report_actions(run : DecisionRun) -> AthleteReportSection {
  let actions = workspace_open_queue(run.workspace).map(item => item.action)
  report_section(
    ReportActions,
    "Actions",
    if actions.length() == 0 {
      "clear"
    } else {
      "open"
    },
    actions.length().min(3),
    [
      "open_actions=" + actions.length().to_string(),
      "interventions=" + decision_run_intervention_count(run).to_string(),
    ],
    if actions.length() == 0 {
      "no open operational action"
    } else {
      "the coach workspace contains follow-up actions"
    },
    actions,
  )
}

///|
fn report_trend(run : DecisionRun) -> AthleteReportSection {
  let view = workflow_trend_view(run)
  let label = match view.trend {
    Rising => "rising"
    Stable => "stable"
    Falling => "falling"
    Volatile => "volatile"
    InsufficientData => "insufficient_data"
  }
  report_section(
    ReportTrend,
    "Trend",
    label,
    if view.status == "review" {
      2
    } else {
      0
    },
    [
      "points=" + view.dates.length().to_string(),
      "status=" + view.status,
      "risk_points=" + view.risk_scores.length().to_string(),
    ],
    "the trend section is derived from the same deterministic monitoring run",
    view.action_dates,
  )
}

///|
fn report_data(
  run : DecisionRun,
  performance : PerformanceSnapshot,
) -> AthleteReportSection {
  report_section(
    ReportData,
    "Data",
    if performance.coverage_percent >= 80.0 {
      "usable"
    } else {
      "review"
    },
    if performance.coverage_percent >= 80.0 {
      0
    } else {
      2
    },
    [
      "run=" + run.config.run_id,
      "records=" + performance.record_count.to_string(),
      "sessions=" + performance.session_count.to_string(),
      "coverage=" + performance.coverage_percent.to_string(),
      "processing_units=" + performance.processing_units.to_string(),
    ],
    "data coverage and processing volume are retained with the report",
    if performance.coverage_percent >= 80.0 {
      []
    } else {
      ["collect a longer continuous baseline"]
    },
  )
}

///|
fn report_headline(run : DecisionRun) -> String {
  if run.status == "critical" {
    "Critical review required"
  } else if decision_run_requires_action(run) {
    "Action required before progression"
  } else if run.status == "review" {
    "Review the current evidence"
  } else {
    "Decision run is operational"
  }
}

///|
fn report_recommendation(run : DecisionRun) -> String {
  if run.status == "critical" {
    "pause progression and route the case for qualified review"
  } else {
    decision_run_recommendation(run)
  }
}

///|
fn athlete_report_checksum(report : AthleteReport) -> String {
  let mut value = report.report_id.length() + report.sections.length()
  for character in athlete_report_text(report) {
    value = (value * 33 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn build_athlete_report(
  run : DecisionRun,
  performance : PerformanceSnapshot,
  athlete_label : String,
) -> AthleteReport {
  let sections = [
    report_overview(run, performance),
    report_risk(run),
    report_load(run),
    report_recovery(run),
    report_quality(run),
    report_actions(run),
    report_trend(run),
    report_data(run, performance),
  ]
  let base = {
    report_id: "report-" + run.config.run_id,
    athlete_label,
    generated_for: run.monitoring.generated_for,
    status: report_status(run),
    priority: report_priority(run),
    sections,
    headline: report_headline(run),
    recommendation: report_recommendation(run),
    checksum: "",
  }
  {
    report_id: base.report_id,
    athlete_label: base.athlete_label,
    generated_for: base.generated_for,
    status: base.status,
    priority: base.priority,
    sections: base.sections,
    headline: base.headline,
    recommendation: base.recommendation,
    checksum: athlete_report_checksum(base),
  }
}

///|
pub fn athlete_report_section(
  report : AthleteReport,
  kind : AthleteReportSectionKind,
) -> AthleteReportSection? {
  for section in report.sections {
    if section.kind == kind {
      return Some(section)
    }
  }
  None
}

///|
pub fn athlete_report_section_by_name(
  report : AthleteReport,
  name : String,
) -> AthleteReportSection? {
  for section in report.sections {
    if athlete_report_section_name(section.kind) == name {
      return Some(section)
    }
  }
  None
}

///|
pub fn athlete_report_section_count(report : AthleteReport) -> Int {
  report.sections.length()
}

///|
pub fn athlete_report_section_names(report : AthleteReport) -> Array[String] {
  report.sections.map(section => athlete_report_section_name(section.kind))
}

///|
pub fn athlete_report_section_statuses(report : AthleteReport) -> Array[String] {
  report.sections.map(section => section.status)
}

///|
pub fn athlete_report_section_priorities(report : AthleteReport) -> Array[Int] {
  report.sections.map(section => section.priority)
}

///|
pub fn athlete_report_action_sections(
  report : AthleteReport,
) -> Array[AthleteReportSection] {
  report.sections.filter(section => section.priority > 0)
}

///|
pub fn athlete_report_action_count(report : AthleteReport) -> Int {
  athlete_report_action_sections(report).length()
}

///|
pub fn athlete_report_all_actions(report : AthleteReport) -> Array[String] {
  let actions = []
  for section in report.sections {
    for action in section.actions {
      if !actions.contains(action) {
        actions.push(action)
      }
    }
  }
  actions
}

///|
pub fn athlete_report_metrics(report : AthleteReport) -> Array[String] {
  let values = []
  for section in report.sections {
    for metric in section.metrics {
      values.push(metric)
    }
  }
  values
}

///|
pub fn athlete_report_narratives(report : AthleteReport) -> Array[String] {
  report.sections.map(section => section.narrative)
}

///|
pub fn athlete_report_priority(report : AthleteReport) -> Int {
  report.priority
}

///|
pub fn athlete_report_status(report : AthleteReport) -> String {
  report.status
}

///|
pub fn athlete_report_requires_action(report : AthleteReport) -> Bool {
  report.priority >= 2 || athlete_report_action_count(report) > 0
}

///|
pub fn athlete_report_requires_review(report : AthleteReport) -> Bool {
  report.priority > 0 || report.status == "review"
}

///|
pub fn athlete_report_is_critical(report : AthleteReport) -> Bool {
  report.status == "critical"
}

///|
pub fn athlete_report_is_accepted(report : AthleteReport) -> Bool {
  report.status == "accepted"
}

///|
pub fn athlete_report_valid(report : AthleteReport) -> Bool {
  report.report_id != "" &&
  report.athlete_label != "" &&
  report.generated_for != "" &&
  report.status != "" &&
  report.priority >= 0 &&
  report.sections.length() > 0 &&
  report.sections.all(section => section.title != "" && section.narrative != "") &&
  report.checksum == athlete_report_checksum(report)
}

///|
pub fn athlete_report_section_valid(section : AthleteReportSection) -> Bool {
  section.title != "" &&
  section.priority >= 0 &&
  section.metrics.length() >= 0 &&
  section.narrative != ""
}

///|
pub fn athlete_report_sections_valid(report : AthleteReport) -> Bool {
  report.sections.all(section => athlete_report_section_valid(section))
}

///|
pub fn athlete_report_checksum_valid(report : AthleteReport) -> Bool {
  report.checksum == athlete_report_checksum(report)
}

///|
pub fn athlete_report_text(report : AthleteReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "report=" +
    report.report_id +
    " athlete=" +
    report.athlete_label +
    " date=" +
    report.generated_for +
    " status=" +
    report.status +
    " priority=" +
    report.priority.to_string(),
  )
  builder.write_string("\nheadline=" + report.headline)
  builder.write_string("\nrecommendation=" + report.recommendation)
  for section in report.sections {
    builder.write_string(
      "\n[" +
      athlete_report_section_name(section.kind) +
      "] " +
      section.status +
      " " +
      section.narrative,
    )
    for metric in section.metrics {
      builder.write_string("\nmetric=" + metric)
    }
    for action in section.actions {
      builder.write_string("\naction=" + action)
    }
  }
  builder.to_string()
}

///|
pub fn athlete_report_summary(report : AthleteReport) -> Array[String] {
  [
    report.report_id,
    report.athlete_label,
    report.generated_for,
    report.status,
    report.priority.to_string(),
    athlete_report_action_count(report).to_string(),
    report.headline,
    report.checksum,
  ]
}

///|
pub fn athlete_report_summary_header() -> Array[String] {
  [
    "report_id", "athlete_label", "generated_for", "status", "priority", "action_count",
    "headline", "checksum",
  ]
}

///|
pub fn athlete_report_summary_csv(report : AthleteReport) -> String {
  athlete_report_summary_header().join(",") +
  "\n" +
  athlete_report_summary(report).join(",")
}

///|
pub fn athlete_report_section_csv_header() -> String {
  "kind,title,status,priority,metrics,narrative,actions"
}

///|
pub fn athlete_report_section_csv(section : AthleteReportSection) -> String {
  athlete_report_section_name(section.kind) +
  "," +
  section.title +
  "," +
  section.status +
  "," +
  section.priority.to_string() +
  "," +
  section.metrics.join(";") +
  "," +
  section.narrative +
  "," +
  section.actions.join(";")
}

///|
pub fn athlete_report_csv(report : AthleteReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string(athlete_report_section_csv_header())
  for section in report.sections {
    builder.write_string("\n" + athlete_report_section_csv(section))
  }
  builder.to_string()
}

///|
pub fn athlete_report_bundle(
  reports : Array[AthleteReport],
) -> AthleteReportBundle {
  let latest = if reports.length() == 0 {
    None
  } else {
    Some(reports[reports.length() - 1])
  }
  {
    reports,
    latest,
    critical_count: reports
    .filter(report => report.status == "critical")
    .length(),
    review_count: reports
    .filter(report => report.status == "review" || report.status == "action")
    .length(),
    accepted_count: reports
    .filter(report => report.status == "accepted")
    .length(),
    status: if reports.any(report => report.status == "critical") {
      "critical"
    } else if reports.any(report => report.status != "accepted") {
      "review"
    } else if reports.length() > 0 {
      "accepted"
    } else {
      "empty"
    },
  }
}

///|
pub fn athlete_report_bundle_latest(
  bundle : AthleteReportBundle,
) -> AthleteReport? {
  bundle.latest
}

///|
pub fn athlete_report_bundle_count(bundle : AthleteReportBundle) -> Int {
  bundle.reports.length()
}

///|
pub fn athlete_report_bundle_status(bundle : AthleteReportBundle) -> String {
  bundle.status
}

///|
pub fn athlete_report_bundle_requires_action(
  bundle : AthleteReportBundle,
) -> Bool {
  bundle.critical_count > 0 || bundle.review_count > 0
}

///|
pub fn athlete_report_bundle_valid(bundle : AthleteReportBundle) -> Bool {
  bundle.reports.all(report => athlete_report_valid(report)) &&
  bundle.critical_count >= 0 &&
  bundle.review_count >= 0 &&
  bundle.accepted_count >= 0 &&
  bundle.critical_count + bundle.review_count + bundle.accepted_count <=
  bundle.reports.length()
}

///|
pub fn athlete_report_bundle_text(bundle : AthleteReportBundle) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "reports=" +
    bundle.reports.length().to_string() +
    " status=" +
    bundle.status +
    " critical=" +
    bundle.critical_count.to_string() +
    " review=" +
    bundle.review_count.to_string() +
    " accepted=" +
    bundle.accepted_count.to_string(),
  )
  for report in bundle.reports {
    builder.write_string(
      "\n" +
      report.report_id +
      " " +
      report.status +
      " priority=" +
      report.priority.to_string(),
    )
  }
  builder.to_string()
}

///|
pub fn athlete_report_bundle_csv(bundle : AthleteReportBundle) -> String {
  let builder = StringBuilder::new()
  builder.write_string(athlete_report_summary_header().join(","))
  for report in bundle.reports {
    builder.write_string("\n" + athlete_report_summary(report).join(","))
  }
  builder.to_string()
}

///|
pub fn athlete_report_compare(
  left : AthleteReport,
  right : AthleteReport,
) -> AthleteReportComparison {
  let left_risk = match athlete_report_risk_status(left) {
    "critical" => 100.0
    "watch" => 50.0
    "action" => 70.0
    _ => 10.0
  }
  let right_risk = match athlete_report_risk_status(right) {
    "critical" => 100.0
    "watch" => 50.0
    "action" => 70.0
    _ => 10.0
  }
  {
    left_id: left.report_id,
    right_id: right.report_id,
    left_priority: left.priority,
    right_priority: right.priority,
    risk_change: right_risk - left_risk,
    readiness_change: 0.0,
    conclusion: if right.priority < left.priority {
      "report priority improved"
    } else if right.priority > left.priority {
      "report priority increased"
    } else {
      "report priority is unchanged"
    },
  }
}

///|
pub fn athlete_report_comparison_text(
  comparison : AthleteReportComparison,
) -> String {
  comparison.left_id +
  " -> " +
  comparison.right_id +
  " risk_change=" +
  comparison.risk_change.to_string() +
  " priority=" +
  comparison.left_priority.to_string() +
  ".." +
  comparison.right_priority.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn athlete_report_checksum_value(report : AthleteReport) -> String {
  report.checksum
}

///|
pub fn athlete_report_exportable(report : AthleteReport) -> Bool {
  athlete_report_valid(report) && athlete_report_status(report) != "critical"
}

///|
pub fn athlete_report_export_status(report : AthleteReport) -> String {
  if athlete_report_exportable(report) {
    "exportable"
  } else {
    "review"
  }
}

///|
pub fn athlete_report_priority_label(report : AthleteReport) -> String {
  if report.priority >= 3 {
    "critical"
  } else if report.priority == 2 {
    "high"
  } else if report.priority == 1 {
    "medium"
  } else {
    "routine"
  }
}

///|
pub fn athlete_report_next_review_days(report : AthleteReport) -> Int {
  if report.priority >= 3 {
    0
  } else if report.priority == 2 {
    1
  } else if report.priority == 1 {
    3
  } else {
    7
  }
}

///|
pub fn athlete_report_review_label(report : AthleteReport) -> String {
  "review_in_" + athlete_report_next_review_days(report).to_string() + "_days"
}

///|
pub fn athlete_report_contract(report : AthleteReport) -> Array[String] {
  [
    athlete_report_status(report),
    athlete_report_priority_label(report),
    athlete_report_export_status(report),
    athlete_report_review_label(report),
    athlete_report_valid(report).to_string(),
    athlete_report_checksum_value(report),
  ]
}

///|
pub fn athlete_report_section_metric(
  section : AthleteReportSection,
  prefix : String,
) -> String {
  for metric in section.metrics {
    if metric.has_prefix(prefix) {
      return metric
    }
  }
  ""
}

///|
pub fn athlete_report_section_actionable(
  section : AthleteReportSection,
) -> Bool {
  section.priority > 0 || section.actions.length() > 0
}

///|
pub fn athlete_report_section_action_count(
  section : AthleteReportSection,
) -> Int {
  section.actions.length()
}

///|
pub fn athlete_report_section_metric_count(
  section : AthleteReportSection,
) -> Int {
  section.metrics.length()
}

///|
pub fn athlete_report_section_text(section : AthleteReportSection) -> String {
  athlete_report_section_name(section.kind) +
  " status=" +
  section.status +
  " priority=" +
  section.priority.to_string() +
  " narrative=" +
  section.narrative +
  " metrics=" +
  section.metrics.join(";") +
  " actions=" +
  section.actions.join(";")
}

///|
pub fn athlete_report_sections_text(report : AthleteReport) -> String {
  report.sections
  .map(section => athlete_report_section_text(section))
  .join("\n")
}

///|
pub fn athlete_report_priority_sections(
  report : AthleteReport,
  priority : Int,
) -> Array[AthleteReportSection] {
  report.sections.filter(section => section.priority >= priority)
}

///|
pub fn athlete_report_priority_section_count(
  report : AthleteReport,
  priority : Int,
) -> Int {
  athlete_report_priority_sections(report, priority).length()
}

///|
pub fn athlete_report_all_titles(report : AthleteReport) -> Array[String] {
  report.sections.map(section => section.title)
}

///|
pub fn athlete_report_has_section(
  report : AthleteReport,
  kind : AthleteReportSectionKind,
) -> Bool {
  athlete_report_section(report, kind) is Some(_)
}

///|
pub fn athlete_report_complete(report : AthleteReport) -> Bool {
  athlete_report_section_kinds().all(kind => {
    athlete_report_has_section(report, kind)
  })
}

///|
pub fn athlete_report_missing_sections(report : AthleteReport) -> Array[String] {
  athlete_report_section_kinds()
  .filter(kind => !athlete_report_has_section(report, kind))
  .map(kind => athlete_report_section_name(kind))
}

///|
pub fn athlete_report_data_quality(report : AthleteReport) -> String {
  match athlete_report_section(report, ReportQuality) {
    Some(section) => section.status
    None => "unknown"
  }
}

///|
pub fn athlete_report_risk_status(report : AthleteReport) -> String {
  match athlete_report_section(report, ReportRisk) {
    Some(section) => section.status
    None => "unknown"
  }
}

///|
pub fn athlete_report_load_status(report : AthleteReport) -> String {
  match athlete_report_section(report, ReportLoad) {
    Some(section) => section.status
    None => "unknown"
  }
}

///|
pub fn athlete_report_recovery_status(report : AthleteReport) -> String {
  match athlete_report_section(report, ReportRecovery) {
    Some(section) => section.status
    None => "unknown"
  }
}

///|
pub fn athlete_report_sections_with_actions(
  report : AthleteReport,
) -> Array[String] {
  report.sections
  .filter(section => section.actions.length() > 0)
  .map(section => athlete_report_section_name(section.kind))
}

///|
pub fn athlete_report_action_text(report : AthleteReport) -> String {
  athlete_report_all_actions(report).join("; ")
}

///|
pub fn athlete_report_narrative(report : AthleteReport) -> String {
  report.headline + ". " + report.recommendation
}

///|
pub fn athlete_report_one_line(report : AthleteReport) -> String {
  report.athlete_label +
  " " +
  report.generated_for +
  " " +
  report.status +
  " priority=" +
  report.priority.to_string() +
  " " +
  report.headline
}

///|
pub fn athlete_report_bundle_priority(bundle : AthleteReportBundle) -> Int {
  bundle.reports.fold(init=0, (maximum, report) => maximum.max(report.priority))
}

///|
pub fn athlete_report_bundle_priority_label(
  bundle : AthleteReportBundle,
) -> String {
  if athlete_report_bundle_priority(bundle) >= 3 {
    "critical"
  } else if athlete_report_bundle_priority(bundle) == 2 {
    "high"
  } else if athlete_report_bundle_priority(bundle) == 1 {
    "medium"
  } else {
    "routine"
  }
}

///|
pub fn athlete_report_bundle_checksum(bundle : AthleteReportBundle) -> String {
  let mut value = bundle.reports.length()
  for character in athlete_report_bundle_text(bundle) {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn athlete_report_bundle_contract(
  bundle : AthleteReportBundle,
) -> Array[String] {
  [
    bundle.status,
    athlete_report_bundle_priority_label(bundle),
    athlete_report_bundle_requires_action(bundle).to_string(),
    athlete_report_bundle_valid(bundle).to_string(),
    athlete_report_bundle_checksum(bundle),
  ]
}
