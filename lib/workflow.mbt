///|
/// End-to-end configuration for a production screening run.
pub(all) struct WorkflowConfig {
  policy : RiskPolicy
  report_options : ReportOptions
  quality_policy : QualityPolicy
  target_sleep : Double
  target_date : String?
  fill_missing_dates : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct WorkflowResult {
  accepted : Bool
  input : TelemetryCsvResult?
  records : Array[DailyRecord]
  quality : QualityReport
  assessment : ComprehensiveAssessment?
  report : RiskReport?
  timeline : RiskTimeline?
  audit : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub fn default_workflow_config() -> WorkflowConfig {
  {
    policy: default_risk_policy(),
    report_options: default_report_options(),
    quality_policy: default_quality_policy(),
    target_sleep: 8.0,
    target_date: None,
    fill_missing_dates: false,
  }
}

///|
pub fn choose_target_date(
  records : Array[DailyRecord],
  requested : String?,
) -> String? {
  match requested {
    Some(date) =>
      if find_record_index(records, date) is Some(_) {
        Some(date)
      } else {
        None
      }
    None =>
      if records.length() == 0 {
        None
      } else {
        Some(sort_records_by_date(records)[records.length() - 1].date)
      }
  }
}

///|
pub fn workflow_records(
  records : Array[DailyRecord],
  config : WorkflowConfig,
) -> Array[DailyRecord] {
  if config.fill_missing_dates {
    fill_missing_records(records, config.target_sleep)
  } else {
    normalize_records(records)
  }
}

///|
pub fn run_workflow(
  records : Array[DailyRecord],
  config : WorkflowConfig,
) -> WorkflowResult {
  let prepared = workflow_records(records, config)
  let quality = validate_records(prepared, config.quality_policy)
  let target = choose_target_date(prepared, config.target_date)
  let audit = []
  audit.push("input records=" + records.length().to_string())
  audit.push("prepared records=" + prepared.length().to_string())
  audit.push("quality=" + quality_report_text(quality))
  match target {
    None => {
      audit.push("assessment skipped: no valid target date")
      {
        accepted: false,
        input: None,
        records: prepared,
        quality,
        assessment: None,
        report: None,
        timeline: None,
        audit,
      }
    }
    Some(target) => {
      let assessment = assess_comprehensive(prepared, target, config.policy)
      let report = match assessment {
        Some(value) => Some(render_assessment(value, config.report_options))
        None => None
      }
      let timeline = Some(build_timeline(prepared, config.policy))
      audit.push("target date=" + target)
      audit.push(
        "assessment=" +
        (if assessment is Some(_) { "complete" } else { "missing" }),
      )
      {
        accepted: assessment is Some(_) && quality.blocking_issue_count == 0,
        input: None,
        records: prepared,
        quality,
        assessment,
        report,
        timeline,
        audit,
      }
    }
  }
}

///|
pub fn run_csv_workflow(
  text : String,
  config : WorkflowConfig,
) -> WorkflowResult {
  let input = parse_telemetry_csv(text)
  let result = run_workflow(input.records, config)
  { ..result, input: Some(input) }
}

///|
pub fn workflow_is_accepted(result : WorkflowResult) -> Bool {
  result.accepted &&
  result.assessment is Some(_) &&
  result.quality.blocking_issue_count == 0
}

///|
pub fn workflow_report_text(result : WorkflowResult) -> String {
  let builder = StringBuilder::new()
  for line in result.audit {
    builder.write_string(line)
    builder.write_string("\n")
  }
  match result.report {
    Some(report) => builder.write_string(report_text(report))
    None => builder.write_string("no report generated")
  }
  builder.to_string()
}

///|
pub fn workflow_stage_status(result : WorkflowResult) -> Array[String] {
  [
    if result.records.length() > 0 {
      "ingest:ok"
    } else {
      "ingest:empty"
    },
    if result.quality.issue_count == 0 {
      "quality:ok"
    } else {
      "quality:review"
    },
    if result.assessment is Some(_) {
      "assessment:ok"
    } else {
      "assessment:skipped"
    },
    if result.report is Some(_) {
      "report:ok"
    } else {
      "report:missing"
    },
    if result.timeline is Some(_) {
      "timeline:ok"
    } else {
      "timeline:missing"
    },
  ]
}
