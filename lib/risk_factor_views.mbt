///|
/// Factor views expose which domains contribute to a decision.
pub(all) struct RiskFactorView {
  name : String
  domain : String
  value : Double
  contribution : Double
  severity : RiskLevel
  confidence : Double
  direction : String
  action : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct RiskFactorReport {
  factors : Array[RiskFactorView]
  dominant : String
  total_contribution : Double
  high_count : Int
  medium_count : Int
  low_count : Int
  status : String
} derive(Debug, Eq, ToJson)

///|
fn factor_direction(
  kind : SignalKind,
  value : Double,
  threshold : Double,
) -> String {
  match kind {
    Workload | LoadSpike | Monotony =>
      if value > threshold {
        "rising"
      } else {
        "stable"
      }
    Recovery | Sleep | Pain | Fatigue =>
      if value < threshold {
        "declining"
      } else {
        "stable"
      }
    Trend => "rising"
    DataQuality | MissingHistory => "incomplete"
  }
}

///|
fn factor_from_signal(signal : RiskSignal) -> RiskFactorView {
  {
    name: signal.title,
    domain: signal_kind_name(signal.kind),
    value: signal.value,
    contribution: signal_weight(signal),
    severity: signal.severity,
    confidence: signal.confidence,
    direction: factor_direction(signal.kind, signal.value, signal.threshold),
    action: signal.action,
  }
}

///|
pub fn risk_factors(
  assessment : ComprehensiveAssessment,
) -> Array[RiskFactorView] {
  assessment.signals.signals.map(signal => factor_from_signal(signal))
}

///|
fn dominant_factor(factors : Array[RiskFactorView]) -> String {
  if factors.length() == 0 {
    "none"
  } else {
    let mut best = factors[0]
    for factor in factors {
      if factor.contribution > best.contribution {
        best = factor
      }
    }
    best.name
  }
}

///|
pub fn risk_factor_report(
  assessment : ComprehensiveAssessment,
) -> RiskFactorReport {
  let factors = risk_factors(assessment)
  {
    factors,
    dominant: dominant_factor(factors),
    total_contribution: factors.fold(init=0.0, (total, factor) => {
      total + factor.contribution
    }),
    high_count: factors.filter(factor => factor.severity == High).length(),
    medium_count: factors.filter(factor => factor.severity == Medium).length(),
    low_count: factors.filter(factor => factor.severity == Low).length(),
    status: if factors.any(factor => factor.severity == High) {
      "high"
    } else if factors.any(factor => factor.severity == Medium) {
      "medium"
    } else if factors.length() > 0 {
      "low"
    } else {
      "clear"
    },
  }
}

///|
pub fn factor_by_name(
  report : RiskFactorReport,
  name : String,
) -> RiskFactorView? {
  for factor in report.factors {
    if factor.name == name {
      return Some(factor)
    }
  }
  None
}

///|
pub fn factor_by_domain(
  report : RiskFactorReport,
  domain : String,
) -> Array[RiskFactorView] {
  report.factors.filter(factor => factor.domain == domain)
}

///|
pub fn factor_high(report : RiskFactorReport) -> Array[RiskFactorView] {
  report.factors.filter(factor => factor.severity == High)
}

///|
pub fn factor_actionable(report : RiskFactorReport) -> Array[RiskFactorView] {
  report.factors.filter(factor => {
    factor.severity != Low || factor.confidence >= 0.70
  })
}

///|
pub fn factor_domains(report : RiskFactorReport) -> Array[String] {
  let domains = []
  for factor in report.factors {
    if !domains.contains(factor.domain) {
      domains.push(factor.domain)
    }
  }
  domains
}

///|
pub fn factor_confidence(report : RiskFactorReport) -> Double {
  mean_load_values(report.factors.map(factor => factor.confidence))
}

///|
pub fn factor_average_contribution(report : RiskFactorReport) -> Double {
  mean_load_values(report.factors.map(factor => factor.contribution))
}

///|
pub fn factor_requires_review(report : RiskFactorReport) -> Bool {
  report.high_count > 0 || factor_confidence(report) < 0.50
}

///|
pub fn factor_next_action(report : RiskFactorReport) -> String {
  if report.high_count > 0 {
    "resolve high-contribution factor: " + report.dominant
  } else if factor_requires_review(report) {
    "collect higher-confidence evidence"
  } else if report.factors.length() == 0 {
    "continue collecting telemetry"
  } else {
    "monitor the dominant factor"
  }
}

///|
pub fn factor_names(report : RiskFactorReport) -> Array[String] {
  report.factors.map(factor => factor.name)
}

///|
pub fn factor_values(report : RiskFactorReport) -> Array[Double] {
  report.factors.map(factor => factor.value)
}

///|
pub fn factor_contributions(report : RiskFactorReport) -> Array[Double] {
  report.factors.map(factor => factor.contribution)
}

///|
pub fn factor_text(factor : RiskFactorView) -> String {
  factor.domain +
  " " +
  factor.name +
  " value=" +
  factor.value.to_string() +
  " contribution=" +
  factor.contribution.to_string() +
  " severity=" +
  risk_level_name(factor.severity) +
  " confidence=" +
  factor.confidence.to_string() +
  " direction=" +
  factor.direction +
  " action=" +
  factor.action
}

///|
pub fn factor_report_text(report : RiskFactorReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "status=" +
    report.status +
    " factors=" +
    report.factors.length().to_string() +
    " dominant=" +
    report.dominant +
    " contribution=" +
    report.total_contribution.to_string() +
    " confidence=" +
    factor_confidence(report).to_string() +
    " action=" +
    factor_next_action(report),
  )
  for factor in report.factors {
    builder.write_string("\n" + factor_text(factor))
  }
  builder.to_string()
}

///|
pub fn factor_csv_header() -> String {
  "name,domain,value,contribution,severity,confidence,direction,action"
}

///|
pub fn factor_csv(factor : RiskFactorView) -> String {
  factor.name +
  "," +
  factor.domain +
  "," +
  factor.value.to_string() +
  "," +
  factor.contribution.to_string() +
  "," +
  risk_level_name(factor.severity) +
  "," +
  factor.confidence.to_string() +
  "," +
  factor.direction +
  "," +
  factor.action
}

///|
pub fn factor_report_csv(report : RiskFactorReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string(factor_csv_header())
  for factor in report.factors {
    builder.write_string("\n")
    builder.write_string(factor_csv(factor))
  }
  builder.to_string()
}

///|
pub fn factor_view_valid(factor : RiskFactorView) -> Bool {
  factor.name != "" &&
  factor.domain != "" &&
  factor.value.is_nan() == false &&
  factor.contribution >= 0.0 &&
  factor.confidence >= 0.0 &&
  factor.confidence <= 1.0 &&
  factor.action != ""
}

///|
pub fn factor_report_valid(report : RiskFactorReport) -> Bool {
  report.dominant != "" &&
  report.total_contribution >= 0.0 &&
  report.high_count >= 0 &&
  report.medium_count >= 0 &&
  report.low_count >= 0 &&
  report.factors.all(factor => factor_view_valid(factor))
}
