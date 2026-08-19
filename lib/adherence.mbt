///|
/// A planned training target for one date.
pub(all) struct TrainingTarget {
  date : String
  target_duration : Double
  target_intensity : Double
  target_kind : SessionKind
  require_rest : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) enum AdherenceStatus {
  Met
  Partial
  Missed
  NotRecorded
} derive(Debug, Eq, ToJson)

///|
pub(all) struct AdherenceRow {
  date : String
  status : AdherenceStatus
  target_load : Double
  actual_load : Double
  load_difference_percent : Double
  recovery_ok : Bool
  explanation : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct AdherenceReport {
  target_count : Int
  met_count : Int
  partial_count : Int
  missed_count : Int
  not_recorded_count : Int
  adherence_percent : Double
  rows : Array[AdherenceRow]
} derive(Debug, Eq, ToJson)

///|
pub fn training_target(
  date : String,
  duration : Double,
  intensity : Double,
  kind : SessionKind,
  require_rest : Bool,
) -> TrainingTarget {
  {
    date,
    target_duration: duration,
    target_intensity: intensity,
    target_kind: kind,
    require_rest,
  }
}

///|
pub fn adherence_status_name(status : AdherenceStatus) -> String {
  match status {
    Met => "met"
    Partial => "partial"
    Missed => "missed"
    NotRecorded => "not-recorded"
  }
}

///|
fn percentage_difference(expected : Double, actual : Double) -> Double {
  if expected == 0.0 {
    if actual == 0.0 {
      0.0
    } else {
      100.0
    }
  } else {
    (actual - expected) / expected * 100.0
  }
}

///|
pub fn assess_target(
  target : TrainingTarget,
  record : DailyRecord?,
  recovery_threshold : Double,
) -> AdherenceRow {
  match record {
    None =>
      {
        date: target.date,
        status: NotRecorded,
        target_load: target.target_duration * target.target_intensity,
        actual_load: 0.0,
        load_difference_percent: -100.0,
        recovery_ok: false,
        explanation: "no telemetry record was found for the target date",
      }
    Some(record) => {
      let target_load = target.target_duration * target.target_intensity
      let actual_load = daily_training_load(record)
      let difference = percentage_difference(target_load, actual_load)
      let recovery = record_recovery_score(
        record,
        default_recovery_weights(),
        8.0,
      )
      let status = if target.require_rest && actual_load > 0.0 {
        Missed
      } else if target_load == 0.0 && actual_load == 0.0 {
        Met
      } else if (actual_load - target_load).abs() <= target_load * 0.10 {
        Met
      } else if (actual_load - target_load).abs() <= target_load * 0.30 {
        Partial
      } else {
        Missed
      }
      {
        date: target.date,
        status,
        target_load,
        actual_load,
        load_difference_percent: difference,
        recovery_ok: recovery >= recovery_threshold,
        explanation: "target=" +
        target_load.to_string() +
        " actual=" +
        actual_load.to_string() +
        " recovery=" +
        recovery.to_string(),
      }
    }
  }
}

///|
pub fn adherence_report(
  targets : Array[TrainingTarget],
  records : Array[DailyRecord],
  recovery_threshold : Double,
) -> AdherenceReport {
  let rows = []
  for target in targets {
    rows.push(
      assess_target(
        target,
        find_record(records, target.date),
        recovery_threshold,
      ),
    )
  }
  let met = rows.filter(row => row.status == Met).length()
  let partial = rows.filter(row => row.status == Partial).length()
  let missed = rows.filter(row => row.status == Missed).length()
  let not_recorded = rows.filter(row => row.status == NotRecorded).length()
  {
    target_count: targets.length(),
    met_count: met,
    partial_count: partial,
    missed_count: missed,
    not_recorded_count: not_recorded,
    adherence_percent: if targets.length() == 0 {
      0.0
    } else {
      (met.to_double() + partial.to_double() * 0.5) /
      targets.length().to_double() *
      100.0
    },
    rows,
  }
}

///|
fn find_record(records : Array[DailyRecord], date : String) -> DailyRecord? {
  for record in records {
    if record.date == date {
      return Some(record)
    }
  }
  None
}

///|
pub fn default_targets(records : Array[DailyRecord]) -> Array[TrainingTarget] {
  records.map(record => {
    training_target(
      record.date,
      record.training_duration,
      record.training_intensity,
      Mixed,
      false,
    )
  })
}

///|
pub fn rest_day_targets(dates : Array[String]) -> Array[TrainingTarget] {
  dates.map(date => training_target(date, 0.0, 0.0, Recovery, true))
}

///|
pub fn recovery_adherence_percent(
  records : Array[DailyRecord],
  target_sleep : Double,
  minimum_quality : Double,
) -> Double {
  if records.length() == 0 {
    0.0
  } else {
    let count = records
      .filter(record => {
        record.sleep_hours >= target_sleep &&
        record.sleep_quality >= minimum_quality
      })
      .length()
    count.to_double() / records.length().to_double() * 100.0
  }
}

///|
pub fn pain_reporting_percent(records : Array[DailyRecord]) -> Double {
  if records.length() == 0 {
    0.0
  } else {
    let recorded = records
      .filter(record => record.pain_level > 0.0 || record.pain_site is Some(_))
      .length()
    recorded.to_double() / records.length().to_double() * 100.0
  }
}

///|
pub fn adherence_report_text(report : AdherenceReport) -> String {
  "targets=" +
  report.target_count.to_string() +
  " met=" +
  report.met_count.to_string() +
  " partial=" +
  report.partial_count.to_string() +
  " missed=" +
  report.missed_count.to_string() +
  " not_recorded=" +
  report.not_recorded_count.to_string() +
  " adherence=" +
  report.adherence_percent.to_string() +
  "%"
}
