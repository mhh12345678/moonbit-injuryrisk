///|
/// Telemetry record representing a single day's training load and recovery state.
pub(all) struct DailyRecord {
  date : String
  training_duration : Double // in minutes, e.g. 60.0
  training_intensity : Double // RPE scale 1-10
  pain_level : Double // scale 0-10
  pain_site : String? // optional pain location description
  sleep_hours : Double // sleep duration
  sleep_quality : Double // scale 1-5
  fatigue : Double // subjective fatigue scale 1-10
} derive(Debug, Eq, ToJson)

///|
/// Metrics that can be evaluated over a sliding window.
pub(all) enum Metric {
  AcuteLoad // Average training load (duration * intensity) over the acute window (typically 7 days)
  ChronicLoad // Average training load over the chronic window (typically 28 days)
  ACWR // Acute to Chronic Workload Ratio (AcuteLoad / ChronicLoad)
  SleepHours // Average sleep duration in hours over the window
  SleepQuality // Average sleep quality over the window
  PainLevel // Maximum pain level over the window
  FatigueLevel // Average subjective fatigue level over the window
  LoadSpike // Percentage increase of acute load compared to the previous week
} derive(Debug, Eq, ToJson)

///|
/// Operators for rule conditions.
pub(all) enum Operator {
  GreaterThan
  LessThan
  EqualTo
} derive(Debug, Eq, ToJson)

///|
/// Risk levels for stratification.
pub(all) enum RiskLevel {
  Low
  Medium
  High
} derive(Debug, Eq, ToJson)

///|
/// Compare and returns the highest of two RiskLevels.
pub fn RiskLevel::max(self : RiskLevel, other : RiskLevel) -> RiskLevel {
  match (self, other) {
    (High, _) | (_, High) => High
    (Medium, _) | (_, Medium) => Medium
    _ => Low
  }
}

///|
/// Rule condition mapping a Metric condition to a RiskLevel severity.
pub(all) struct Rule {
  name : String
  metric : Metric
  op : Operator
  threshold : Double
  window_size : Int // sliding window size in days
  severity : RiskLevel
  description : String
} derive(Debug, Eq, ToJson)

///|
/// Evaluation result for a specific rule.
pub(all) struct RuleResult {
  rule : Rule
  triggered : Bool
  actual_value : Double
  explanation : String
} derive(Debug, Eq, ToJson)

///|
/// Overall risk assessment report.
pub(all) struct RiskAssessment {
  date : String
  risk_level : RiskLevel
  triggered_rules : Array[RuleResult]
  summary : String
} derive(Debug, Eq, ToJson)
