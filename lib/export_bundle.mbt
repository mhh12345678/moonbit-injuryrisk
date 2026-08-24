///|
/// Stable export bundle for applications that need one deterministic report.
pub(all) enum ExportSectionKind {
  ExportSummary
  ExportAssessment
  ExportMonitoring
  ExportEvents
  ExportInterventions
  ExportBaseline
  ExportSchedule
  ExportAudit
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ExportSection {
  kind : ExportSectionKind
  title : String
  content : String
  row_count : Int
  included : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ExportBundle {
  run_id : String
  generated_for : String
  sections : Array[ExportSection]
  section_count : Int
  row_count : Int
  format_version : String
  valid : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn export_section_name(kind : ExportSectionKind) -> String {
  match kind {
    ExportSummary => "summary"
    ExportAssessment => "assessment"
    ExportMonitoring => "monitoring"
    ExportEvents => "events"
    ExportInterventions => "interventions"
    ExportBaseline => "baseline"
    ExportSchedule => "schedule"
    ExportAudit => "audit"
  }
}

///|
fn export_section(
  kind : ExportSectionKind,
  title : String,
  content : String,
  row_count : Int,
  included : Bool,
) -> ExportSection {
  { kind, title, content, row_count, included }
}

///|
fn text_line_count(text : String) -> Int {
  if text == "" {
    0
  } else {
    text.split("\n").length()
  }
}

///|
pub fn empty_export_bundle(
  run_id : String,
  generated_for : String,
) -> ExportBundle {
  {
    run_id,
    generated_for,
    sections: [],
    section_count: 0,
    row_count: 0,
    format_version: "1",
    valid: true,
  }
}

///|
pub fn add_export_section(
  bundle : ExportBundle,
  section : ExportSection,
) -> ExportBundle {
  let sections = bundle.sections.filter(item => item.kind != section.kind) +
    [section]
  let rows = sections.fold(init=0, (total, item) => {
    total + (if item.included { item.row_count } else { 0 })
  })
  {
    run_id: bundle.run_id,
    generated_for: bundle.generated_for,
    sections,
    section_count: sections.length(),
    row_count: rows,
    format_version: bundle.format_version,
    valid: bundle.valid && section.title != "",
  }
}

///|
pub fn add_summary_section(
  bundle : ExportBundle,
  summary : String,
) -> ExportBundle {
  add_export_section(
    bundle,
    export_section(
      ExportSummary,
      "summary",
      summary,
      text_line_count(summary),
      true,
    ),
  )
}

///|
pub fn add_assessment_section(
  bundle : ExportBundle,
  assessment : ComprehensiveAssessment?,
) -> ExportBundle {
  match assessment {
    Some(assessment) =>
      add_export_section(
        bundle,
        export_section(
          ExportAssessment,
          "assessment",
          assessment_text(assessment),
          1,
          true,
        ),
      )
    None =>
      add_export_section(
        bundle,
        export_section(
          ExportAssessment,
          "assessment",
          "no assessment",
          0,
          false,
        ),
      )
  }
}

///|
pub fn add_monitoring_section(
  bundle : ExportBundle,
  run : MonitoringRun,
) -> ExportBundle {
  add_export_section(
    bundle,
    export_section(
      ExportMonitoring,
      "monitoring",
      monitoring_run_csv(run),
      run.monitors.length(),
      true,
    ),
  )
}

///|
pub fn add_events_section(
  bundle : ExportBundle,
  log : EventLog,
) -> ExportBundle {
  add_export_section(
    bundle,
    export_section(
      ExportEvents,
      "events",
      event_log_csv(log),
      log.events.length(),
      true,
    ),
  )
}

///|
pub fn add_interventions_section(
  bundle : ExportBundle,
  plan : InterventionPlan,
) -> ExportBundle {
  add_export_section(
    bundle,
    export_section(
      ExportInterventions,
      "interventions",
      intervention_plan_csv(plan),
      plan.interventions.length(),
      true,
    ),
  )
}

///|
pub fn add_baseline_section(
  bundle : ExportBundle,
  report : BaselineReport,
) -> ExportBundle {
  add_export_section(
    bundle,
    export_section(
      ExportBaseline,
      "baseline",
      baseline_report_csv(report),
      report.observations.length(),
      true,
    ),
  )
}

///|
pub fn add_schedule_section(
  bundle : ExportBundle,
  summary : ScheduleSummary,
) -> ExportBundle {
  add_export_section(
    bundle,
    export_section(
      ExportSchedule,
      "schedule",
      schedule_csv(summary),
      summary.days.length(),
      true,
    ),
  )
}

///|
pub fn add_audit_section(
  bundle : ExportBundle,
  trail : DecisionAuditTrail,
) -> ExportBundle {
  add_export_section(
    bundle,
    export_section(
      ExportAudit,
      "audit",
      decision_audit_csv_text(trail),
      trail.entries.length(),
      true,
    ),
  )
}

///|
pub fn build_export_bundle(
  run_id : String,
  generated_for : String,
  assessment : ComprehensiveAssessment?,
  monitoring : MonitoringRun,
  events : EventLog,
  interventions : InterventionPlan?,
  baseline : BaselineReport?,
  schedule : ScheduleSummary?,
  audit : DecisionAuditTrail?,
) -> ExportBundle {
  let bundle = empty_export_bundle(run_id, generated_for)
  let bundle = add_assessment_section(bundle, assessment)
  let bundle = add_monitoring_section(bundle, monitoring)
  let bundle = add_events_section(bundle, events)
  let bundle = match interventions {
    Some(plan) => add_interventions_section(bundle, plan)
    None => bundle
  }
  let bundle = match baseline {
    Some(report) => add_baseline_section(bundle, report)
    None => bundle
  }
  let bundle = match schedule {
    Some(summary) => add_schedule_section(bundle, summary)
    None => bundle
  }
  match audit {
    Some(trail) => add_audit_section(bundle, trail)
    None => bundle
  }
}

///|
pub fn export_section_for(
  bundle : ExportBundle,
  kind : ExportSectionKind,
) -> ExportSection? {
  for section in bundle.sections {
    if section.kind == kind {
      return Some(section)
    }
  }
  None
}

///|
pub fn export_included_sections(bundle : ExportBundle) -> Array[ExportSection] {
  bundle.sections.filter(section => section.included)
}

///|
pub fn export_missing_sections(bundle : ExportBundle) -> Array[String] {
  export_section_kinds()
  .filter(kind => export_section_for(bundle, kind) is None)
  .map(kind => export_section_name(kind))
}

///|
pub fn export_section_kinds() -> Array[ExportSectionKind] {
  [
    ExportSummary,
    ExportAssessment,
    ExportMonitoring,
    ExportEvents,
    ExportInterventions,
    ExportBaseline,
    ExportSchedule,
    ExportAudit,
  ]
}

///|
pub fn export_bundle_text(bundle : ExportBundle) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "run=" +
    bundle.run_id +
    " generated_for=" +
    bundle.generated_for +
    " version=" +
    bundle.format_version +
    " rows=" +
    bundle.row_count.to_string(),
  )
  for section in bundle.sections {
    builder.write_string("\n\n## " + section.title + "\n")
    builder.write_string(section.content)
  }
  builder.to_string()
}

///|
pub fn export_bundle_manifest(bundle : ExportBundle) -> String {
  let builder = StringBuilder()
  builder.write_string("section,title,row_count,included")
  for section in bundle.sections {
    builder.write_string(
      "\n" +
      export_section_name(section.kind) +
      "," +
      section.title +
      "," +
      section.row_count.to_string() +
      "," +
      section.included.to_string(),
    )
  }
  builder.to_string()
}

///|
pub fn export_bundle_section_text(
  bundle : ExportBundle,
  kind : ExportSectionKind,
) -> String {
  match export_section_for(bundle, kind) {
    Some(section) => section.content
    None => ""
  }
}

///|
pub fn export_bundle_has(
  bundle : ExportBundle,
  kind : ExportSectionKind,
) -> Bool {
  export_section_for(bundle, kind) is Some(_)
}

///|
pub fn export_bundle_row_count(
  bundle : ExportBundle,
  kind : ExportSectionKind,
) -> Int {
  match export_section_for(bundle, kind) {
    Some(section) => section.row_count
    None => 0
  }
}

///|
pub fn export_bundle_is_complete(bundle : ExportBundle) -> Bool {
  bundle.valid && export_included_sections(bundle).length() >= 4
}

///|
pub fn export_bundle_is_reproducible(
  left : ExportBundle,
  right : ExportBundle,
) -> Bool {
  export_bundle_manifest(left) == export_bundle_manifest(right) &&
  export_bundle_text(left) == export_bundle_text(right)
}

///|
pub fn export_bundle_summary(bundle : ExportBundle) -> String {
  "run=" +
  bundle.run_id +
  " sections=" +
  bundle.section_count.to_string() +
  " included=" +
  export_included_sections(bundle).length().to_string() +
  " rows=" +
  bundle.row_count.to_string() +
  " complete=" +
  export_bundle_is_complete(bundle).to_string()
}

///|
pub fn export_bundle_valid(bundle : ExportBundle) -> Bool {
  bundle.run_id != "" &&
  bundle.generated_for != "" &&
  bundle.format_version != "" &&
  bundle.sections.all(section => section.title != "" && section.row_count >= 0)
}

///|
pub fn export_bundle_line_count(bundle : ExportBundle) -> Int {
  text_line_count(export_bundle_text(bundle))
}

///|
pub fn export_bundle_csv(bundle : ExportBundle) -> String {
  export_bundle_manifest(bundle)
}
