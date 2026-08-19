///|
/// In-memory telemetry store for applications that append one day at a time.
pub(all) struct TelemetryStore {
  records : Array[DailyRecord]
  revision : Int
  policy : QualityPolicy
} derive(Debug, Eq, ToJson)

///|
pub(all) struct StoreUpdate {
  accepted : Bool
  revision : Int
  issues : Array[QualityIssue]
  record_count : Int
} derive(Debug, Eq, ToJson)

///|
pub fn new_telemetry_store(
  records : Array[DailyRecord],
  policy : QualityPolicy,
) -> TelemetryStore {
  { records: normalize_records(records), revision: 1, policy }
}

///|
pub fn store_records(store : TelemetryStore) -> Array[DailyRecord] {
  store.records.copy()
}

///|
pub fn store_revision(store : TelemetryStore) -> Int {
  store.revision
}

///|
pub fn store_quality(store : TelemetryStore) -> QualityReport {
  validate_records(store.records, store.policy)
}

///|
pub fn append_record(
  store : TelemetryStore,
  record : DailyRecord,
) -> (TelemetryStore, StoreUpdate) {
  let issues = validate_record(record, store.records.length(), store.policy)
  if issues.length() > 0 {
    (
      store,
      {
        accepted: false,
        revision: store.revision,
        issues,
        record_count: store.records.length(),
      },
    )
  } else {
    let records = store.records.copy()
    records.push(record)
    let next = {
      records: normalize_records(records),
      revision: store.revision + 1,
      policy: store.policy,
    }
    (
      next,
      {
        accepted: true,
        revision: next.revision,
        issues: [],
        record_count: next.records.length(),
      },
    )
  }
}

///|
pub fn append_records(
  store : TelemetryStore,
  records : Array[DailyRecord],
) -> (TelemetryStore, Array[StoreUpdate]) {
  let mut current = store
  let updates = []
  for record in records {
    let result = append_record(current, record)
    current = result.0
    updates.push(result.1)
  }
  (current, updates)
}

///|
pub fn record_at_date(store : TelemetryStore, date : String) -> DailyRecord? {
  for record in store.records {
    if record.date == date {
      return Some(record)
    }
  }
  None
}

///|
pub fn records_between(
  store : TelemetryStore,
  start : String,
  end : String,
) -> Array[DailyRecord] {
  let start_date = parse_date(start)
  let end_date = parse_date(end)
  match (start_date, end_date) {
    (Some(start_date), Some(end_date)) =>
      match make_date_range(start_date, end_date) {
        Some(range) => records_in_date_range(store.records, range)
        None => []
      }
    _ => []
  }
}

///|
pub fn replace_record(
  store : TelemetryStore,
  record : DailyRecord,
) -> (TelemetryStore, StoreUpdate) {
  let issues = validate_record(record, -1, store.policy)
  if issues.length() > 0 {
    (
      store,
      {
        accepted: false,
        revision: store.revision,
        issues,
        record_count: store.records.length(),
      },
    )
  } else {
    let records = store.records.filter(item => item.date != record.date)
    records.push(record)
    let next = {
      records: normalize_records(records),
      revision: store.revision + 1,
      policy: store.policy,
    }
    (
      next,
      {
        accepted: true,
        revision: next.revision,
        issues: [],
        record_count: next.records.length(),
      },
    )
  }
}

///|
pub fn remove_record(
  store : TelemetryStore,
  date : String,
) -> (TelemetryStore, StoreUpdate) {
  let records = store.records.filter(item => item.date != date)
  if records.length() == store.records.length() {
    (
      store,
      {
        accepted: false,
        revision: store.revision,
        issues: [],
        record_count: store.records.length(),
      },
    )
  } else {
    let next = { records, revision: store.revision + 1, policy: store.policy }
    (
      next,
      {
        accepted: true,
        revision: next.revision,
        issues: [],
        record_count: next.records.length(),
      },
    )
  }
}

///|
pub fn latest_record(store : TelemetryStore) -> DailyRecord? {
  if store.records.length() == 0 {
    None
  } else {
    Some(store.records[store.records.length() - 1])
  }
}

///|
pub fn store_load_summary(
  store : TelemetryStore,
  window_size : Int,
) -> LoadSummary {
  summarize_load_window(store.records, window_size)
}

///|
pub fn store_timeline(store : TelemetryStore) -> RiskTimeline {
  build_timeline(store.records, default_risk_policy())
}

///|
pub fn store_snapshot(store : TelemetryStore) -> String {
  let quality = store_quality(store)
  "revision=" +
  store.revision.to_string() +
  " records=" +
  store.records.length().to_string() +
  " quality=" +
  quality.score.to_string()
}

///|
pub fn store_retained_dates(store : TelemetryStore) -> Array[String] {
  store.records.map(record => record.date)
}

///|
pub fn store_is_continuous(store : TelemetryStore) -> Bool {
  missing_dates(store.records).length() == 0 &&
  duplicate_date_indices(store.records).length() == 0
}

///|
pub fn trim_store_before(
  store : TelemetryStore,
  date : String,
) -> TelemetryStore {
  let cutoff = parse_date(date)
  match cutoff {
    Some(cutoff) =>
      {
        records: store.records.filter(record => {
          match parse_date(record.date) {
            Some(value) => !(compare_dates(value, cutoff) is Before)
            None => false
          }
        }),
        revision: store.revision + 1,
        policy: store.policy,
      }
    None => store
  }
}
