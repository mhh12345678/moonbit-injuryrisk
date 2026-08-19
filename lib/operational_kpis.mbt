///|
/// Operational KPIs turn a decision run into measurable service behavior.
pub(all) enum ServiceKpiKind {
  KpiQuality
  KpiCoverage
  KpiRisk
  KpiReadiness
  KpiRecovery
  KpiAlertRate
  KpiEventRate
  KpiInterventionRate
  KpiThroughput
  KpiActionDensity
  KpiDataCompleteness
  KpiReviewLatency
} derive(Debug, Eq, ToJson)

///|
pub(all) enum ServiceKpiBand {
  KpiGood
  KpiWatch
  KpiPoor
  KpiUnknown
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ServiceKpi {
  kind : ServiceKpiKind
  name : String
  value : Double
  target : Double
  unit : String
  band : ServiceKpiBand
  status : String
  evidence : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ServiceKpiSnapshot {
  run_id : String
  generated_for : String
  kpis : Array[ServiceKpi]
  good_count : Int
  watch_count : Int
  poor_count : Int
  overall_score : Double
  status : String
  recommendation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ServiceKpiTarget {
  kind : ServiceKpiKind
  target : Double
  tolerance : Double
  higher_is_better : Bool
  required : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ServiceKpiComparison {
  kind : ServiceKpiKind
  left_value : Double
  right_value : Double
  change : Double
  change_percent : Double
  left_band : ServiceKpiBand
  right_band : ServiceKpiBand
  conclusion : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct ServiceKpiReport {
  snapshot : ServiceKpiSnapshot
  required_count : Int
  required_failures : Int
  valid : Bool
  messages : Array[String]
} derive(Debug, Eq, ToJson)

///|
pub fn service_kpi_kind_name(kind : ServiceKpiKind) -> String {
  match kind {
    KpiQuality => "quality"
    KpiCoverage => "coverage"
    KpiRisk => "risk"
    KpiReadiness => "readiness"
    KpiRecovery => "recovery"
    KpiAlertRate => "alert_rate"
    KpiEventRate => "event_rate"
    KpiInterventionRate => "intervention_rate"
    KpiThroughput => "throughput"
    KpiActionDensity => "action_density"
    KpiDataCompleteness => "data_completeness"
    KpiReviewLatency => "review_latency"
  }
}

///|
pub fn service_kpi_band_name(band : ServiceKpiBand) -> String {
  match band {
    KpiGood => "good"
    KpiWatch => "watch"
    KpiPoor => "poor"
    KpiUnknown => "unknown"
  }
}

///|
pub fn service_kpi_band_rank(band : ServiceKpiBand) -> Int {
  match band {
    KpiGood => 0
    KpiWatch => 1
    KpiPoor => 2
    KpiUnknown => 3
  }
}

///|
pub fn default_service_kpi_targets() -> Array[ServiceKpiTarget] {
  [
    {
      kind: KpiQuality,
      target: 80.0,
      tolerance: 5.0,
      higher_is_better: true,
      required: true,
    },
    {
      kind: KpiCoverage,
      target: 80.0,
      tolerance: 10.0,
      higher_is_better: true,
      required: true,
    },
    {
      kind: KpiRisk,
      target: 35.0,
      tolerance: 15.0,
      higher_is_better: false,
      required: true,
    },
    {
      kind: KpiReadiness,
      target: 70.0,
      tolerance: 10.0,
      higher_is_better: true,
      required: true,
    },
    {
      kind: KpiRecovery,
      target: 70.0,
      tolerance: 10.0,
      higher_is_better: true,
      required: false,
    },
    {
      kind: KpiAlertRate,
      target: 20.0,
      tolerance: 10.0,
      higher_is_better: false,
      required: false,
    },
    {
      kind: KpiEventRate,
      target: 20.0,
      tolerance: 10.0,
      higher_is_better: false,
      required: false,
    },
    {
      kind: KpiInterventionRate,
      target: 30.0,
      tolerance: 15.0,
      higher_is_better: false,
      required: false,
    },
    {
      kind: KpiThroughput,
      target: 0.75,
      tolerance: 0.15,
      higher_is_better: true,
      required: false,
    },
    {
      kind: KpiActionDensity,
      target: 35.0,
      tolerance: 15.0,
      higher_is_better: false,
      required: false,
    },
    {
      kind: KpiDataCompleteness,
      target: 80.0,
      tolerance: 10.0,
      higher_is_better: true,
      required: true,
    },
    {
      kind: KpiReviewLatency,
      target: 1.0,
      tolerance: 1.0,
      higher_is_better: false,
      required: false,
    },
  ]
}

///|
fn service_kpi_target(
  targets : Array[ServiceKpiTarget],
  kind : ServiceKpiKind,
) -> ServiceKpiTarget? {
  for target in targets {
    if target.kind == kind {
      return Some(target)
    }
  }
  None
}

///|
fn service_kpi_value_band(
  value : Double,
  target : ServiceKpiTarget?,
) -> ServiceKpiBand {
  match target {
    None => KpiUnknown
    Some(target) =>
      if target.higher_is_better {
        if value >= target.target {
          KpiGood
        } else if value >= target.target - target.tolerance {
          KpiWatch
        } else {
          KpiPoor
        }
      } else if value <= target.target {
        KpiGood
      } else if value <= target.target + target.tolerance {
        KpiWatch
      } else {
        KpiPoor
      }
  }
}

///|
fn service_kpi_status(band : ServiceKpiBand) -> String {
  if band == KpiGood {
    "pass"
  } else if band == KpiWatch {
    "watch"
  } else if band == KpiPoor {
    "fail"
  } else {
    "unknown"
  }
}

///|
fn service_kpi(
  kind : ServiceKpiKind,
  value : Double,
  evidence : String,
  targets : Array[ServiceKpiTarget],
) -> ServiceKpi {
  let target = service_kpi_target(targets, kind)
  let band = service_kpi_value_band(value, target)
  let target_value = match target {
    Some(value) => value.target
    None => 0.0
  }
  {
    kind,
    name: service_kpi_kind_name(kind),
    value,
    target: target_value,
    unit: if kind == KpiThroughput {
      "ratio"
    } else {
      "percent"
    },
    band,
    status: service_kpi_status(band),
    evidence,
  }
}

///|
fn service_kpis_from_snapshot(
  snapshot : PerformanceSnapshot,
  summary : MonitoringSummary,
  targets : Array[ServiceKpiTarget],
) -> Array[ServiceKpi] {
  [
    service_kpi(
      KpiQuality,
      snapshot.quality_score,
      "quality gate score",
      targets,
    ),
    service_kpi(
      KpiCoverage,
      snapshot.coverage_percent,
      "record coverage",
      targets,
    ),
    service_kpi(KpiRisk, snapshot.risk_mean, "mean risk score", targets),
    service_kpi(
      KpiReadiness,
      snapshot.readiness_mean,
      "mean readiness score",
      targets,
    ),
    service_kpi(
      KpiRecovery,
      snapshot.recovery_mean,
      "mean recovery score",
      targets,
    ),
    service_kpi(
      KpiAlertRate,
      performance_alert_rate(snapshot),
      "alerts per record",
      targets,
    ),
    service_kpi(
      KpiEventRate,
      performance_event_rate(snapshot),
      "events per record",
      targets,
    ),
    service_kpi(
      KpiInterventionRate,
      performance_intervention_rate(snapshot),
      "interventions per assessment",
      targets,
    ),
    service_kpi(
      KpiThroughput,
      performance_throughput(snapshot),
      "records per processing unit",
      targets,
    ),
    service_kpi(
      KpiActionDensity,
      performance_action_density(snapshot),
      "combined action density",
      targets,
    ),
    service_kpi(
      KpiDataCompleteness,
      summary.data_complete_percent,
      "monitor data completeness",
      targets,
    ),
    service_kpi(
      KpiReviewLatency,
      if summary.actionable_day_count == 0 {
        0.0
      } else {
        summary.actionable_day_count.to_double() /
        summary.day_count.max(1).to_double()
      },
      "actionable day ratio",
      targets,
    ),
  ]
}

///|
fn service_kpi_overall_score(kpis : Array[ServiceKpi]) -> Double {
  if kpis.length() == 0 {
    0.0
  } else {
    kpis
    .map(kpi => {
      match kpi.band {
        KpiGood => 100.0
        KpiWatch => 60.0
        KpiPoor => 0.0
        KpiUnknown => 40.0
      }
    })
    .fold(init=0.0, (total, value) => total + value) /
    kpis.length().to_double()
  }
}

///|
fn service_kpi_recommendation(kpis : Array[ServiceKpi]) -> String {
  if kpis.any(kpi => kpi.band == KpiPoor && kpi.kind == KpiQuality) {
    "repair data quality before operational use"
  } else if kpis.any(kpi => kpi.band == KpiPoor && kpi.kind == KpiRisk) {
    "inspect risk drivers and limit progression"
  } else if kpis.any(kpi => kpi.band == KpiPoor) {
    "review poor operational KPIs before the next run"
  } else if kpis.any(kpi => kpi.band == KpiWatch) {
    "keep the next run under closer observation"
  } else {
    "operational KPIs are within target"
  }
}

///|
pub fn service_kpi_snapshot(
  run : DecisionRun,
  performance : PerformanceSnapshot,
  targets : Array[ServiceKpiTarget],
) -> ServiceKpiSnapshot {
  let kpis = service_kpis_from_snapshot(
    performance,
    run.monitoring.summary,
    targets,
  )
  let good = kpis.filter(kpi => kpi.band == KpiGood).length()
  let watch = kpis.filter(kpi => kpi.band == KpiWatch).length()
  let poor = kpis.filter(kpi => kpi.band == KpiPoor).length()
  {
    run_id: run.config.run_id,
    generated_for: run.monitoring.generated_for,
    kpis,
    good_count: good,
    watch_count: watch,
    poor_count: poor,
    overall_score: service_kpi_overall_score(kpis),
    status: if poor > 0 {
      "action"
    } else if watch > 0 {
      "watch"
    } else {
      "good"
    },
    recommendation: service_kpi_recommendation(kpis),
  }
}

///|
pub fn service_kpi_snapshot_default(
  run : DecisionRun,
  performance : PerformanceSnapshot,
) -> ServiceKpiSnapshot {
  service_kpi_snapshot(run, performance, default_service_kpi_targets())
}

///|
pub fn service_kpi_by_kind(
  snapshot : ServiceKpiSnapshot,
  kind : ServiceKpiKind,
) -> ServiceKpi? {
  for kpi in snapshot.kpis {
    if kpi.kind == kind {
      return Some(kpi)
    }
  }
  None
}

///|
pub fn service_kpi_by_name(
  snapshot : ServiceKpiSnapshot,
  name : String,
) -> ServiceKpi? {
  for kpi in snapshot.kpis {
    if kpi.name == name {
      return Some(kpi)
    }
  }
  None
}

///|
pub fn service_kpi_value(
  snapshot : ServiceKpiSnapshot,
  kind : ServiceKpiKind,
) -> Double {
  match service_kpi_by_kind(snapshot, kind) {
    Some(kpi) => kpi.value
    None => 0.0
  }
}

///|
pub fn service_kpi_band(
  snapshot : ServiceKpiSnapshot,
  kind : ServiceKpiKind,
) -> ServiceKpiBand {
  match service_kpi_by_kind(snapshot, kind) {
    Some(kpi) => kpi.band
    None => KpiUnknown
  }
}

///|
pub fn service_kpi_status_for(
  snapshot : ServiceKpiSnapshot,
  kind : ServiceKpiKind,
) -> String {
  service_kpi_status(service_kpi_band(snapshot, kind))
}

///|
pub fn service_kpi_names(snapshot : ServiceKpiSnapshot) -> Array[String] {
  snapshot.kpis.map(kpi => kpi.name)
}

///|
pub fn service_kpi_values(snapshot : ServiceKpiSnapshot) -> Array[Double] {
  snapshot.kpis.map(kpi => kpi.value)
}

///|
pub fn service_kpi_good(snapshot : ServiceKpiSnapshot) -> Array[ServiceKpi] {
  snapshot.kpis.filter(kpi => kpi.band == KpiGood)
}

///|
pub fn service_kpi_watch(snapshot : ServiceKpiSnapshot) -> Array[ServiceKpi] {
  snapshot.kpis.filter(kpi => kpi.band == KpiWatch)
}

///|
pub fn service_kpi_poor(snapshot : ServiceKpiSnapshot) -> Array[ServiceKpi] {
  snapshot.kpis.filter(kpi => kpi.band == KpiPoor)
}

///|
pub fn service_kpi_required(
  snapshot : ServiceKpiSnapshot,
  targets : Array[ServiceKpiTarget],
) -> Array[ServiceKpi] {
  snapshot.kpis.filter(kpi => {
    match service_kpi_target(targets, kpi.kind) {
      Some(target) => target.required
      None => false
    }
  })
}

///|
pub fn service_kpi_required_failures(
  snapshot : ServiceKpiSnapshot,
  targets : Array[ServiceKpiTarget],
) -> Array[ServiceKpi] {
  service_kpi_required(snapshot, targets).filter(kpi => {
    kpi.band == KpiPoor || kpi.band == KpiUnknown
  })
}

///|
pub fn service_kpi_required_count(
  snapshot : ServiceKpiSnapshot,
  targets : Array[ServiceKpiTarget],
) -> Int {
  service_kpi_required(snapshot, targets).length()
}

///|
pub fn service_kpi_required_failure_count(
  snapshot : ServiceKpiSnapshot,
  targets : Array[ServiceKpiTarget],
) -> Int {
  service_kpi_required_failures(snapshot, targets).length()
}

///|
pub fn service_kpi_passes(
  snapshot : ServiceKpiSnapshot,
  targets : Array[ServiceKpiTarget],
) -> Bool {
  service_kpi_required_failure_count(snapshot, targets) == 0
}

///|
pub fn service_kpi_report(
  snapshot : ServiceKpiSnapshot,
  targets : Array[ServiceKpiTarget],
) -> ServiceKpiReport {
  let failures = service_kpi_required_failures(snapshot, targets)
  let messages = failures.map(kpi => kpi.name + " is below target")
  {
    snapshot,
    required_count: service_kpi_required_count(snapshot, targets),
    required_failures: failures.length(),
    valid: failures.length() == 0 && snapshot.kpis.length() > 0,
    messages,
  }
}

///|
pub fn service_kpi_report_default(
  snapshot : ServiceKpiSnapshot,
) -> ServiceKpiReport {
  service_kpi_report(snapshot, default_service_kpi_targets())
}

///|
pub fn service_kpi_report_message(report : ServiceKpiReport) -> String {
  "status=" +
  report.snapshot.status +
  " score=" +
  report.snapshot.overall_score.to_string() +
  " required=" +
  report.required_count.to_string() +
  " failures=" +
  report.required_failures.to_string()
}

///|
pub fn service_kpi_report_text(report : ServiceKpiReport) -> String {
  let builder = StringBuilder::new()
  builder.write_string(service_kpi_report_message(report))
  builder.write_string("\nrecommendation=" + report.snapshot.recommendation)
  for message in report.messages {
    builder.write_string("\n- " + message)
  }
  builder.to_string()
}

///|
pub fn service_kpi_valid(kpi : ServiceKpi) -> Bool {
  kpi.name != "" &&
  kpi.value.is_nan() == false &&
  kpi.target.is_nan() == false &&
  kpi.unit != "" &&
  kpi.band != KpiUnknown
}

///|
pub fn service_kpi_snapshot_valid(snapshot : ServiceKpiSnapshot) -> Bool {
  snapshot.run_id != "" &&
  snapshot.generated_for != "" &&
  snapshot.kpis.all(kpi => service_kpi_valid(kpi)) &&
  snapshot.good_count >= 0 &&
  snapshot.watch_count >= 0 &&
  snapshot.poor_count >= 0 &&
  snapshot.good_count + snapshot.watch_count + snapshot.poor_count <=
  snapshot.kpis.length() &&
  snapshot.overall_score >= 0.0 &&
  snapshot.overall_score <= 100.0
}

///|
pub fn service_kpi_target_valid(target : ServiceKpiTarget) -> Bool {
  target.target.is_nan() == false &&
  target.tolerance >= 0.0 &&
  target.tolerance.is_nan() == false
}

///|
pub fn service_kpi_targets_valid(targets : Array[ServiceKpiTarget]) -> Bool {
  targets.length() > 0 &&
  targets.all(target => service_kpi_target_valid(target))
}

///|
pub fn service_kpi_report_valid(report : ServiceKpiReport) -> Bool {
  service_kpi_snapshot_valid(report.snapshot) &&
  report.required_count >= report.required_failures &&
  report.required_failures >= 0 &&
  report.messages.length() == report.required_failures
}

///|
pub fn service_kpi_kind_values() -> Array[ServiceKpiKind] {
  [
    KpiQuality,
    KpiCoverage,
    KpiRisk,
    KpiReadiness,
    KpiRecovery,
    KpiAlertRate,
    KpiEventRate,
    KpiInterventionRate,
    KpiThroughput,
    KpiActionDensity,
    KpiDataCompleteness,
    KpiReviewLatency,
  ]
}

///|
pub fn service_kpi_kind_names() -> Array[String] {
  service_kpi_kind_values().map(kind => service_kpi_kind_name(kind))
}

///|
pub fn service_kpi_band_values() -> Array[ServiceKpiBand] {
  [KpiGood, KpiWatch, KpiPoor, KpiUnknown]
}

///|
pub fn service_kpi_band_names() -> Array[String] {
  service_kpi_band_values().map(band => service_kpi_band_name(band))
}

///|
pub fn service_kpi_highest_priority(
  snapshot : ServiceKpiSnapshot,
) -> ServiceKpi? {
  if snapshot.kpis.length() == 0 {
    None
  } else {
    let mut result = snapshot.kpis[0]
    for kpi in snapshot.kpis {
      if service_kpi_band_rank(kpi.band) > service_kpi_band_rank(result.band) {
        result = kpi
      }
    }
    Some(result)
  }
}

///|
pub fn service_kpi_priority(snapshot : ServiceKpiSnapshot) -> String {
  match service_kpi_highest_priority(snapshot) {
    Some(kpi) => kpi.name
    None => "none"
  }
}

///|
pub fn service_kpi_risk_status(snapshot : ServiceKpiSnapshot) -> String {
  service_kpi_status_for(snapshot, KpiRisk)
}

///|
pub fn service_kpi_quality_status(snapshot : ServiceKpiSnapshot) -> String {
  service_kpi_status_for(snapshot, KpiQuality)
}

///|
pub fn service_kpi_coverage_status(snapshot : ServiceKpiSnapshot) -> String {
  service_kpi_status_for(snapshot, KpiCoverage)
}

///|
pub fn service_kpi_readiness_status(snapshot : ServiceKpiSnapshot) -> String {
  service_kpi_status_for(snapshot, KpiReadiness)
}

///|
pub fn service_kpi_recovery_status(snapshot : ServiceKpiSnapshot) -> String {
  service_kpi_status_for(snapshot, KpiRecovery)
}

///|
pub fn service_kpi_action_rate(snapshot : ServiceKpiSnapshot) -> Double {
  service_kpi_value(snapshot, KpiActionDensity)
}

///|
pub fn service_kpi_quality_score(snapshot : ServiceKpiSnapshot) -> Double {
  service_kpi_value(snapshot, KpiQuality)
}

///|
pub fn service_kpi_risk_score(snapshot : ServiceKpiSnapshot) -> Double {
  service_kpi_value(snapshot, KpiRisk)
}

///|
pub fn service_kpi_readiness_score(snapshot : ServiceKpiSnapshot) -> Double {
  service_kpi_value(snapshot, KpiReadiness)
}

///|
pub fn service_kpi_recovery_score(snapshot : ServiceKpiSnapshot) -> Double {
  service_kpi_value(snapshot, KpiRecovery)
}

///|
pub fn service_kpi_alert_rate(snapshot : ServiceKpiSnapshot) -> Double {
  service_kpi_value(snapshot, KpiAlertRate)
}

///|
pub fn service_kpi_event_rate(snapshot : ServiceKpiSnapshot) -> Double {
  service_kpi_value(snapshot, KpiEventRate)
}

///|
pub fn service_kpi_intervention_rate(snapshot : ServiceKpiSnapshot) -> Double {
  service_kpi_value(snapshot, KpiInterventionRate)
}

///|
pub fn service_kpi_throughput(snapshot : ServiceKpiSnapshot) -> Double {
  service_kpi_value(snapshot, KpiThroughput)
}

///|
pub fn service_kpi_completeness(snapshot : ServiceKpiSnapshot) -> Double {
  service_kpi_value(snapshot, KpiDataCompleteness)
}

///|
pub fn service_kpi_review_latency(snapshot : ServiceKpiSnapshot) -> Double {
  service_kpi_value(snapshot, KpiReviewLatency)
}

///|
pub fn service_kpi_compare(
  left : ServiceKpi,
  right : ServiceKpi,
) -> ServiceKpiComparison {
  let change = right.value - left.value
  {
    kind: right.kind,
    left_value: left.value,
    right_value: right.value,
    change,
    change_percent: percentage_change(left.value, right.value),
    left_band: left.band,
    right_band: right.band,
    conclusion: if service_kpi_band_rank(right.band) <
      service_kpi_band_rank(left.band) {
      "kpi improved"
    } else if service_kpi_band_rank(right.band) >
      service_kpi_band_rank(left.band) {
      "kpi degraded"
    } else {
      "kpi band is unchanged"
    },
  }
}

///|
pub fn service_kpi_snapshot_compare(
  left : ServiceKpiSnapshot,
  right : ServiceKpiSnapshot,
) -> Array[ServiceKpiComparison] {
  let values = []
  for kind in service_kpi_kind_values() {
    match (service_kpi_by_kind(left, kind), service_kpi_by_kind(right, kind)) {
      (Some(a), Some(b)) => values.push(service_kpi_compare(a, b))
      _ => ()
    }
  }
  values
}

///|
pub fn service_kpi_comparison_text(comparison : ServiceKpiComparison) -> String {
  service_kpi_kind_name(comparison.kind) +
  " left=" +
  comparison.left_value.to_string() +
  " right=" +
  comparison.right_value.to_string() +
  " change=" +
  comparison.change.to_string() +
  " conclusion=" +
  comparison.conclusion
}

///|
pub fn service_kpi_comparisons_text(
  comparisons : Array[ServiceKpiComparison],
) -> String {
  comparisons.map(item => service_kpi_comparison_text(item)).join("\n")
}

///|
pub fn service_kpi_csv_header() -> String {
  "kind,name,value,target,unit,band,status,evidence"
}

///|
pub fn service_kpi_csv(kpi : ServiceKpi) -> String {
  service_kpi_kind_name(kpi.kind) +
  "," +
  kpi.name +
  "," +
  kpi.value.to_string() +
  "," +
  kpi.target.to_string() +
  "," +
  kpi.unit +
  "," +
  service_kpi_band_name(kpi.band) +
  "," +
  kpi.status +
  "," +
  kpi.evidence
}

///|
pub fn service_kpi_snapshot_csv(snapshot : ServiceKpiSnapshot) -> String {
  let builder = StringBuilder::new()
  builder.write_string(service_kpi_csv_header())
  for kpi in snapshot.kpis {
    builder.write_string("\n" + service_kpi_csv(kpi))
  }
  builder.to_string()
}

///|
pub fn service_kpi_snapshot_text(snapshot : ServiceKpiSnapshot) -> String {
  let builder = StringBuilder::new()
  builder.write_string(
    "run=" +
    snapshot.run_id +
    " date=" +
    snapshot.generated_for +
    " status=" +
    snapshot.status +
    " score=" +
    snapshot.overall_score.to_string(),
  )
  builder.write_string("\nrecommendation=" + snapshot.recommendation)
  for kpi in snapshot.kpis {
    builder.write_string(
      "\n" +
      service_kpi_kind_name(kpi.kind) +
      "=" +
      kpi.value.to_string() +
      " " +
      service_kpi_band_name(kpi.band),
    )
  }
  builder.to_string()
}

///|
pub fn service_kpi_snapshot_summary(
  snapshot : ServiceKpiSnapshot,
) -> Array[String] {
  [
    snapshot.run_id,
    snapshot.generated_for,
    snapshot.status,
    snapshot.overall_score.to_string(),
    snapshot.good_count.to_string(),
    snapshot.watch_count.to_string(),
    snapshot.poor_count.to_string(),
    service_kpi_priority(snapshot),
  ]
}

///|
pub fn service_kpi_snapshot_summary_header() -> Array[String] {
  [
    "run_id", "generated_for", "status", "overall_score", "good_count", "watch_count",
    "poor_count", "priority",
  ]
}

///|
pub fn service_kpi_snapshot_summary_csv(
  snapshot : ServiceKpiSnapshot,
) -> String {
  service_kpi_snapshot_summary_header().join(",") +
  "\n" +
  service_kpi_snapshot_summary(snapshot).join(",")
}

///|
pub fn service_kpi_actionable(snapshot : ServiceKpiSnapshot) -> Bool {
  snapshot.poor_count > 0 || snapshot.watch_count >= 3
}

///|
pub fn service_kpi_stable(snapshot : ServiceKpiSnapshot) -> Bool {
  snapshot.status == "good"
}

///|
pub fn service_kpi_requires_review(snapshot : ServiceKpiSnapshot) -> Bool {
  service_kpi_actionable(snapshot) || !service_kpi_snapshot_valid(snapshot)
}

///|
pub fn service_kpi_status_code(snapshot : ServiceKpiSnapshot) -> Int {
  if snapshot.status == "good" {
    200
  } else if snapshot.status == "watch" {
    206
  } else if snapshot.status == "action" {
    409
  } else {
    422
  }
}

///|
pub fn service_kpi_count(snapshot : ServiceKpiSnapshot) -> Int {
  snapshot.kpis.length()
}

///|
pub fn service_kpi_average(snapshot : ServiceKpiSnapshot) -> Double {
  mean_load_values(service_kpi_values(snapshot))
}

///|
pub fn service_kpi_minimum(snapshot : ServiceKpiSnapshot) -> Double {
  minimum_load_values(service_kpi_values(snapshot))
}

///|
pub fn service_kpi_maximum(snapshot : ServiceKpiSnapshot) -> Double {
  maximum_load_values(service_kpi_values(snapshot))
}

///|
pub fn service_kpi_deviation(snapshot : ServiceKpiSnapshot) -> Double {
  standard_deviation_values(service_kpi_values(snapshot))
}

///|
pub fn service_kpi_poor_names(snapshot : ServiceKpiSnapshot) -> Array[String] {
  service_kpi_poor(snapshot).map(kpi => kpi.name)
}

///|
pub fn service_kpi_watch_names(snapshot : ServiceKpiSnapshot) -> Array[String] {
  service_kpi_watch(snapshot).map(kpi => kpi.name)
}

///|
pub fn service_kpi_good_names(snapshot : ServiceKpiSnapshot) -> Array[String] {
  service_kpi_good(snapshot).map(kpi => kpi.name)
}

///|
pub fn service_kpi_poor_message(snapshot : ServiceKpiSnapshot) -> String {
  if snapshot.poor_count == 0 {
    "no poor KPI"
  } else {
    "poor KPIs: " + service_kpi_poor_names(snapshot).join(",")
  }
}

///|
pub fn service_kpi_watch_message(snapshot : ServiceKpiSnapshot) -> String {
  if snapshot.watch_count == 0 {
    "no watch KPI"
  } else {
    "watch KPIs: " + service_kpi_watch_names(snapshot).join(",")
  }
}

///|
pub fn service_kpi_good_message(snapshot : ServiceKpiSnapshot) -> String {
  if snapshot.good_count == 0 {
    "no KPI met target"
  } else {
    "good KPIs: " + service_kpi_good_names(snapshot).join(",")
  }
}

///|
pub fn service_kpi_messages(snapshot : ServiceKpiSnapshot) -> Array[String] {
  [
    service_kpi_poor_message(snapshot),
    service_kpi_watch_message(snapshot),
    service_kpi_good_message(snapshot),
    snapshot.recommendation,
  ]
}

///|
pub fn service_kpi_target_names(
  targets : Array[ServiceKpiTarget],
) -> Array[String] {
  targets.map(target => service_kpi_kind_name(target.kind))
}

///|
pub fn service_kpi_target_values(
  targets : Array[ServiceKpiTarget],
) -> Array[Double] {
  targets.map(target => target.target)
}

///|
pub fn service_kpi_target_required_names(
  targets : Array[ServiceKpiTarget],
) -> Array[String] {
  targets
  .filter(target => target.required)
  .map(target => service_kpi_kind_name(target.kind))
}

///|
pub fn service_kpi_target_text(target : ServiceKpiTarget) -> String {
  service_kpi_kind_name(target.kind) +
  " target=" +
  target.target.to_string() +
  " tolerance=" +
  target.tolerance.to_string() +
  " higher_is_better=" +
  target.higher_is_better.to_string() +
  " required=" +
  target.required.to_string()
}

///|
pub fn service_kpi_targets_text(targets : Array[ServiceKpiTarget]) -> String {
  targets.map(target => service_kpi_target_text(target)).join("\n")
}

///|
pub fn service_kpi_target_csv_header() -> String {
  "kind,target,tolerance,higher_is_better,required"
}

///|
pub fn service_kpi_target_csv(target : ServiceKpiTarget) -> String {
  service_kpi_kind_name(target.kind) +
  "," +
  target.target.to_string() +
  "," +
  target.tolerance.to_string() +
  "," +
  target.higher_is_better.to_string() +
  "," +
  target.required.to_string()
}

///|
pub fn service_kpi_targets_csv(targets : Array[ServiceKpiTarget]) -> String {
  let builder = StringBuilder::new()
  builder.write_string(service_kpi_target_csv_header())
  for target in targets {
    builder.write_string("\n" + service_kpi_target_csv(target))
  }
  builder.to_string()
}

///|
pub fn service_kpi_checksum(snapshot : ServiceKpiSnapshot) -> String {
  let mut value = snapshot.run_id.length() + snapshot.kpis.length()
  for character in service_kpi_snapshot_csv(snapshot) {
    value = (value * 33 + character.to_int()) % 2147483647
  }
  value.to_string()
}

///|
pub fn service_kpi_reproducible(
  left : ServiceKpiSnapshot,
  right : ServiceKpiSnapshot,
) -> Bool {
  service_kpi_checksum(left) == service_kpi_checksum(right)
}

///|
pub fn service_kpi_metric_names() -> Array[String] {
  service_kpi_kind_names()
}

///|
pub fn service_kpi_metric(
  snapshot : ServiceKpiSnapshot,
  name : String,
) -> Double {
  match service_kpi_by_name(snapshot, name) {
    Some(kpi) => kpi.value
    None => 0.0
  }
}

///|
pub fn service_kpi_metric_band(
  snapshot : ServiceKpiSnapshot,
  name : String,
) -> ServiceKpiBand {
  match service_kpi_by_name(snapshot, name) {
    Some(kpi) => kpi.band
    None => KpiUnknown
  }
}

///|
pub fn service_kpi_metric_evidence(
  snapshot : ServiceKpiSnapshot,
  name : String,
) -> String {
  match service_kpi_by_name(snapshot, name) {
    Some(kpi) => kpi.evidence
    None => ""
  }
}

///|
pub fn service_kpi_metric_status(
  snapshot : ServiceKpiSnapshot,
  name : String,
) -> String {
  service_kpi_status(service_kpi_metric_band(snapshot, name))
}

///|
pub fn service_kpi_snapshot_projection(
  snapshot : ServiceKpiSnapshot,
  names : Array[String],
) -> Array[Double] {
  names.map(name => service_kpi_metric(snapshot, name))
}

///|
pub fn service_kpi_snapshot_projection_text(
  snapshot : ServiceKpiSnapshot,
  names : Array[String],
) -> String {
  service_kpi_snapshot_projection(snapshot, names)
  .map(value => value.to_string())
  .join(",")
}

///|
pub fn service_kpi_snapshot_required_status(
  snapshot : ServiceKpiSnapshot,
  targets : Array[ServiceKpiTarget],
) -> String {
  if service_kpi_passes(snapshot, targets) {
    "accepted"
  } else {
    "rejected"
  }
}

///|
pub fn service_kpi_snapshot_contract(
  snapshot : ServiceKpiSnapshot,
) -> Array[String] {
  [
    service_kpi_status_code(snapshot).to_string(),
    service_kpi_snapshot_valid(snapshot).to_string(),
    service_kpi_requires_review(snapshot).to_string(),
    service_kpi_checksum(snapshot),
  ]
}

///|
pub fn service_kpi_snapshot_for_run(run : DecisionRun) -> ServiceKpiSnapshot {
  service_kpi_snapshot_default(run, performance_snapshot([], [], run))
}

///|
pub fn service_kpi_status_line(snapshot : ServiceKpiSnapshot) -> String {
  snapshot.generated_for +
  " status=" +
  snapshot.status +
  " score=" +
  snapshot.overall_score.to_string() +
  " priority=" +
  service_kpi_priority(snapshot)
}

///|
pub fn service_kpi_report_lines(report : ServiceKpiReport) -> Array[String] {
  [
    service_kpi_report_message(report),
    service_kpi_poor_message(report.snapshot),
    service_kpi_watch_message(report.snapshot),
    report.snapshot.recommendation,
  ]
}

///|
pub fn service_kpi_report_csv(report : ServiceKpiReport) -> String {
  service_kpi_snapshot_csv(report.snapshot)
}

///|
pub fn service_kpi_report_checksum(report : ServiceKpiReport) -> String {
  service_kpi_checksum(report.snapshot) + "-" + report.valid.to_string()
}

///|
pub fn service_kpi_report_status(report : ServiceKpiReport) -> String {
  if report.valid {
    "accepted"
  } else {
    "review"
  }
}

///|
pub fn service_kpi_report_requires_action(report : ServiceKpiReport) -> Bool {
  !report.valid || service_kpi_actionable(report.snapshot)
}

///|
pub fn service_kpi_report_recommendation(report : ServiceKpiReport) -> String {
  if report.valid {
    report.snapshot.recommendation
  } else {
    "resolve required KPI failures"
  }
}
