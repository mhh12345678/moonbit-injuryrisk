///|
/// Output formats supported by the report helpers.
pub(all) enum ReportFormat {
  PlainText
  Csv
  JsonLines
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ReportOptions {
  format : ReportFormat
  include_clear_rules : Bool
  include_recommendations : Bool
  include_quality : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RiskReport {
  title : String
  generated_for : String
  body : String
  format : ReportFormat
} derive(Debug, Eq, ToJson)

///|
pub fn default_report_options() -> ReportOptions {
  {
    format: PlainText,
    include_clear_rules: false,
    include_recommendations: true,
    include_quality: true,
  }
}

///|
fn csv_escape(value : String) -> String {
  let builder = StringBuilder::new()
  let mut quoted = false
  for character in value {
    if character == '"' {
      quoted = true
      builder.write_string("\"\"")
    } else {
      if character == ',' || character == '\n' {
        quoted = true
      }
      builder.write_char(character)
    }
  }
  if quoted {
    "\"" + builder.to_string() + "\""
  } else {
    builder.to_string()
  }
}

///|
pub fn records_to_csv(records : Array[DailyRecord]) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "date,training_duration,training_intensity,load,pain_level,pain_site,sleep_hours,sleep_quality,fatigue\n",
  )
  for record in records {
    builder.write_string(csv_escape(record.date))
    builder.write_string(",")
    builder.write_string(record.training_duration.to_string())
    builder.write_string(",")
    builder.write_string(record.training_intensity.to_string())
    builder.write_string(",")
    builder.write_string(daily_training_load(record).to_string())
    builder.write_string(",")
    builder.write_string(record.pain_level.to_string())
    builder.write_string(",")
    builder.write_string(
      match record.pain_site {
        Some(site) => csv_escape(site)
        None => ""
      },
    )
    builder.write_string(",")
    builder.write_string(record.sleep_hours.to_string())
    builder.write_string(",")
    builder.write_string(record.sleep_quality.to_string())
    builder.write_string(",")
    builder.write_string(record.fatigue.to_string())
    builder.write_string("\n")
  }
  builder.to_string()
}

///|
pub fn signals_to_csv(signals : Array[RiskSignal]) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "id,kind,title,value,threshold,severity,confidence,evidence,action\n",
  )
  for signal in signals {
    builder.write_string(csv_escape(signal.id))
    builder.write_string(",")
    builder.write_string(signal_kind_name(signal.kind))
    builder.write_string(",")
    builder.write_string(csv_escape(signal.title))
    builder.write_string(",")
    builder.write_string(signal.value.to_string())
    builder.write_string(",")
    builder.write_string(signal.threshold.to_string())
    builder.write_string(",")
    builder.write_string(risk_level_name(signal.severity))
    builder.write_string(",")
    builder.write_string(signal.confidence.to_string())
    builder.write_string(",")
    builder.write_string(csv_escape(signal.evidence))
    builder.write_string(",")
    builder.write_string(csv_escape(signal.action))
    builder.write_string("\n")
  }
  builder.to_string()
}

///|
pub fn timeline_to_csv(timeline : RiskTimeline) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "date,risk_level,risk_score,readiness_score,acute_load,chronic_load,acwr,recovery_score,signal_count\n",
  )
  for point in timeline.points {
    builder.write_string(
      point.date +
      "," +
      risk_level_name(point.risk_level) +
      "," +
      point.risk_score.to_string() +
      "," +
      point.readiness_score.to_string() +
      "," +
      point.acute_load.to_string() +
      "," +
      point.chronic_load.to_string() +
      "," +
      point.acwr.to_string() +
      "," +
      point.recovery_score.to_string() +
      "," +
      point.signal_count.to_string() +
      "\n",
    )
  }
  builder.to_string()
}

///|
pub fn render_load_section(load : LoadSummary) -> String {
  "load\n  total=" +
  load.total_load.to_string() +
  " average=" +
  load.average_load.to_string() +
  " acute=" +
  load.acute_load.to_string() +
  " chronic=" +
  load.chronic_load.to_string() +
  " acwr=" +
  load.acwr.to_string() +
  " ramp=" +
  load.ramp_rate.to_string() +
  " monotony=" +
  load.monotony.to_string() +
  " strain=" +
  load.strain.to_string()
}

