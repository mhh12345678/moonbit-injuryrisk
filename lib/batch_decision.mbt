///|
/// Batch decision table for teams processing many athlete series.
pub(all) struct BatchDecisionRow {
  athlete_id : String
  decision : ProgressionDecision
  risk_score : Double
  readiness_score : Double
  quality_score : Double
  load_cap : Double
  action : String
  evidence_count : Int
  accepted : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct BatchDecisionReport {
  rows : Array[BatchDecisionRow]
  athlete_count : Int
  accepted_count : Int
  action_count : Int
  referral_count : Int
  average_risk : Double
  average_readiness : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
fn batch_decision(
  assessment : ComprehensiveAssessment,
  athlete_id : String,
  control : RiskControlResult,
  evidence_count : Int,
) -> BatchDecisionRow {
  let decision = if control.referral_required {
    ProgressionRefer
  } else if control.rest_required {
    ProgressionPause
  } else if !control.allowed {
    ProgressionReduce
  } else {
    ProgressionApprove
  }
  {
    athlete_id,
    decision,
    risk_score: assessment.risk_score,
    readiness_score: assessment.readiness_score,
    quality_score: assessment.quality.score,
    load_cap: control.load_cap,
    action: control.next_action,
    evidence_count,
    accepted: decision == ProgressionApprove &&
    assessment.quality.blocking_issue_count == 0,
  }
}

///|
pub fn batch_decision_rows(
  cohort : Array[AthleteSeries],
  policy : RiskPolicy,
  control_config : RiskControlConfig,
  monitor_config : MonitoringThresholds,
) -> Array[BatchDecisionRow] {
  let rows = []
  for series in cohort {
    match assess_latest(series.records, policy) {
      Some(assessment) => {
        let sorted = sort_records_by_date(series.records)
        let record = sorted[sorted.length() - 1]
        let monitor = run_monitoring(series.records, policy, monitor_config)
        let evidence = evidence_from_run(monitor).length()
        let control = evaluate_risk_control(
          assessment,
          record,
          longest_training_block(sorted),
          control_config,
        )
        rows.push(
          batch_decision(assessment, series.athlete_id, control, evidence),
        )
      }
      None =>
        rows.push({
          athlete_id: series.athlete_id,
          decision: ProgressionPause,
          risk_score: 0.0,
          readiness_score: 0.0,
          quality_score: 0.0,
          load_cap: 0.0,
          action: "collect valid telemetry",
          evidence_count: 0,
          accepted: false,
        })
    }
  }
  rows
}

///|
pub fn summarize_batch_decisions(
  rows : Array[BatchDecisionRow],
) -> BatchDecisionReport {
  let accepted = rows.filter(row => row.accepted).length()
  let action = rows.filter(row => row.decision != ProgressionApprove).length()
  let referral = rows.filter(row => row.decision == ProgressionRefer).length()
  {
    rows,
    athlete_count: rows.length(),
    accepted_count: accepted,
    action_count: action,
    referral_count: referral,
    average_risk: mean_load_values(rows.map(row => row.risk_score)),
    average_readiness: mean_load_values(rows.map(row => row.readiness_score)),
    status: if referral > 0 {
      "referral"
    } else if action > accepted {
      "action_required"
    } else {
      "operational"
    },
  }
}

///|
pub fn batch_rows_by_decision(
  report : BatchDecisionReport,
  decision : ProgressionDecision,
) -> Array[BatchDecisionRow] {
  report.rows.filter(row => row.decision == decision)
}

///|
pub fn batch_accepted_ids(report : BatchDecisionReport) -> Array[String] {
  report.rows.filter(row => row.accepted).map(row => row.athlete_id)
}

///|
pub fn batch_action_ids(report : BatchDecisionReport) -> Array[String] {
  report.rows.filter(row => !row.accepted).map(row => row.athlete_id)
}

///|
pub fn batch_referral_ids(report : BatchDecisionReport) -> Array[String] {
  report.rows
  .filter(row => row.decision == ProgressionRefer)
  .map(row => row.athlete_id)
}

///|
pub fn batch_average_load_cap(report : BatchDecisionReport) -> Double {
  mean_load_values(report.rows.map(row => row.load_cap))
}

///|
pub fn batch_quality_ready_percent(report : BatchDecisionReport) -> Double {
  if report.rows.length() == 0 {
    0.0
  } else {
    report.rows.filter(row => row.quality_score >= 80.0).length().to_double() /
    report.rows.length().to_double() *
    100.0
  }
}

///|
pub fn batch_risk_range(report : BatchDecisionReport) -> Array[Double] {
  [
    minimum_load_values(report.rows.map(row => row.risk_score)),
    maximum_load_values(report.rows.map(row => row.risk_score)),
  ]
}

///|
pub fn batch_readiness_range(report : BatchDecisionReport) -> Array[Double] {
  [
    minimum_load_values(report.rows.map(row => row.readiness_score)),
    maximum_load_values(report.rows.map(row => row.readiness_score)),
  ]
}

///|
pub fn batch_requires_review(report : BatchDecisionReport) -> Bool {
  report.status != "operational" || report.referral_count > 0
}

///|
pub fn batch_recommendation(report : BatchDecisionReport) -> String {
  if report.referral_count > 0 {
    "route referral rows for qualified review"
  } else if report.action_count > 0 {
    "apply row-level load caps before progression"
  } else {
    "continue scheduled progression"
  }
}

///|
pub fn batch_decision_text(row : BatchDecisionRow) -> String {
  row.athlete_id +
  " decision=" +
  progression_decision_name(row.decision) +
  " risk=" +
  row.risk_score.to_string() +
  " readiness=" +
  row.readiness_score.to_string() +
  " quality=" +
  row.quality_score.to_string() +
  " load_cap=" +
  row.load_cap.to_string() +
  " evidence=" +
  row.evidence_count.to_string() +
  " action=" +
  row.action
}

///|
pub fn batch_decision_report_text(report : BatchDecisionReport) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "status=" +
    report.status +
    " athletes=" +
    report.athlete_count.to_string() +
    " accepted=" +
    report.accepted_count.to_string() +
    " action=" +
    report.action_count.to_string() +
    " referrals=" +
    report.referral_count.to_string() +
    " average_risk=" +
    report.average_risk.to_string() +
    " average_readiness=" +
    report.average_readiness.to_string() +
    " recommendation=" +
    batch_recommendation(report),
  )
  for row in report.rows {
    builder.write_string("\n" + batch_decision_text(row))
  }
  builder.to_string()
}

