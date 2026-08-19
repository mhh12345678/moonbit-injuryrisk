///|
/// A deterministic acceptance packet joins decision evidence, governance, and export state.
pub(all) struct AcceptancePacket {
  run : DecisionRun
  performance : PerformanceSnapshot
  governance : GovernanceReport
  evidence : EvidenceMatrix
  queue : ReviewQueueView
  bundle : ExportBundle
  status : String
  recommendation : String
  checksum : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct AcceptancePacketComparison {
  left_status : String
  right_status : String
  left_records : Int
  right_records : Int
  left_risk : Double
  right_risk : Double
  risk_change : Double
  left_quality : Double
  right_quality : Double
  quality_change : Double
  left_open_items : Int
  right_open_items : Int
  open_item_change : Int
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct AcceptanceMetric {
  name : String
  value : Double
  unit : String
  interpretation : String
  within_range : Bool
} derive(Debug, Eq, ToJson)

///|
fn acceptance_packet_status(
  run : DecisionRun,
  governance : GovernanceReport,
  evidence : EvidenceMatrix,
  queue : ReviewQueueView,
) -> String {
  if governance_blocks(governance) || !governance_valid(governance) {
    "blocked"
  } else if !run.accepted ||
    decision_run_requires_action(run) ||
    evidence_requires_review(evidence) ||
    review_queue_requires_review(queue) {
    "review"
  } else {
    "ready"
  }
}

///|
fn acceptance_packet_recommendation(
  status : String,
  run : DecisionRun,
  governance : GovernanceReport,
  evidence : EvidenceMatrix,
  queue : ReviewQueueView,
) -> String {
  if status == "blocked" {
    governance_recommendation_text(governance)
  } else if evidence_requires_review(evidence) {
    evidence_recommendation(evidence)
  } else if review_queue_requires_review(queue) {
    queue.recommendation
  } else if decision_run_requires_action(run) {
    decision_run_recommendation(run)
  } else {
    "release the packet for operational use"
  }
}

///|
fn acceptance_packet_checksum(packet : AcceptancePacket) -> String {
  let payload = packet.run.config.run_id +
    "|" +
    packet.status +
    "|" +
    performance_text(packet.performance) +
    "|" +
    governance_checksum(packet.governance) +
    "|" +
    evidence_matrix_text(packet.evidence) +
    "|" +
    review_queue_text(packet.queue) +
    "|" +
    export_bundle_manifest(packet.bundle)
  let mut value = 23
  for character in payload {
    value = (value * 37 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
fn acceptance_packet_from_parts(
  run : DecisionRun,
  performance : PerformanceSnapshot,
  governance : GovernanceReport,
  evidence : EvidenceMatrix,
  queue : ReviewQueueView,
  bundle : ExportBundle,
) -> AcceptancePacket {
  let status = acceptance_packet_status(run, governance, evidence, queue)
  let recommendation = acceptance_packet_recommendation(
    status, run, governance, evidence, queue,
  )
  let base = {
    run,
    performance,
    governance,
    evidence,
    queue,
    bundle,
    status,
    recommendation,
    checksum: "",
  }
  {
    run: base.run,
    performance: base.performance,
    governance: base.governance,
    evidence: base.evidence,
    queue: base.queue,
    bundle: base.bundle,
    status: base.status,
    recommendation: base.recommendation,
    checksum: acceptance_packet_checksum(base),
  }
}

///|
pub fn build_acceptance_packet(
  records : Array[DailyRecord],
  sessions : Array[TrainingSession],
  config : DecisionRunConfig,
  reference_date : String,
) -> AcceptancePacket {
  let run = run_decision_pipeline(records, config)
  let performance = performance_snapshot(records, sessions, run)
  let governance = govern_records_default(records)
  let evidence = build_evidence_matrix(evidence_from_run(run.monitoring))
  let queue = build_review_queue(build_action_queue(run), reference_date)
  let bundle = decision_run_export(run)
  acceptance_packet_from_parts(
    run, performance, governance, evidence, queue, bundle,
  )
}

///|
pub fn acceptance_packet_for_records(
  records : Array[DailyRecord],
) -> AcceptancePacket {
  let config = default_decision_run_config()
  build_acceptance_packet(records, [], config, "9999-12-31")
}

///|
pub fn acceptance_packet_for_service(
  request : ServiceRequest,
  reference_date : String,
) -> AcceptancePacket {
  build_acceptance_packet(
    request.records,
    request.sessions,
    request.config,
    reference_date,
  )
}

///|
pub fn acceptance_packet_run(packet : AcceptancePacket) -> DecisionRun {
  packet.run
}

///|
pub fn acceptance_packet_performance(
  packet : AcceptancePacket,
) -> PerformanceSnapshot {
  packet.performance
}

///|
pub fn acceptance_packet_governance(
  packet : AcceptancePacket,
) -> GovernanceReport {
  packet.governance
}

///|
pub fn acceptance_packet_evidence(packet : AcceptancePacket) -> EvidenceMatrix {
  packet.evidence
}

///|
pub fn acceptance_packet_queue(packet : AcceptancePacket) -> ReviewQueueView {
  packet.queue
}

///|
pub fn acceptance_packet_export(packet : AcceptancePacket) -> ExportBundle {
  packet.bundle
}

///|
pub fn acceptance_packet_status_value(packet : AcceptancePacket) -> String {
  packet.status
}

///|
pub fn acceptance_packet_recommendation_value(
  packet : AcceptancePacket,
) -> String {
  packet.recommendation
}

///|
pub fn acceptance_packet_checksum_value(packet : AcceptancePacket) -> String {
  packet.checksum
}

///|
pub fn acceptance_packet_record_count(packet : AcceptancePacket) -> Int {
  packet.performance.record_count
}

///|
pub fn acceptance_packet_session_count(packet : AcceptancePacket) -> Int {
  packet.performance.session_count
}

///|
pub fn acceptance_packet_assessment_count(packet : AcceptancePacket) -> Int {
  packet.performance.assessment_count
}

///|
pub fn acceptance_packet_alert_count(packet : AcceptancePacket) -> Int {
  packet.performance.alert_count
}

///|
pub fn acceptance_packet_event_count(packet : AcceptancePacket) -> Int {
  packet.performance.event_count
}

///|
pub fn acceptance_packet_intervention_count(packet : AcceptancePacket) -> Int {
  packet.performance.intervention_count
}

///|
pub fn acceptance_packet_open_item_count(packet : AcceptancePacket) -> Int {
  packet.queue.open_count
}

///|
pub fn acceptance_packet_unresolved_evidence_count(
  packet : AcceptancePacket,
) -> Int {
  packet.evidence.unresolved_count
}

///|
pub fn acceptance_packet_issue_count(packet : AcceptancePacket) -> Int {
  packet.governance.issue_count
}

///|
pub fn acceptance_packet_blocking_issue_count(packet : AcceptancePacket) -> Int {
  packet.governance.blocking_count
}

///|
pub fn acceptance_packet_risk(packet : AcceptancePacket) -> Double {
  decision_run_latest_risk(packet.run)
}

///|
pub fn acceptance_packet_readiness(packet : AcceptancePacket) -> Double {
  decision_run_latest_readiness(packet.run)
}

///|
pub fn acceptance_packet_quality(packet : AcceptancePacket) -> Double {
  packet.performance.quality_score
}

///|
pub fn acceptance_packet_coverage(packet : AcceptancePacket) -> Double {
  packet.performance.coverage_percent
}

///|
pub fn acceptance_packet_recovery(packet : AcceptancePacket) -> Double {
  packet.performance.recovery_mean
}

///|
pub fn acceptance_packet_operational_score(packet : AcceptancePacket) -> Double {
  performance_score(packet.performance)
}

///|
pub fn acceptance_packet_governance_score(packet : AcceptancePacket) -> Double {
  governance_score(packet.governance)
}

///|
pub fn acceptance_packet_evidence_confidence(
  packet : AcceptancePacket,
) -> Double {
  packet.evidence.confidence
}

///|
pub fn acceptance_packet_queue_score(packet : AcceptancePacket) -> Double {
  packet.queue.average_score
}

///|
pub fn acceptance_packet_accepted(packet : AcceptancePacket) -> Bool {
  packet.status == "ready" && packet.run.accepted
}

///|
pub fn acceptance_packet_needs_review(packet : AcceptancePacket) -> Bool {
  packet.status == "review"
}

///|
pub fn acceptance_packet_blocked(packet : AcceptancePacket) -> Bool {
  packet.status == "blocked"
}

///|
pub fn acceptance_packet_exportable(packet : AcceptancePacket) -> Bool {
  packet.status != "blocked" &&
  export_bundle_is_complete(packet.bundle) &&
  governance_exportable(packet.governance)
}

///|
pub fn acceptance_packet_has_audit(packet : AcceptancePacket) -> Bool {
  decision_run_audit_valid(packet.run)
}

///|
pub fn acceptance_packet_has_quality(packet : AcceptancePacket) -> Bool {
  decision_run_quality_valid(packet.run)
}

///|
pub fn acceptance_packet_has_evidence(packet : AcceptancePacket) -> Bool {
  packet.evidence.items.length() > 0
}

///|
pub fn acceptance_packet_has_queue_work(packet : AcceptancePacket) -> Bool {
  packet.queue.open_count > 0
}

///|
pub fn acceptance_packet_is_reproducible(
  left : AcceptancePacket,
  right : AcceptancePacket,
) -> Bool {
  left.checksum == right.checksum &&
  decision_run_is_reproducible(left.run, right.run)
}

///|
pub fn acceptance_packet_valid(packet : AcceptancePacket) -> Bool {
  packet.run.config.run_id != "" &&
  packet.status != "" &&
  packet.recommendation != "" &&
  packet.checksum == acceptance_packet_checksum(packet) &&
  decision_run_valid(packet.run) &&
  performance_snapshot_valid(packet.performance) &&
  governance_valid(packet.governance) &&
  evidence_matrix_valid(packet.evidence) &&
  review_queue_valid(packet.queue) &&
  export_bundle_valid(packet.bundle)
}

///|
pub fn acceptance_packet_contract(packet : AcceptancePacket) -> Array[String] {
  [
    packet.run.config.run_id,
    packet.status,
    packet.performance.status,
    governance_status_text(packet.governance),
    packet.evidence.status,
    packet.queue.status,
    packet.recommendation,
    acceptance_packet_exportable(packet).to_string(),
    packet.checksum,
  ]
}

///|
pub fn acceptance_packet_contract_valid(packet : AcceptancePacket) -> Bool {
  acceptance_packet_valid(packet) &&
  acceptance_packet_contract(packet).length() == 9
}

///|
pub fn acceptance_packet_status_code(packet : AcceptancePacket) -> Int {
  if packet.status == "ready" {
    200
  } else if packet.status == "review" {
    206
  } else if packet.status == "blocked" {
    422
  } else {
    500
  }
}

///|
pub fn acceptance_packet_status_label(packet : AcceptancePacket) -> String {
  packet.status + "(" + acceptance_packet_status_code(packet).to_string() + ")"
}

///|
pub fn acceptance_packet_priority(packet : AcceptancePacket) -> Int {
  if acceptance_packet_blocked(packet) {
    3
  } else if acceptance_packet_needs_review(packet) {
    2
  } else {
    0
  }
}

///|
pub fn acceptance_packet_review_label(packet : AcceptancePacket) -> String {
  "priority_" + acceptance_packet_priority(packet).to_string()
}

///|
pub fn acceptance_packet_release_label(packet : AcceptancePacket) -> String {
  if acceptance_packet_exportable(packet) && acceptance_packet_accepted(packet) {
    "release"
  } else if acceptance_packet_blocked(packet) {
    "hold"
  } else {
    "review"
  }
}

///|
pub fn acceptance_packet_quality_band(packet : AcceptancePacket) -> String {
  governance_quality_band(packet.governance)
}

///|
pub fn acceptance_packet_evidence_band(packet : AcceptancePacket) -> String {
  evidence_confidence_band(packet.evidence)
}

///|
pub fn acceptance_packet_queue_status(packet : AcceptancePacket) -> String {
  review_queue_status(packet.queue)
}

///|
pub fn acceptance_packet_audit_count(packet : AcceptancePacket) -> Int {
  audit_entry_count(packet.run.audit)
}

///|
pub fn acceptance_packet_export_section_count(packet : AcceptancePacket) -> Int {
  packet.bundle.section_count
}

///|
pub fn acceptance_packet_export_row_count(packet : AcceptancePacket) -> Int {
  packet.bundle.row_count
}

///|
pub fn acceptance_packet_progression_allowed(packet : AcceptancePacket) -> Bool {
  acceptance_packet_accepted(packet) &&
  packet.evidence.high_count == 0 &&
  packet.queue.critical_count == 0
}

///|
pub fn acceptance_packet_requires_follow_up(packet : AcceptancePacket) -> Bool {
  packet.queue.open_count > 0 ||
  packet.evidence.unresolved_count > 0 ||
  packet.governance.issue_count > 0
}

///|
pub fn acceptance_packet_follow_up_count(packet : AcceptancePacket) -> Int {
  packet.queue.open_count +
  packet.evidence.unresolved_count +
  packet.governance.issue_count
}

///|
pub fn acceptance_packet_data_ready(packet : AcceptancePacket) -> Bool {
  acceptance_packet_governance_ready(packet) &&
  packet.performance.quality_score >= 80.0 &&
  packet.performance.coverage_percent >= 80.0
}

///|
pub fn acceptance_packet_governance_ready(packet : AcceptancePacket) -> Bool {
  governance_ready(packet.governance)
}

///|
pub fn acceptance_packet_audit_ready(packet : AcceptancePacket) -> Bool {
  acceptance_packet_has_audit(packet) && packet.run.audit.entries.length() > 0
}

///|
pub fn acceptance_packet_release_ready(packet : AcceptancePacket) -> Bool {
  acceptance_packet_data_ready(packet) &&
  acceptance_packet_audit_ready(packet) &&
  acceptance_packet_exportable(packet) &&
  acceptance_packet_progression_allowed(packet)
}

///|
pub fn acceptance_packet_metric(
  packet : AcceptancePacket,
  name : String,
) -> Double {
  match name {
    "risk" => acceptance_packet_risk(packet)
    "readiness" => acceptance_packet_readiness(packet)
    "quality" => acceptance_packet_quality(packet)
    "coverage" => acceptance_packet_coverage(packet)
    "recovery" => acceptance_packet_recovery(packet)
    "operational_score" => acceptance_packet_operational_score(packet)
    "governance_score" => acceptance_packet_governance_score(packet)
    "evidence_confidence" =>
      acceptance_packet_evidence_confidence(packet) * 100.0
    "queue_score" => acceptance_packet_queue_score(packet)
    "records" => acceptance_packet_record_count(packet).to_double()
    "open_items" => acceptance_packet_open_item_count(packet).to_double()
    "follow_up" => acceptance_packet_follow_up_count(packet).to_double()
    _ => 0.0
  }
}

///|
pub fn acceptance_packet_metric_names() -> Array[String] {
  [
    "risk", "readiness", "quality", "coverage", "recovery", "operational_score",
    "governance_score", "evidence_confidence", "queue_score", "records", "open_items",
    "follow_up",
  ]
}

///|
pub fn acceptance_packet_metrics(
  packet : AcceptancePacket,
) -> Array[AcceptanceMetric] {
  [
    {
      name: "risk",
      value: acceptance_packet_risk(packet),
      unit: "score",
      interpretation: "lower is safer",
      within_range: acceptance_packet_risk(packet) >= 0.0 &&
      acceptance_packet_risk(packet) <= 100.0,
    },
    {
      name: "readiness",
      value: acceptance_packet_readiness(packet),
      unit: "score",
      interpretation: "higher is more ready",
      within_range: acceptance_packet_readiness(packet) >= 0.0 &&
      acceptance_packet_readiness(packet) <= 100.0,
    },
    {
      name: "quality",
      value: acceptance_packet_quality(packet),
      unit: "percent",
      interpretation: "input quality",
      within_range: acceptance_packet_quality(packet) >= 0.0 &&
      acceptance_packet_quality(packet) <= 100.0,
    },
    {
      name: "coverage",
      value: acceptance_packet_coverage(packet),
      unit: "percent",
      interpretation: "record coverage",
      within_range: acceptance_packet_coverage(packet) >= 0.0 &&
      acceptance_packet_coverage(packet) <= 100.0,
    },
    {
      name: "recovery",
      value: acceptance_packet_recovery(packet),
      unit: "score",
      interpretation: "recovery reserve",
      within_range: acceptance_packet_recovery(packet) >= 0.0 &&
      acceptance_packet_recovery(packet) <= 100.0,
    },
    {
      name: "operational_score",
      value: acceptance_packet_operational_score(packet),
      unit: "score",
      interpretation: "pipeline health",
      within_range: true,
    },
    {
      name: "governance_score",
      value: acceptance_packet_governance_score(packet),
      unit: "score",
      interpretation: "data trust",
      within_range: true,
    },
    {
      name: "evidence_confidence",
      value: acceptance_packet_evidence_confidence(packet) * 100.0,
      unit: "percent",
      interpretation: "evidence confidence",
      within_range: true,
    },
    {
      name: "queue_score",
      value: acceptance_packet_queue_score(packet),
      unit: "score",
      interpretation: "open work score",
      within_range: true,
    },
  ]
}

///|
pub fn acceptance_packet_metric_values(
  packet : AcceptancePacket,
) -> Array[Double] {
  acceptance_packet_metrics(packet).map(metric => metric.value)
}

///|
pub fn acceptance_packet_metric_by_name(
  packet : AcceptancePacket,
  name : String,
) -> AcceptanceMetric? {
  for metric in acceptance_packet_metrics(packet) {
    if metric.name == name {
      return Some(metric)
    }
  }
  None
}

///|
pub fn acceptance_packet_metric_valid(metric : AcceptanceMetric) -> Bool {
  metric.name != "" &&
  metric.unit != "" &&
  metric.interpretation != "" &&
  !metric.value.is_nan()
}

///|
pub fn acceptance_packet_metrics_valid(packet : AcceptancePacket) -> Bool {
  acceptance_packet_metrics(packet).all(metric => {
    acceptance_packet_metric_valid(metric) && metric.within_range
  })
}

///|
pub fn acceptance_packet_score(packet : AcceptancePacket) -> Double {
  let base = acceptance_packet_quality(packet) * 0.25 +
    acceptance_packet_coverage(packet) * 0.20 +
    acceptance_packet_readiness(packet) * 0.20 +
    acceptance_packet_recovery(packet) * 0.15 +
    acceptance_packet_governance_score(packet) * 0.10 +
    acceptance_packet_operational_score(packet) * 0.10
  base.min(100.0).max(0.0)
}

///|
pub fn acceptance_packet_score_band(packet : AcceptancePacket) -> String {
  let score = acceptance_packet_score(packet)
  if score >= 90.0 {
    "excellent"
  } else if score >= 80.0 {
    "good"
  } else if score >= 60.0 {
    "watch"
  } else {
    "poor"
  }
}

///|
pub fn acceptance_packet_score_passes(
  packet : AcceptancePacket,
  floor : Double,
) -> Bool {
  acceptance_packet_score(packet) >= floor && !acceptance_packet_blocked(packet)
}

///|
pub fn acceptance_packet_risk_band(packet : AcceptancePacket) -> String {
  if acceptance_packet_risk(packet) >= 75.0 {
    "high"
  } else if acceptance_packet_risk(packet) >= 50.0 {
    "medium"
  } else {
    "low"
  }
}

///|
pub fn acceptance_packet_readiness_band(packet : AcceptancePacket) -> String {
  if acceptance_packet_readiness(packet) >= 80.0 {
    "ready"
  } else if acceptance_packet_readiness(packet) >= 60.0 {
    "watch"
  } else {
    "limited"
  }
}

///|
pub fn acceptance_packet_load_band(packet : AcceptancePacket) -> String {
  if packet.performance.load_mean >= 8.0 {
    "high"
  } else if packet.performance.load_mean >= 5.0 {
    "moderate"
  } else {
    "low"
  }
}

///|
pub fn acceptance_packet_recovery_band(packet : AcceptancePacket) -> String {
  if acceptance_packet_recovery(packet) >= 80.0 {
    "strong"
  } else if acceptance_packet_recovery(packet) >= 60.0 {
    "adequate"
  } else {
    "limited"
  }
}

///|
pub fn acceptance_packet_threshold_passes(
  packet : AcceptancePacket,
  quality_floor : Double,
  coverage_floor : Double,
) -> Bool {
  acceptance_packet_quality(packet) >= quality_floor &&
  acceptance_packet_coverage(packet) >= coverage_floor
}

///|
pub fn acceptance_packet_alert_rate(packet : AcceptancePacket) -> Double {
  performance_alert_rate(packet.performance)
}

///|
pub fn acceptance_packet_event_rate(packet : AcceptancePacket) -> Double {
  performance_event_rate(packet.performance)
}

///|
pub fn acceptance_packet_intervention_rate(packet : AcceptancePacket) -> Double {
  performance_intervention_rate(packet.performance)
}

///|
pub fn acceptance_packet_follow_up_rate(packet : AcceptancePacket) -> Double {
  if acceptance_packet_record_count(packet) == 0 {
    0.0
  } else {
    acceptance_packet_follow_up_count(packet).to_double() /
    acceptance_packet_record_count(packet).to_double() *
    100.0
  }
}

///|
pub fn acceptance_packet_evidence_resolution_rate(
  packet : AcceptancePacket,
) -> Double {
  if packet.evidence.items.length() == 0 {
    100.0
  } else {
    (packet.evidence.items.length() - packet.evidence.unresolved_count).to_double() /
    packet.evidence.items.length().to_double() *
    100.0
  }
}

///|
pub fn acceptance_packet_queue_clearance_rate(
  packet : AcceptancePacket,
) -> Double {
  if packet.queue.rows.length() == 0 {
    100.0
  } else {
    (packet.queue.rows.length() - packet.queue.open_count).to_double() /
    packet.queue.rows.length().to_double() *
    100.0
  }
}

///|
pub fn acceptance_packet_issue_rate(packet : AcceptancePacket) -> Double {
  governance_issue_rate(packet.governance)
}

///|
pub fn acceptance_packet_blocking_rate(packet : AcceptancePacket) -> Double {
  governance_blocking_rate(packet.governance)
}

///|
pub fn acceptance_packet_processing_units(packet : AcceptancePacket) -> Int {
  packet.performance.processing_units
}

///|
pub fn acceptance_packet_throughput(packet : AcceptancePacket) -> Double {
  performance_throughput(packet.performance)
}

///|
pub fn acceptance_packet_rates(packet : AcceptancePacket) -> Array[Double] {
  [
    acceptance_packet_alert_rate(packet),
    acceptance_packet_event_rate(packet),
    acceptance_packet_intervention_rate(packet),
    acceptance_packet_follow_up_rate(packet),
    acceptance_packet_evidence_resolution_rate(packet),
    acceptance_packet_queue_clearance_rate(packet),
  ]
}

///|
pub fn acceptance_packet_rate_average(packet : AcceptancePacket) -> Double {
  mean_load_values(acceptance_packet_rates(packet))
}

///|
pub fn acceptance_packet_rate_deviation(packet : AcceptancePacket) -> Double {
  standard_deviation_values(acceptance_packet_rates(packet))
}

///|
pub fn acceptance_packet_evidence_items(
  packet : AcceptancePacket,
) -> Array[EvidenceItem] {
  packet.evidence.items
}

///|
pub fn acceptance_packet_unresolved_evidence(
  packet : AcceptancePacket,
) -> Array[EvidenceItem] {
  evidence_unresolved(packet.evidence)
}

///|
pub fn acceptance_packet_high_evidence(
  packet : AcceptancePacket,
) -> Array[EvidenceItem] {
  evidence_by_severity(packet.evidence, High)
}

///|
pub fn acceptance_packet_medium_evidence(
  packet : AcceptancePacket,
) -> Array[EvidenceItem] {
  evidence_by_severity(packet.evidence, Medium)
}

///|
pub fn acceptance_packet_evidence_domains(
  packet : AcceptancePacket,
) -> Array[String] {
  evidence_domains(packet.evidence)
}

///|
pub fn acceptance_packet_evidence_actions(
  packet : AcceptancePacket,
) -> Array[String] {
  evidence_actions(packet.evidence)
}

///|
pub fn acceptance_packet_resolve_evidence(
  packet : AcceptancePacket,
  id : String,
) -> AcceptancePacket {
  let evidence = evidence_resolve(packet.evidence, id)
  acceptance_packet_from_parts(
    packet.run,
    packet.performance,
    packet.governance,
    evidence,
    packet.queue,
    packet.bundle,
  )
}

///|
pub fn acceptance_packet_queue_rows(
  packet : AcceptancePacket,
) -> Array[ReviewQueueRow] {
  packet.queue.rows
}

///|
pub fn acceptance_packet_open_queue(
  packet : AcceptancePacket,
) -> Array[ReviewQueueRow] {
  review_queue_open(packet.queue)
}

///|
pub fn acceptance_packet_overdue_queue(
  packet : AcceptancePacket,
) -> Array[ReviewQueueRow] {
  review_queue_overdue(packet.queue)
}

///|
pub fn acceptance_packet_critical_queue(
  packet : AcceptancePacket,
) -> Array[ReviewQueueRow] {
  review_queue_critical(packet.queue)
}

///|
pub fn acceptance_packet_urgent_queue(
  packet : AcceptancePacket,
) -> Array[ReviewQueueRow] {
  review_queue_urgent(packet.queue)
}

///|
pub fn acceptance_packet_queue_categories(
  packet : AcceptancePacket,
) -> Array[String] {
  review_queue_categories(packet.queue)
}

///|
pub fn acceptance_packet_queue_actions(
  packet : AcceptancePacket,
) -> Array[String] {
  packet.queue.rows.map(row => row.action)
}

///|
pub fn acceptance_packet_queue_priority_counts(
  packet : AcceptancePacket,
) -> Array[Int] {
  review_queue_priority_counts(packet.queue)
}

///|
pub fn acceptance_packet_governance_issues(
  packet : AcceptancePacket,
) -> Array[GovernanceIssue] {
  packet.governance.issues
}

///|
pub fn acceptance_packet_blocking_issues(
  packet : AcceptancePacket,
) -> Array[GovernanceIssue] {
  governance_blocking_issues(packet.governance)
}

///|
pub fn acceptance_packet_warning_issues(
  packet : AcceptancePacket,
) -> Array[GovernanceIssue] {
  governance_warning_issues(packet.governance)
}

///|
pub fn acceptance_packet_issue_fields(
  packet : AcceptancePacket,
) -> Array[String] {
  governance_issue_fields(packet.governance)
}

///|
pub fn acceptance_packet_repair_plan(
  packet : AcceptancePacket,
) -> Array[String] {
  governance_repair_plan(packet.governance)
}

///|
pub fn acceptance_packet_lineage(packet : AcceptancePacket) -> DataLineage {
  packet.governance.lineage
}

///|
pub fn acceptance_packet_transformations(
  packet : AcceptancePacket,
) -> Array[String] {
  governance_transformations(packet.governance)
}

///|
pub fn acceptance_packet_audit_entries(
  packet : AcceptancePacket,
) -> Array[DecisionAuditEntry] {
  packet.run.audit.entries
}

///|
pub fn acceptance_packet_audit_kinds(packet : AcceptancePacket) -> Array[Int] {
  audit_kind_counts(packet.run.audit)
}

///|
pub fn acceptance_packet_last_audit_outcome(
  packet : AcceptancePacket,
) -> String {
  match audit_last_outcome(packet.run.audit) {
    Some(value) => value
    None => "none"
  }
}

///|
pub fn acceptance_packet_export_sections(
  packet : AcceptancePacket,
) -> Array[ExportSection] {
  packet.bundle.sections
}

///|
pub fn acceptance_packet_included_sections(
  packet : AcceptancePacket,
) -> Array[ExportSection] {
  export_included_sections(packet.bundle)
}

///|
pub fn acceptance_packet_missing_sections(
  packet : AcceptancePacket,
) -> Array[String] {
  export_missing_sections(packet.bundle)
}

///|
pub fn acceptance_packet_section_names(
  packet : AcceptancePacket,
) -> Array[String] {
  packet.bundle.sections.map(section => export_section_name(section.kind))
}

///|
pub fn acceptance_packet_section_rows(packet : AcceptancePacket) -> Array[Int] {
  packet.bundle.sections.map(section => section.row_count)
}

///|
pub fn acceptance_packet_section_text(
  packet : AcceptancePacket,
  kind : ExportSectionKind,
) -> String {
  export_bundle_section_text(packet.bundle, kind)
}

///|
pub fn acceptance_packet_text(packet : AcceptancePacket) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "status=" +
    packet.status +
    " release=" +
    acceptance_packet_release_label(packet) +
    " score=" +
    acceptance_packet_score(packet).to_string(),
  )
  builder.write_string("\nrun=" + decision_run_summary(packet.run))
  builder.write_string("\nperformance=" + performance_text(packet.performance))
  builder.write_string("\ngovernance=" + governance_text(packet.governance))
  builder.write_string("\nevidence=" + evidence_matrix_text(packet.evidence))
  builder.write_string("\nqueue=" + review_queue_text(packet.queue))
  builder.write_string("\nrecommendation=" + packet.recommendation)
  builder.write_string("\nchecksum=" + packet.checksum)
  builder.to_string()
}

///|
pub fn acceptance_packet_summary(packet : AcceptancePacket) -> String {
  "run=" +
  packet.run.config.run_id +
  " status=" +
  packet.status +
  " records=" +
  acceptance_packet_record_count(packet).to_string() +
  " risk=" +
  acceptance_packet_risk(packet).to_string() +
  " readiness=" +
  acceptance_packet_readiness(packet).to_string() +
  " quality=" +
  acceptance_packet_quality(packet).to_string() +
  " open=" +
  acceptance_packet_open_item_count(packet).to_string() +
  " score=" +
  acceptance_packet_score(packet).to_string()
}

///|
pub fn acceptance_packet_recommendation_text(
  packet : AcceptancePacket,
) -> String {
  packet.recommendation
}

///|
pub fn acceptance_packet_metric_text(metric : AcceptanceMetric) -> String {
  metric.name +
  "=" +
  metric.value.to_string() +
  " " +
  metric.unit +
  " " +
  metric.interpretation +
  " valid=" +
  metric.within_range.to_string()
}

///|
pub fn acceptance_packet_metrics_text(packet : AcceptancePacket) -> String {
  let builder = StringBuilder::new()
  for metric in acceptance_packet_metrics(packet) {
    builder.write_string("\n" + acceptance_packet_metric_text(metric))
  }
  builder.to_string()
}

///|
pub fn acceptance_packet_text_with_metrics(packet : AcceptancePacket) -> String {
  acceptance_packet_text(packet) +
  "\nmetrics=" +
  acceptance_packet_metrics_text(packet)
}

///|
pub fn acceptance_packet_csv_header() -> String {
  "run_id,status,release,records,sessions,assessments,risk,readiness,quality,coverage,recovery,alerts,events,interventions,open_items,evidence_unresolved,governance_issues,score,checksum"
}

///|
pub fn acceptance_packet_csv_row(packet : AcceptancePacket) -> String {
  packet.run.config.run_id +
  "," +
  packet.status +
  "," +
  acceptance_packet_release_label(packet) +
  "," +
  acceptance_packet_record_count(packet).to_string() +
  "," +
  acceptance_packet_session_count(packet).to_string() +
  "," +
  acceptance_packet_assessment_count(packet).to_string() +
  "," +
  acceptance_packet_risk(packet).to_string() +
  "," +
  acceptance_packet_readiness(packet).to_string() +
  "," +
  acceptance_packet_quality(packet).to_string() +
  "," +
  acceptance_packet_coverage(packet).to_string() +
  "," +
  acceptance_packet_recovery(packet).to_string() +
  "," +
  acceptance_packet_alert_count(packet).to_string() +
  "," +
  acceptance_packet_event_count(packet).to_string() +
  "," +
  acceptance_packet_intervention_count(packet).to_string() +
  "," +
  acceptance_packet_open_item_count(packet).to_string() +
  "," +
  acceptance_packet_unresolved_evidence_count(packet).to_string() +
  "," +
  acceptance_packet_issue_count(packet).to_string() +
  "," +
  acceptance_packet_score(packet).to_string() +
  "," +
  packet.checksum
}

///|
pub fn acceptance_packet_csv(packet : AcceptancePacket) -> String {
  acceptance_packet_csv_header() + "\n" + acceptance_packet_csv_row(packet)
}

///|
pub fn acceptance_packet_metric_csv_header() -> String {
  "name,value,unit,interpretation,within_range"
}

///|
pub fn acceptance_packet_metric_csv(metric : AcceptanceMetric) -> String {
  metric.name +
  "," +
  metric.value.to_string() +
  "," +
  metric.unit +
  "," +
  metric.interpretation +
  "," +
  metric.within_range.to_string()
}

///|
pub fn acceptance_packet_metrics_csv(packet : AcceptancePacket) -> String {
  let builder = StringBuilder::new()
  builder.write_string(acceptance_packet_metric_csv_header())
  for metric in acceptance_packet_metrics(packet) {
    builder.write_string("\n" + acceptance_packet_metric_csv(metric))
  }
  builder.to_string()
}

///|
pub fn acceptance_packet_manifest(packet : AcceptancePacket) -> Array[String] {
  [
    packet.run.config.run_id,
    packet.status,
    acceptance_packet_release_label(packet),
    packet.performance.status,
    governance_status_text(packet.governance),
    packet.evidence.status,
    packet.queue.status,
    acceptance_packet_score_band(packet),
    packet.checksum,
  ]
}

///|
pub fn acceptance_packet_manifest_csv(packet : AcceptancePacket) -> String {
  [
    "run_id", "status", "release", "performance", "governance", "evidence", "queue",
    "score_band", "checksum",
  ].join(",") +
  "\n" +
  acceptance_packet_manifest(packet).join(",")
}

///|
pub fn acceptance_packet_export_text(packet : AcceptancePacket) -> String {
  export_bundle_text(packet.bundle) +
  "\n\n## acceptance\n" +
  acceptance_packet_summary(packet)
}

///|
pub fn acceptance_packet_export_manifest(packet : AcceptancePacket) -> String {
  export_bundle_manifest(packet.bundle) +
  "\n" +
  acceptance_packet_manifest_csv(packet)
}

///|
pub fn acceptance_packet_hash_text(packet : AcceptancePacket) -> String {
  packet.checksum + ":" + acceptance_packet_summary(packet)
}

///|
pub fn acceptance_packet_compare(
  left : AcceptancePacket,
  right : AcceptancePacket,
) -> AcceptancePacketComparison {
  let risk_change = acceptance_packet_risk(right) - acceptance_packet_risk(left)
  let quality_change = acceptance_packet_quality(right) -
    acceptance_packet_quality(left)
  let open_change = acceptance_packet_open_item_count(right) -
    acceptance_packet_open_item_count(left)
  let conclusion = if risk_change < 0.0 &&
    quality_change >= 0.0 &&
    open_change <= 0 {
    "packet outcomes improved"
  } else if risk_change > 0.0 || open_change > 0 {
    "packet burden increased"
  } else {
    "packet outcomes are mixed"
  }
  {
    left_status: left.status,
    right_status: right.status,
    left_records: acceptance_packet_record_count(left),
    right_records: acceptance_packet_record_count(right),
    left_risk: acceptance_packet_risk(left),
    right_risk: acceptance_packet_risk(right),
    risk_change,
    left_quality: acceptance_packet_quality(left),
    right_quality: acceptance_packet_quality(right),
    quality_change,
    left_open_items: acceptance_packet_open_item_count(left),
    right_open_items: acceptance_packet_open_item_count(right),
    open_item_change: open_change,
    conclusion,
  }
}

///|
pub fn acceptance_packet_comparison_text(
  comparison : AcceptancePacketComparison,
) -> String {
  "status=" +
  comparison.left_status +
  " -> " +
  comparison.right_status +
  " records=" +
  comparison.left_records.to_string() +
  " -> " +
  comparison.right_records.to_string() +
  " risk_change=" +
  comparison.risk_change.to_string() +
  " quality_change=" +
  comparison.quality_change.to_string() +
  " open_change=" +
  comparison.open_item_change.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn acceptance_packet_comparison_csv(
  comparison : AcceptancePacketComparison,
) -> String {
  "left_status,right_status,left_records,right_records,left_risk,right_risk,risk_change,left_quality,right_quality,quality_change,left_open_items,right_open_items,open_item_change,conclusion\n" +
  comparison.left_status +
  "," +
  comparison.right_status +
  "," +
  comparison.left_records.to_string() +
  "," +
  comparison.right_records.to_string() +
  "," +
  comparison.left_risk.to_string() +
  "," +
  comparison.right_risk.to_string() +
  "," +
  comparison.risk_change.to_string() +
  "," +
  comparison.left_quality.to_string() +
  "," +
  comparison.right_quality.to_string() +
  "," +
  comparison.quality_change.to_string() +
  "," +
  comparison.left_open_items.to_string() +
  "," +
  comparison.right_open_items.to_string() +
  "," +
  comparison.open_item_change.to_string() +
  "," +
  comparison.conclusion
}

///|
pub fn acceptance_packet_improved(
  comparison : AcceptancePacketComparison,
) -> Bool {
  comparison.risk_change < 0.0 &&
  comparison.quality_change >= 0.0 &&
  comparison.open_item_change <= 0
}

///|
pub fn acceptance_packet_worsened(
  comparison : AcceptancePacketComparison,
) -> Bool {
  comparison.risk_change > 0.0 || comparison.open_item_change > 0
}

///|
pub fn acceptance_packet_stable(
  comparison : AcceptancePacketComparison,
) -> Bool {
  !acceptance_packet_improved(comparison) &&
  !acceptance_packet_worsened(comparison)
}

///|
pub fn acceptance_packet_status_changed(
  comparison : AcceptancePacketComparison,
) -> Bool {
  comparison.left_status != comparison.right_status
}

///|
pub fn acceptance_packet_risk_delta(
  comparison : AcceptancePacketComparison,
) -> Double {
  comparison.risk_change
}

///|
pub fn acceptance_packet_quality_delta(
  comparison : AcceptancePacketComparison,
) -> Double {
  comparison.quality_change
}

///|
pub fn acceptance_packet_open_delta(
  comparison : AcceptancePacketComparison,
) -> Int {
  comparison.open_item_change
}

///|
pub fn acceptance_packet_comparison_valid(
  comparison : AcceptancePacketComparison,
) -> Bool {
  comparison.left_status != "" &&
  comparison.right_status != "" &&
  comparison.left_records >= 0 &&
  comparison.right_records >= 0 &&
  comparison.left_risk >= 0.0 &&
  comparison.left_risk <= 100.0 &&
  comparison.right_risk >= 0.0 &&
  comparison.right_risk <= 100.0 &&
  comparison.left_quality >= 0.0 &&
  comparison.left_quality <= 100.0 &&
  comparison.right_quality >= 0.0 &&
  comparison.right_quality <= 100.0 &&
  comparison.conclusion != ""
}

///|
pub fn acceptance_packet_for_date(
  records : Array[DailyRecord],
  date : String,
) -> AcceptancePacket {
  let filtered = records.filter(record => record.date <= date)
  let config = default_decision_run_config()
  build_acceptance_packet(filtered, [], config, date)
}

///|
pub fn acceptance_packet_for_window(
  records : Array[DailyRecord],
  start_date : String,
  end_date : String,
) -> AcceptancePacket {
  let filtered = records.filter(record => {
    record.date >= start_date && record.date <= end_date
  })
  let config = default_decision_run_config()
  build_acceptance_packet(filtered, [], config, end_date)
}

///|
pub fn acceptance_packet_filter_valid_records(
  records : Array[DailyRecord],
) -> Array[DailyRecord] {
  records.filter(record => {
    record.date != "" &&
    record.training_duration >= 0.0 &&
    record.training_intensity >= 0.0 &&
    record.training_intensity <= 10.0 &&
    record.pain_level >= 0.0 &&
    record.pain_level <= 10.0 &&
    record.sleep_hours >= 0.0 &&
    record.sleep_hours <= 24.0
  })
}

///|
pub fn acceptance_packet_valid_record_rate(
  records : Array[DailyRecord],
) -> Double {
  if records.length() == 0 {
    0.0
  } else {
    acceptance_packet_filter_valid_records(records).length().to_double() /
    records.length().to_double() *
    100.0
  }
}

///|
pub fn acceptance_packet_has_date(
  records : Array[DailyRecord],
  date : String,
) -> Bool {
  records.any(record => record.date == date)
}

///|
pub fn acceptance_packet_dates(records : Array[DailyRecord]) -> Array[String] {
  records.map(record => record.date)
}

///|
pub fn acceptance_packet_metric_projection(
  packet : AcceptancePacket,
  names : Array[String],
) -> Array[Double] {
  names.map(name => acceptance_packet_metric(packet, name))
}

///|
pub fn acceptance_packet_metric_average(
  packet : AcceptancePacket,
  names : Array[String],
) -> Double {
  mean_load_values(acceptance_packet_metric_projection(packet, names))
}

///|
pub fn acceptance_packet_metric_minimum(
  packet : AcceptancePacket,
  names : Array[String],
) -> Double {
  minimum_load_values(acceptance_packet_metric_projection(packet, names))
}

///|
pub fn acceptance_packet_metric_maximum(
  packet : AcceptancePacket,
  names : Array[String],
) -> Double {
  maximum_load_values(acceptance_packet_metric_projection(packet, names))
}

///|
pub fn acceptance_packet_metric_deviation(
  packet : AcceptancePacket,
  names : Array[String],
) -> Double {
  standard_deviation_values(acceptance_packet_metric_projection(packet, names))
}

///|
pub fn acceptance_packet_metric_trend(
  packet : AcceptancePacket,
  names : Array[String],
) -> LoadTrend {
  load_trend(acceptance_packet_metric_projection(packet, names), 0.1)
}

///|
pub fn acceptance_packet_export_status(packet : AcceptancePacket) -> String {
  if acceptance_packet_exportable(packet) {
    "exportable"
  } else {
    "blocked"
  }
}

///|
pub fn acceptance_packet_validation_messages(
  packet : AcceptancePacket,
) -> Array[String] {
  let messages = []
  if !decision_run_valid(packet.run) {
    messages.push("decision run is invalid")
  }
  if !performance_snapshot_valid(packet.performance) {
    messages.push("performance snapshot is invalid")
  }
  if !governance_valid(packet.governance) {
    messages.push("governance report is invalid")
  }
  if !evidence_matrix_valid(packet.evidence) {
    messages.push("evidence matrix is invalid")
  }
  if !review_queue_valid(packet.queue) {
    messages.push("review queue is invalid")
  }
  if !export_bundle_valid(packet.bundle) {
    messages.push("export bundle is invalid")
  }
  if packet.checksum != acceptance_packet_checksum(packet) {
    messages.push("packet checksum does not match")
  }
  messages
}

///|
pub fn acceptance_packet_validation_status(packet : AcceptancePacket) -> String {
  if acceptance_packet_validation_messages(packet).length() == 0 {
    "valid"
  } else {
    "invalid"
  }
}

///|
pub fn acceptance_packet_validation_text(packet : AcceptancePacket) -> String {
  let messages = acceptance_packet_validation_messages(packet)
  if messages.length() == 0 {
    "valid"
  } else {
    "invalid: " + messages.join("; ")
  }
}

///|
pub fn acceptance_packet_operational_contract(
  packet : AcceptancePacket,
) -> Array[String] {
  [
    acceptance_packet_status_label(packet),
    acceptance_packet_release_label(packet),
    acceptance_packet_score_band(packet),
    acceptance_packet_risk_band(packet),
    acceptance_packet_readiness_band(packet),
    acceptance_packet_load_band(packet),
    acceptance_packet_recovery_band(packet),
    acceptance_packet_quality_band(packet),
    acceptance_packet_evidence_band(packet),
    acceptance_packet_queue_status(packet),
    acceptance_packet_export_status(packet),
    acceptance_packet_validation_status(packet),
  ]
}

///|
pub fn acceptance_packet_operational_contract_csv(
  packet : AcceptancePacket,
) -> String {
  [
    "status", "release", "score_band", "risk_band", "readiness_band", "load_band",
    "recovery_band", "quality_band", "evidence_band", "queue_status", "export_status",
    "validation",
  ].join(",") +
  "\n" +
  acceptance_packet_operational_contract(packet).join(",")
}

///|
pub fn acceptance_packet_risk_controls(
  packet : AcceptancePacket,
) -> Array[String] {
  let controls = []
  if acceptance_packet_risk(packet) >= 75.0 {
    controls.push("risk_review")
  }
  if acceptance_packet_readiness(packet) < 60.0 {
    controls.push("readiness_review")
  }
  if packet.evidence.high_count > 0 {
    controls.push("high_evidence_review")
  }
  if packet.queue.critical_count > 0 {
    controls.push("critical_queue_review")
  }
  if packet.governance.blocking_count > 0 {
    controls.push("governance_hold")
  }
  controls
}

///|
pub fn acceptance_packet_control_count(packet : AcceptancePacket) -> Int {
  acceptance_packet_risk_controls(packet).length()
}

///|
pub fn acceptance_packet_controlled(packet : AcceptancePacket) -> Bool {
  acceptance_packet_control_count(packet) == 0
}

///|
pub fn acceptance_packet_control_text(packet : AcceptancePacket) -> String {
  if acceptance_packet_controlled(packet) {
    "no additional controls"
  } else {
    acceptance_packet_risk_controls(packet).join(",")
  }
}

///|
pub fn acceptance_packet_decision_summary(
  packet : AcceptancePacket,
) -> Array[String] {
  [
    packet.status,
    acceptance_packet_release_label(packet),
    acceptance_packet_risk_band(packet),
    acceptance_packet_readiness_band(packet),
    acceptance_packet_quality_band(packet),
    acceptance_packet_evidence_band(packet),
    acceptance_packet_queue_status(packet),
    acceptance_packet_control_text(packet),
    packet.recommendation,
  ]
}

///|
pub fn acceptance_packet_decision_summary_csv(
  packet : AcceptancePacket,
) -> String {
  [
    "status", "release", "risk_band", "readiness_band", "quality_band", "evidence_band",
    "queue_status", "controls", "recommendation",
  ].join(",") +
  "\n" +
  acceptance_packet_decision_summary(packet).join(",")
}

///|
pub fn acceptance_packet_snapshot(packet : AcceptancePacket) -> Array[String] {
  [
    acceptance_packet_summary(packet),
    acceptance_packet_validation_status(packet),
    acceptance_packet_checksum_value(packet),
    acceptance_packet_recommendation_value(packet),
  ]
}

///|
pub fn acceptance_packet_snapshot_text(packet : AcceptancePacket) -> String {
  acceptance_packet_snapshot(packet).join("\n")
}

///|
pub fn acceptance_packet_checksum_matches(packet : AcceptancePacket) -> Bool {
  packet.checksum == acceptance_packet_checksum(packet)
}

///|
pub fn acceptance_packet_quality_gate_passes(
  packet : AcceptancePacket,
  floor : Double,
) -> Bool {
  quality_gate_passes(packet.run.quality) &&
  acceptance_packet_quality(packet) >= floor
}

///|
pub fn acceptance_packet_audit_contains(
  packet : AcceptancePacket,
  kind : DecisionAuditKind,
) -> Bool {
  audit_entries_by_kind(packet.run.audit, kind).length() > 0
}

///|
pub fn acceptance_packet_audit_subjects(
  packet : AcceptancePacket,
) -> Array[String] {
  audit_subjects(packet.run.audit)
}

///|
pub fn acceptance_packet_audit_validity_text(
  packet : AcceptancePacket,
) -> String {
  if acceptance_packet_has_audit(packet) {
    "audit_valid"
  } else {
    "audit_missing"
  }
}

///|
pub fn acceptance_packet_evidence_status_text(
  packet : AcceptancePacket,
) -> String {
  packet.evidence.status +
  " confidence=" +
  packet.evidence.confidence.to_string()
}

///|
pub fn acceptance_packet_governance_status_text(
  packet : AcceptancePacket,
) -> String {
  governance_status_text(packet.governance) +
  " score=" +
  packet.governance.score.to_string()
}

///|
pub fn acceptance_packet_queue_status_text(packet : AcceptancePacket) -> String {
  packet.queue.status +
  " open=" +
  packet.queue.open_count.to_string() +
  " overdue=" +
  packet.queue.overdue_count.to_string()
}

///|
pub fn acceptance_packet_export_status_text(
  packet : AcceptancePacket,
) -> String {
  acceptance_packet_export_status(packet) +
  " sections=" +
  packet.bundle.section_count.to_string() +
  " rows=" +
  packet.bundle.row_count.to_string()
}

///|
pub fn acceptance_packet_component_status(
  packet : AcceptancePacket,
) -> Array[String] {
  [
    "run=" + packet.run.status,
    "performance=" + packet.performance.status,
    "governance=" + acceptance_packet_governance_status_text(packet),
    "evidence=" + acceptance_packet_evidence_status_text(packet),
    "queue=" + acceptance_packet_queue_status_text(packet),
    "export=" + acceptance_packet_export_status_text(packet),
    "audit=" + acceptance_packet_audit_validity_text(packet),
  ]
}

///|
pub fn acceptance_packet_component_status_text(
  packet : AcceptancePacket,
) -> String {
  acceptance_packet_component_status(packet).join("\n")
}

///|
pub fn acceptance_packet_report(packet : AcceptancePacket) -> String {
  acceptance_packet_summary(packet) +
  "\n" +
  acceptance_packet_component_status_text(packet) +
  "\nrecommendation=" +
  packet.recommendation +
  "\nvalidation=" +
  acceptance_packet_validation_text(packet)
}

///|
pub fn acceptance_packet_report_csv(packet : AcceptancePacket) -> String {
  acceptance_packet_csv(packet) +
  "\n\n" +
  acceptance_packet_operational_contract_csv(packet) +
  "\n\n" +
  acceptance_packet_decision_summary_csv(packet)
}

///|
pub fn acceptance_packet_ready_for_archive(packet : AcceptancePacket) -> Bool {
  acceptance_packet_valid(packet) &&
  acceptance_packet_checksum_matches(packet) &&
  acceptance_packet_has_audit(packet) &&
  export_bundle_valid(packet.bundle)
}

///|
pub fn acceptance_packet_archive_label(packet : AcceptancePacket) -> String {
  if acceptance_packet_ready_for_archive(packet) {
    "archive_ready"
  } else {
    "archive_review"
  }
}

///|
pub fn acceptance_packet_archive_manifest(
  packet : AcceptancePacket,
) -> Array[String] {
  [
    packet.run.config.run_id,
    acceptance_packet_archive_label(packet),
    packet.checksum,
    packet.run.audit.final_checksum,
    packet.governance.lineage.checksum,
    packet.bundle.format_version,
  ]
}

///|
pub fn acceptance_packet_archive_manifest_csv(
  packet : AcceptancePacket,
) -> String {
  [
    "run_id", "archive_status", "packet_checksum", "audit_checksum", "lineage_checksum",
    "format_version",
  ].join(",") +
  "\n" +
  acceptance_packet_archive_manifest(packet).join(",")
}

///|
pub fn acceptance_packet_retainable(
  packet : AcceptancePacket,
  policy : DataRetentionPolicy,
) -> Bool {
  data_retention_policy_valid(policy) &&
  packet.performance.record_count >= policy.minimum_days
}

///|
pub fn acceptance_packet_retention_text(
  packet : AcceptancePacket,
  policy : DataRetentionPolicy,
) -> String {
  if acceptance_packet_retainable(packet, policy) {
    "retention_allowed"
  } else {
    "retention_review"
  }
}

///|
pub fn acceptance_packet_anonymized_export_allowed(
  packet : AcceptancePacket,
) -> Bool {
  packet.governance.retention.allow_anonymized_export &&
  acceptance_packet_exportable(packet)
}

///|
pub fn acceptance_packet_audit_required(packet : AcceptancePacket) -> Bool {
  packet.governance.retention.require_audit
}

///|
pub fn acceptance_packet_quality_required(packet : AcceptancePacket) -> Bool {
  packet.governance.retention.require_quality_gate
}

///|
pub fn acceptance_packet_policy_summary(
  packet : AcceptancePacket,
) -> Array[String] {
  [
    governance_retention_text(packet.governance.retention),
    acceptance_packet_retention_text(packet, packet.governance.retention),
    acceptance_packet_anonymized_export_allowed(packet).to_string(),
    acceptance_packet_audit_required(packet).to_string(),
    acceptance_packet_quality_required(packet).to_string(),
  ]
}

///|
pub fn acceptance_packet_policy_summary_csv(
  packet : AcceptancePacket,
) -> String {
  [
    "retention", "retention_status", "anonymized_export", "audit_required", "quality_required",
  ].join(",") +
  "\n" +
  acceptance_packet_policy_summary(packet).join(",")
}

///|
pub fn acceptance_packet_window_summary(packet : AcceptancePacket) -> String {
  "records=" +
  acceptance_packet_record_count(packet).to_string() +
  " sessions=" +
  acceptance_packet_session_count(packet).to_string() +
  " first_audit=" +
  acceptance_packet_audit_count(packet).to_string() +
  " evidence=" +
  packet.evidence.items.length().to_string() +
  " queue=" +
  packet.queue.rows.length().to_string()
}

///|
pub fn acceptance_packet_empty(records : Array[DailyRecord]) -> Bool {
  records.length() == 0
}

///|
pub fn acceptance_packet_empty_status(records : Array[DailyRecord]) -> String {
  acceptance_packet_status_value(acceptance_packet_for_records(records))
}

///|
pub fn acceptance_packet_input_summary(
  records : Array[DailyRecord],
) -> Array[String] {
  [
    records.length().to_string(),
    acceptance_packet_valid_record_rate(records).to_string(),
    acceptance_packet_dates(records).join(";"),
    acceptance_packet_empty(records).to_string(),
  ]
}

///|
pub fn acceptance_packet_input_summary_csv(
  records : Array[DailyRecord],
) -> String {
  ["records", "valid_rate", "dates", "empty"].join(",") +
  "\n" +
  acceptance_packet_input_summary(records).join(",")
}

///|
pub fn acceptance_packet_outcome_vector(
  packet : AcceptancePacket,
) -> Array[Double] {
  [
    acceptance_packet_risk(packet),
    acceptance_packet_readiness(packet),
    acceptance_packet_quality(packet),
    acceptance_packet_coverage(packet),
    acceptance_packet_recovery(packet),
    acceptance_packet_score(packet),
  ]
}

///|
pub fn acceptance_packet_outcome_average(packet : AcceptancePacket) -> Double {
  mean_load_values(acceptance_packet_outcome_vector(packet))
}

///|
pub fn acceptance_packet_outcome_minimum(packet : AcceptancePacket) -> Double {
  minimum_load_values(acceptance_packet_outcome_vector(packet))
}

///|
pub fn acceptance_packet_outcome_maximum(packet : AcceptancePacket) -> Double {
  maximum_load_values(acceptance_packet_outcome_vector(packet))
}

///|
pub fn acceptance_packet_outcome_deviation(packet : AcceptancePacket) -> Double {
  standard_deviation_values(acceptance_packet_outcome_vector(packet))
}

///|
pub fn acceptance_packet_outcome_trend(packet : AcceptancePacket) -> LoadTrend {
  load_trend(acceptance_packet_outcome_vector(packet), 0.1)
}

///|
pub fn acceptance_packet_outcome_text(packet : AcceptancePacket) -> String {
  acceptance_packet_outcome_vector(packet)
  .map(value => value.to_string())
  .join(",")
}

///|
pub fn acceptance_packet_outcome_csv(packet : AcceptancePacket) -> String {
  "risk,readiness,quality,coverage,recovery,score\n" +
  acceptance_packet_outcome_text(packet)
}

///|
pub fn acceptance_packet_compare_summary(
  left : AcceptancePacket,
  right : AcceptancePacket,
) -> String {
  acceptance_packet_comparison_text(acceptance_packet_compare(left, right))
}

///|
pub fn acceptance_packet_compare_csv(
  left : AcceptancePacket,
  right : AcceptancePacket,
) -> String {
  acceptance_packet_comparison_csv(acceptance_packet_compare(left, right))
}

///|
pub fn acceptance_packet_batch(
  records : Array[DailyRecord],
  dates : Array[String],
) -> Array[AcceptancePacket] {
  dates.map(date => acceptance_packet_for_date(records, date))
}

///|
pub fn acceptance_packet_batch_statuses(
  packets : Array[AcceptancePacket],
) -> Array[String] {
  packets.map(packet => packet.status)
}

///|
pub fn acceptance_packet_batch_scores(
  packets : Array[AcceptancePacket],
) -> Array[Double] {
  packets.map(packet => acceptance_packet_score(packet))
}

///|
pub fn acceptance_packet_batch_average_score(
  packets : Array[AcceptancePacket],
) -> Double {
  mean_load_values(acceptance_packet_batch_scores(packets))
}

///|
pub fn acceptance_packet_batch_ready_count(
  packets : Array[AcceptancePacket],
) -> Int {
  packets.filter(packet => acceptance_packet_accepted(packet)).length()
}

///|
pub fn acceptance_packet_batch_review_count(
  packets : Array[AcceptancePacket],
) -> Int {
  packets.filter(packet => acceptance_packet_needs_review(packet)).length()
}

///|
pub fn acceptance_packet_batch_blocked_count(
  packets : Array[AcceptancePacket],
) -> Int {
  packets.filter(packet => acceptance_packet_blocked(packet)).length()
}

///|
pub fn acceptance_packet_batch_open_items(
  packets : Array[AcceptancePacket],
) -> Int {
  packets.fold(init=0, (total, packet) => {
    total + acceptance_packet_follow_up_count(packet)
  })
}

///|
pub fn acceptance_packet_batch_valid(packets : Array[AcceptancePacket]) -> Bool {
  packets.all(packet => acceptance_packet_valid(packet))
}

///|
pub fn acceptance_packet_batch_contract(
  packets : Array[AcceptancePacket],
) -> Array[String] {
  [
    packets.length().to_string(),
    acceptance_packet_batch_ready_count(packets).to_string(),
    acceptance_packet_batch_review_count(packets).to_string(),
    acceptance_packet_batch_blocked_count(packets).to_string(),
    acceptance_packet_batch_average_score(packets).to_string(),
    acceptance_packet_batch_open_items(packets).to_string(),
    acceptance_packet_batch_valid(packets).to_string(),
  ]
}

///|
pub fn acceptance_packet_batch_text(
  packets : Array[AcceptancePacket],
) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "packets=" +
    packets.length().to_string() +
    " ready=" +
    acceptance_packet_batch_ready_count(packets).to_string() +
    " review=" +
    acceptance_packet_batch_review_count(packets).to_string() +
    " blocked=" +
    acceptance_packet_batch_blocked_count(packets).to_string() +
    " average_score=" +
    acceptance_packet_batch_average_score(packets).to_string(),
  )
  for packet in packets {
    builder.write_string("\n" + acceptance_packet_summary(packet))
  }
  builder.to_string()
}

///|
pub fn acceptance_packet_batch_csv(packets : Array[AcceptancePacket]) -> String {
  let builder = StringBuilder::new()
  builder.write_string(acceptance_packet_csv_header())
  for packet in packets {
    builder.write_string("\n" + acceptance_packet_csv_row(packet))
  }
  builder.to_string()
}