///|
pub fn render_recovery_section(recovery : RecoverySummary) -> String {
  "recovery\n  score=" +
  recovery.recovery_score.to_string() +
  " readiness=" +
  recovery.training_readiness.to_string() +
  " sleep=" +
  recovery.average_sleep_hours.to_string() +
  " debt=" +
  recovery.sleep_debt_hours.to_string() +
  " fatigue=" +
  recovery.average_fatigue.to_string() +
  " pain=" +
  recovery.maximum_pain.to_string()
}

///|
pub fn render_quality_section(quality : QualityReport) -> String {
  "quality\n  " +
  quality_report_text(quality) +
  " completeness=" +
  completeness_ratio_from_report(quality).to_string()
}

///|
fn completeness_ratio_from_report(report : QualityReport) -> Double {
  if report.record_count == 0 {
    0.0
  } else {
    (report.record_count - report.missing_date_count).to_double() /
    report.record_count.to_double()
  }
}

///|
pub fn render_signals_section(signals : SignalSummary) -> String {
  let builder = StringBuilder::new()
  builder.write_string("signals\n  count=")
  builder.write_string(signals.signal_count.to_string())
  builder.write_string(" high=")
  builder.write_string(signals.high_count.to_string())
  builder.write_string(" medium=")
  builder.write_string(signals.medium_count.to_string())
  builder.write_string(" weighted_score=")
  builder.write_string(signals.weighted_score.to_string())
  for signal in signals.signals {
    builder.write_string("\n  - ")
    builder.write_string(signal_text(signal))
  }
  builder.to_string()
}

///|
pub fn render_plan_section(plan : ActionPlan) -> String {
  let builder = StringBuilder::new()
  builder.write_string("action plan\n  focus=")
  builder.write_string(plan.focus)
  builder.write_string(" rest_days=")
  builder.write_string(plan.rest_days.to_string())
  builder.write_string(" load_change_percent=")
  builder.write_string(plan.load_change_percent.to_string())
  for recommendation in plan.recommendations {
    builder.write_string("\n  - [")
    builder.write_string(recommendation_priority_name(recommendation.priority))
    builder.write_string("] ")
    builder.write_string(recommendation.action)
  }
  builder.to_string()
}

///|
pub fn render_assessment(
  assessment : ComprehensiveAssessment,
  options : ReportOptions,
) -> RiskReport {
  let body = match options.format {
    PlainText => {
      let builder = StringBuilder::new()
      builder.write_string(assessment.summary)
      builder.write_string("\n")
      builder.write_string(render_load_section(assessment.load))
      builder.write_string("\n")
      builder.write_string(render_recovery_section(assessment.recovery))
      if options.include_quality {
        builder.write_string("\n")
        builder.write_string(render_quality_section(assessment.quality))
      }
      builder.write_string("\n")
      builder.write_string(render_signals_section(assessment.signals))
      if options.include_recommendations {
        builder.write_string("\n")
        builder.write_string(render_plan_section(assessment.action_plan))
      }
      builder.to_string()
    }
    Csv => signals_to_csv(assessment.signals.signals)
    JsonLines =>
      assessment.summary + "\n" + signals_to_csv(assessment.signals.signals)
  }
  {
    title: "MoonBit injury risk assessment",
    generated_for: assessment.date,
    body,
    format: options.format,
  }
}

///|
pub fn report_for_records(
  records : Array[DailyRecord],
  target_date : String,
  policy : RiskPolicy,
  options : ReportOptions,
) -> RiskReport? {
  match assess_comprehensive(records, target_date, policy) {
    Some(assessment) => Some(render_assessment(assessment, options))
    None => None
  }
}

///|
pub fn report_text(report : RiskReport) -> String {
  report.title + "\n" + report.body
}

///|
pub fn report_format_name(format : ReportFormat) -> String {
  match format {
    PlainText => "text"
    Csv => "csv"
    JsonLines => "json-lines"
  }
}