///|
pub fn batch_decision_csv_header() -> String {
  "athlete_id,decision,risk_score,readiness_score,quality_score,load_cap,action,evidence_count,accepted"
}

///|
pub fn batch_decision_csv(row : BatchDecisionRow) -> String {
  row.athlete_id +
  "," +
  progression_decision_name(row.decision) +
  "," +
  row.risk_score.to_string() +
  "," +
  row.readiness_score.to_string() +
  "," +
  row.quality_score.to_string() +
  "," +
  row.load_cap.to_string() +
  "," +
  row.action +
  "," +
  row.evidence_count.to_string() +
  "," +
  row.accepted.to_string()
}

///|
pub fn batch_decision_report_csv(report : BatchDecisionReport) -> String {
  let builder = StringBuilder()
  builder.write_string(batch_decision_csv_header())
  for row in report.rows {
    builder.write_string("\n")
    builder.write_string(batch_decision_csv(row))
  }
  builder.to_string()
}

///|
pub fn batch_decision_row_valid(row : BatchDecisionRow) -> Bool {
  row.athlete_id != "" &&
  row.risk_score >= 0.0 &&
  row.risk_score <= 100.0 &&
  row.readiness_score >= 0.0 &&
  row.readiness_score <= 100.0 &&
  row.quality_score >= 0.0 &&
  row.quality_score <= 100.0 &&
  row.load_cap >= 0.0 &&
  row.evidence_count >= 0
}
