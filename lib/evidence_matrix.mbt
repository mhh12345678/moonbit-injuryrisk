///|
/// Evidence matrix linking measured signals to operational actions.
pub(all) struct EvidenceItem {
  id : String
  date : String
  domain : String
  metric : String
  value : Double
  threshold : Double
  severity : RiskLevel
  confidence : Double
  source : String
  action : String
  resolved : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct EvidenceMatrix {
  items : Array[EvidenceItem]
  high_count : Int
  medium_count : Int
  low_count : Int
  unresolved_count : Int
  confidence : Double
  status : String
} derive(Debug, Eq, ToJson)

///|
fn evidence_from_signal(signal : RiskSignal, date : String) -> EvidenceItem {
  {
    id: signal.id + "-evidence",
    date,
    domain: signal_kind_name(signal.kind),
    metric: signal.title,
    value: signal.value,
    threshold: signal.threshold,
    severity: signal.severity,
    confidence: signal.confidence,
    source: "risk-signal",
    action: signal.action,
    resolved: false,
  }
}

///|
pub fn evidence_from_assessment(
  assessment : ComprehensiveAssessment,
) -> Array[EvidenceItem] {
  assessment.signals.signals.map(signal => {
    evidence_from_signal(signal, assessment.date)
  })
}

///|
pub fn evidence_from_run(run : MonitoringRun) -> Array[EvidenceItem] {
  let output = []
  for monitor in run.monitors {
    match monitor.assessment {
      Some(assessment) =>
        for item in evidence_from_assessment(assessment) {
          output.push(item)
        }
      None => ()
    }
  }
  output
}

///|
pub fn build_evidence_matrix(items : Array[EvidenceItem]) -> EvidenceMatrix {
  let high = items.filter(item => item.severity == High).length()
  let medium = items.filter(item => item.severity == Medium).length()
  let low = items.filter(item => item.severity == Low).length()
  let unresolved = items.filter(item => !item.resolved).length()
  {
    items,
    high_count: high,
    medium_count: medium,
    low_count: low,
    unresolved_count: unresolved,
    confidence: mean_load_values(items.map(item => item.confidence)),
    status: if high > 0 {
      "high"
    } else if medium > 0 {
      "medium"
    } else if low > 0 {
      "low"
    } else {
      "clear"
    },
  }
}

///|
pub fn evidence_matrix_for_assessment(
  assessment : ComprehensiveAssessment,
) -> EvidenceMatrix {
  build_evidence_matrix(evidence_from_assessment(assessment))
}

///|
pub fn evidence_by_domain(
  matrix : EvidenceMatrix,
  domain : String,
) -> Array[EvidenceItem] {
  matrix.items.filter(item => item.domain == domain)
}

///|
pub fn evidence_by_date(
  matrix : EvidenceMatrix,
  date : String,
) -> Array[EvidenceItem] {
  matrix.items.filter(item => item.date == date)
}

///|
pub fn evidence_by_severity(
  matrix : EvidenceMatrix,
  severity : RiskLevel,
) -> Array[EvidenceItem] {
  matrix.items.filter(item => item.severity == severity)
}

///|
pub fn evidence_unresolved(matrix : EvidenceMatrix) -> Array[EvidenceItem] {
  matrix.items.filter(item => !item.resolved)
}

///|
pub fn evidence_resolve(matrix : EvidenceMatrix, id : String) -> EvidenceMatrix {
  let items = matrix.items.map(item => {
    if item.id == id {
      {
        id: item.id,
        date: item.date,
        domain: item.domain,
        metric: item.metric,
        value: item.value,
        threshold: item.threshold,
        severity: item.severity,
        confidence: item.confidence,
        source: item.source,
        action: item.action,
        resolved: true,
      }
    } else {
      item
    }
  })
  build_evidence_matrix(items)
}

///|
pub fn evidence_domains(matrix : EvidenceMatrix) -> Array[String] {
  let domains = []
  for item in matrix.items {
    if !domains.contains(item.domain) {
      domains.push(item.domain)
    }
  }
  domains
}

///|
pub fn evidence_actions(matrix : EvidenceMatrix) -> Array[String] {
  let actions = []
  for item in evidence_unresolved(matrix) {
    if !actions.contains(item.action) {
      actions.push(item.action)
    }
  }
  actions
}

///|
pub fn evidence_confidence_band(matrix : EvidenceMatrix) -> String {
  if matrix.confidence >= 0.80 {
    "high"
  } else if matrix.confidence >= 0.50 {
    "medium"
  } else {
    "low"
  }
}

///|
pub fn evidence_requires_review(matrix : EvidenceMatrix) -> Bool {
  matrix.high_count > 0 || evidence_confidence_band(matrix) == "low"
}

///|
pub fn evidence_recommendation(matrix : EvidenceMatrix) -> String {
  if matrix.high_count > 0 {
    "review high-severity evidence"
  } else if matrix.unresolved_count > 0 {
    "complete evidence actions"
  } else {
    "continue evidence collection"
  }
}

///|
pub fn evidence_item_text(item : EvidenceItem) -> String {
  item.date +
  " " +
  item.domain +
  " metric=" +
  item.metric +
  " value=" +
  item.value.to_string() +
  " threshold=" +
  item.threshold.to_string() +
  " severity=" +
  risk_level_name(item.severity) +
  " confidence=" +
  item.confidence.to_string() +
  " action=" +
  item.action
}

///|
pub fn evidence_matrix_text(matrix : EvidenceMatrix) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "status=" +
    matrix.status +
    " items=" +
    matrix.items.length().to_string() +
    " high=" +
    matrix.high_count.to_string() +
    " medium=" +
    matrix.medium_count.to_string() +
    " low=" +
    matrix.low_count.to_string() +
    " unresolved=" +
    matrix.unresolved_count.to_string() +
    " confidence=" +
    matrix.confidence.to_string() +
    " action=" +
    evidence_recommendation(matrix),
  )
  for item in matrix.items {
    builder.write_string("\n" + evidence_item_text(item))
  }
  builder.to_string()
}

///|
pub fn evidence_csv_header() -> String {
  "id,date,domain,metric,value,threshold,severity,confidence,source,resolved,action"
}

///|
pub fn evidence_csv(item : EvidenceItem) -> String {
  item.id +
  "," +
  item.date +
  "," +
  item.domain +
  "," +
  item.metric +
  "," +
  item.value.to_string() +
  "," +
  item.threshold.to_string() +
  "," +
  risk_level_name(item.severity) +
  "," +
  item.confidence.to_string() +
  "," +
  item.source +
  "," +
  item.resolved.to_string() +
  "," +
  item.action
}

///|
pub fn evidence_matrix_csv(matrix : EvidenceMatrix) -> String {
  let builder = StringBuilder::new()
  builder.write_string(evidence_csv_header())
  for item in matrix.items {
    builder.write_string("\n")
    builder.write_string(evidence_csv(item))
  }
  builder.to_string()
}

///|
pub fn evidence_item_valid(item : EvidenceItem) -> Bool {
  item.id != "" &&
  item.date != "" &&
  item.domain != "" &&
  item.metric != "" &&
  item.confidence >= 0.0 &&
  item.confidence <= 1.0 &&
  item.value.is_nan() == false
}

///|
pub fn evidence_matrix_valid(matrix : EvidenceMatrix) -> Bool {
  matrix.high_count >= 0 &&
  matrix.medium_count >= 0 &&
  matrix.low_count >= 0 &&
  matrix.unresolved_count >= 0 &&
  matrix.confidence >= 0.0 &&
  matrix.confidence <= 1.0 &&
  matrix.items.all(item => evidence_item_valid(item))
}
