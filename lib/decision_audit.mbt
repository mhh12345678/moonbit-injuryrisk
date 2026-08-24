///|
/// Deterministic audit trail for reproducible decision-support runs.
pub(all) enum DecisionAuditKind {
  AuditInput
  AuditQuality
  AuditAssessment
  AuditAlert
  AuditIntervention
  AuditExport
  AuditReview
} derive(Debug, Eq, ToJson)

///|
pub(all) struct DecisionAuditEntry {
  sequence : Int
  kind : DecisionAuditKind
  subject : String
  date : String
  outcome : String
  evidence : String
  checksum : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct DecisionAuditTrail {
  run_id : String
  entries : Array[DecisionAuditEntry]
  final_checksum : String
  valid : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn decision_audit_kind_name(kind : DecisionAuditKind) -> String {
  match kind {
    AuditInput => "input"
    AuditQuality => "quality"
    AuditAssessment => "assessment"
    AuditAlert => "alert"
    AuditIntervention => "intervention"
    AuditExport => "export"
    AuditReview => "review"
  }
}

///|
fn checksum_text(text : String) -> String {
  let mut value = 17
  for character in text {
    value = (value * 31 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
fn audit_payload(
  sequence : Int,
  kind : DecisionAuditKind,
  subject : String,
  date : String,
  outcome : String,
  evidence : String,
) -> String {
  sequence.to_string() +
  "|" +
  decision_audit_kind_name(kind) +
  "|" +
  subject +
  "|" +
  date +
  "|" +
  outcome +
  "|" +
  evidence
}

///|
fn make_audit_entry(
  sequence : Int,
  kind : DecisionAuditKind,
  subject : String,
  date : String,
  outcome : String,
  evidence : String,
  previous : String,
) -> DecisionAuditEntry {
  let payload = previous +
    audit_payload(sequence, kind, subject, date, outcome, evidence)
  {
    sequence,
    kind,
    subject,
    date,
    outcome,
    evidence,
    checksum: checksum_text(payload),
  }
}

///|
pub fn new_decision_audit(run_id : String) -> DecisionAuditTrail {
  { run_id, entries: [], final_checksum: checksum_text(run_id), valid: true }
}

///|
pub fn append_decision_audit(
  trail : DecisionAuditTrail,
  kind : DecisionAuditKind,
  subject : String,
  date : String,
  outcome : String,
  evidence : String,
) -> DecisionAuditTrail {
  let sequence = trail.entries.length()
  let previous = if sequence == 0 {
    trail.final_checksum
  } else {
    trail.entries[sequence - 1].checksum
  }
  let entry = make_audit_entry(
    sequence, kind, subject, date, outcome, evidence, previous,
  )
  {
    run_id: trail.run_id,
    entries: trail.entries + [entry],
    final_checksum: entry.checksum,
    valid: trail.valid,
  }
}

///|
pub fn audit_input(
  trail : DecisionAuditTrail,
  records : Array[DailyRecord],
) -> DecisionAuditTrail {
  append_decision_audit(
    trail,
    AuditInput,
    "daily_records",
    "",
    records.length().to_string(),
    "records=" + records.length().to_string(),
  )
}

///|
pub fn audit_quality(
  trail : DecisionAuditTrail,
  report : QualityReport,
) -> DecisionAuditTrail {
  append_decision_audit(
    trail,
    AuditQuality,
    "quality_report",
    "",
    quality_band(report.score),
    quality_report_text(report),
  )
}

///|
pub fn audit_assessment(
  trail : DecisionAuditTrail,
  assessment : ComprehensiveAssessment,
) -> DecisionAuditTrail {
  append_decision_audit(
    trail,
    AuditAssessment,
    "assessment",
    assessment.date,
    risk_level_name(assessment.risk_level),
    assessment.summary,
  )
}

///|
pub fn audit_monitoring(
  trail : DecisionAuditTrail,
  run : MonitoringRun,
) -> DecisionAuditTrail {
  append_decision_audit(
    trail,
    AuditAlert,
    "monitoring",
    run.generated_for,
    run.summary.status,
    monitoring_summary_text(run.summary),
  )
}

///|
pub fn audit_intervention_plan(
  trail : DecisionAuditTrail,
  plan : InterventionPlan,
) -> DecisionAuditTrail {
  append_decision_audit(
    trail,
    AuditIntervention,
    "intervention_plan",
    plan.anchor_date,
    plan.status,
    intervention_plan_text(plan),
  )
}

///|
pub fn audit_export(
  trail : DecisionAuditTrail,
  format : String,
  item_count : Int,
) -> DecisionAuditTrail {
  append_decision_audit(
    trail,
    AuditExport,
    format,
    "",
    item_count.to_string(),
    "exported_items=" + item_count.to_string(),
  )
}

///|
pub fn audit_review(
  trail : DecisionAuditTrail,
  subject : String,
  outcome : String,
  evidence : String,
) -> DecisionAuditTrail {
  append_decision_audit(trail, AuditReview, subject, "", outcome, evidence)
}

///|
fn expected_checksum(entry : DecisionAuditEntry, previous : String) -> String {
  checksum_text(
    previous +
    audit_payload(
      entry.sequence,
      entry.kind,
      entry.subject,
      entry.date,
      entry.outcome,
      entry.evidence,
    ),
  )
}

///|
pub fn verify_decision_audit(trail : DecisionAuditTrail) -> Bool {
  let mut previous = checksum_text(trail.run_id)
  let mut valid = true
  for entry in trail.entries {
    if entry.sequence < 0 ||
      entry.checksum != expected_checksum(entry, previous) {
      valid = false
    }
    previous = entry.checksum
  }
  valid && previous == trail.final_checksum
}

///|
pub fn repair_decision_audit(trail : DecisionAuditTrail) -> DecisionAuditTrail {
  let mut previous = checksum_text(trail.run_id)
  let entries = []
  for index, entry in trail.entries {
    let repaired = make_audit_entry(
      index,
      entry.kind,
      entry.subject,
      entry.date,
      entry.outcome,
      entry.evidence,
      previous,
    )
    entries.push(repaired)
    previous = repaired.checksum
  }
  { run_id: trail.run_id, entries, final_checksum: previous, valid: true }
}

///|
pub fn audit_entry_for_sequence(
  trail : DecisionAuditTrail,
  sequence : Int,
) -> DecisionAuditEntry? {
  for entry in trail.entries {
    if entry.sequence == sequence {
      return Some(entry)
    }
  }
  None
}

///|
pub fn audit_entries_by_kind(
  trail : DecisionAuditTrail,
  kind : DecisionAuditKind,
) -> Array[DecisionAuditEntry] {
  trail.entries.filter(entry => entry.kind == kind)
}

///|
pub fn audit_subjects(trail : DecisionAuditTrail) -> Array[String] {
  let subjects = []
  for entry in trail.entries {
    if !subjects.contains(entry.subject) {
      subjects.push(entry.subject)
    }
  }
  subjects
}

///|
pub fn audit_kind_counts(trail : DecisionAuditTrail) -> Array[Int] {
  decision_audit_kinds().map(kind => audit_entries_by_kind(trail, kind).length())
}

///|
pub fn decision_audit_kinds() -> Array[DecisionAuditKind] {
  [
    AuditInput,
    AuditQuality,
    AuditAssessment,
    AuditAlert,
    AuditIntervention,
    AuditExport,
    AuditReview,
  ]
}

///|
pub fn audit_is_empty(trail : DecisionAuditTrail) -> Bool {
  trail.entries.length() == 0
}

///|
pub fn audit_entry_count(trail : DecisionAuditTrail) -> Int {
  trail.entries.length()
}

///|
pub fn audit_last_outcome(trail : DecisionAuditTrail) -> String? {
  if trail.entries.length() == 0 {
    None
  } else {
    Some(trail.entries[trail.entries.length() - 1].outcome)
  }
}

///|
pub fn audit_has_blocking_outcome(trail : DecisionAuditTrail) -> Bool {
  trail.entries.any(entry => {
    entry.outcome == "critical" ||
    entry.outcome == "action_required" ||
    entry.outcome == "poor"
  })
}

///|
pub fn decision_audit_text(trail : DecisionAuditTrail) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "run=" +
    trail.run_id +
    " entries=" +
    trail.entries.length().to_string() +
    " valid=" +
    verify_decision_audit(trail).to_string() +
    " checksum=" +
    trail.final_checksum,
  )
  for entry in trail.entries {
    builder.write_string("\n")
    builder.write_string(
      entry.sequence.to_string() +
      " " +
      decision_audit_kind_name(entry.kind) +
      " " +
      entry.subject +
      " outcome=" +
      entry.outcome +
      " checksum=" +
      entry.checksum,
    )
  }
  builder.to_string()
}

///|
pub fn decision_audit_csv_header() -> String {
  "sequence,kind,subject,date,outcome,evidence,checksum"
}

///|
pub fn decision_audit_csv(entry : DecisionAuditEntry) -> String {
  entry.sequence.to_string() +
  "," +
  decision_audit_kind_name(entry.kind) +
  "," +
  entry.subject +
  "," +
  entry.date +
  "," +
  entry.outcome +
  "," +
  entry.evidence +
  "," +
  entry.checksum
}

///|
pub fn decision_audit_csv_text(trail : DecisionAuditTrail) -> String {
  let builder = StringBuilder()
  builder.write_string(decision_audit_csv_header())
  for entry in trail.entries {
    builder.write_string("\n")
    builder.write_string(decision_audit_csv(entry))
  }
  builder.to_string()
}

///|
pub fn decision_audit_valid(trail : DecisionAuditTrail) -> Bool {
  trail.run_id != "" &&
  verify_decision_audit(trail) &&
  trail.entries.all(entry => entry.subject != "" && entry.checksum != "")
}
