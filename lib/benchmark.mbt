///|
/// Deterministic workload used by the native benchmark command.
pub(all) struct BenchmarkResult {
  iterations : Int
  record_count : Int
  assessments : Int
  high_risk_assessments : Int
  checksum : Double
} derive(Debug, Eq, ToJson)

///|
pub fn benchmark_records(days : Int) -> Array[DailyRecord] {
  generate_scenario(RapidProgression, days)
}

///|
pub fn run_benchmark(iterations : Int, days : Int) -> BenchmarkResult {
  let count = iterations.max(0)
  let records = benchmark_records(days.max(0))
  let policy = default_risk_policy()
  let mut assessments = 0
  let mut high = 0
  let mut checksum = 0.0
  for _ in 0..<count {
    match assess_latest(records, policy) {
      Some(assessment) => {
        assessments += 1
        if assessment.risk_level == High {
          high += 1
        }
        checksum += assessment.risk_score +
          assessment.readiness_score +
          assessment.load.acwr
      }
      None => ()
    }
  }
  {
    iterations: count,
    record_count: records.length(),
    assessments,
    high_risk_assessments: high,
    checksum,
  }
}

///|
pub fn benchmark_result_text(result : BenchmarkResult) -> String {
  "iterations=" +
  result.iterations.to_string() +
  " records=" +
  result.record_count.to_string() +
  " assessments=" +
  result.assessments.to_string() +
  " high_risk=" +
  result.high_risk_assessments.to_string() +
  " checksum=" +
  result.checksum.to_string()
}
