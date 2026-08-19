///|
/// A pain episode extracted from daily athlete telemetry.
pub(all) struct PainEpisode {
  date : String
  level : Double
  site : String
  persistent_days : Int
  escalating : Bool
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PainSummary {
  observed_days : Int
  painful_days : Int
  maximum_level : Double
  average_level : Double
  burden : Double
  persistent_sites : Array[String]
  latest_episode : PainEpisode?
  escalation : Bool
} derive(Debug, Eq, ToJson)

///|
pub fn pain_site_name(site : String?) -> String {
  match site {
    Some(value) => if value == "" { "unspecified" } else { value }
    None => "unspecified"
  }
}

///|
pub fn painful_records(
  records : Array[DailyRecord],
  threshold : Double,
) -> Array[DailyRecord] {
  records.filter(record => record.pain_level >= threshold)
}

///|
pub fn pain_levels(records : Array[DailyRecord]) -> Array[Double] {
  records.map(record => record.pain_level)
}

///|
pub fn pain_burden(records : Array[DailyRecord]) -> Double {
  total_load_values(pain_levels(records))
}

///|
pub fn pain_free_ratio(records : Array[DailyRecord]) -> Double {
  if records.length() == 0 {
    0.0
  } else {
    records.filter(record => record.pain_level <= 0.0).length().to_double() /
    records.length().to_double()
  }
}

///|
pub fn maximum_pain_change(records : Array[DailyRecord]) -> Double {
  let levels = pain_levels(records)
  let differences = first_differences(levels)
  maximum_load_values(differences)
}

///|
pub fn pain_escalating(
  records : Array[DailyRecord],
  minimum_change : Double,
) -> Bool {
  if records.length() < 2 {
    false
  } else {
    let first = records[0].pain_level
    let last = records[records.length() - 1].pain_level
    last - first >= minimum_change
  }
}

///|
pub fn pain_site_totals(
  records : Array[DailyRecord],
) -> Array[(String, Double)] {
  let sites : Array[String] = []
  let totals : Array[Double] = []
  for record in records {
    let site = pain_site_name(record.pain_site)
    let mut found = -1
    for index in 0..<sites.length() {
      if sites[index] == site {
        found = index
        break
      }
    }
    if found < 0 {
      sites.push(site)
      totals.push(record.pain_level)
    } else {
      totals[found] += record.pain_level
    }
  }
  let result = []
  for index in 0..<sites.length() {
    result.push((sites[index], totals[index]))
  }
  result
}

///|
pub fn dominant_pain_site(records : Array[DailyRecord]) -> String? {
  let totals = pain_site_totals(records)
  if totals.length() == 0 {
    return None
  }
  let mut best = totals[0]
  for item in totals {
    if item.1 > best.1 {
      best = item
    }
  }
  Some(best.0)
}

///|
pub fn persistent_pain_sites(
  records : Array[DailyRecord],
  threshold : Double,
  minimum_days : Int,
) -> Array[String] {
  let counts : Array[(String, Int)] = []
  let sites : Array[String] = []
  for record in records {
    if record.pain_level >= threshold {
      let site = pain_site_name(record.pain_site)
      let mut found = -1
      for index in 0..<sites.length() {
        if sites[index] == site {
          found = index
          break
        }
      }
      if found < 0 {
        sites.push(site)
        counts.push((site, 1))
      } else {
        counts[found] = (site, counts[found].1 + 1)
      }
    }
  }
  counts.filter(item => item.1 >= minimum_days).map(item => item.0)
}

///|
pub fn pain_episodes(
  records : Array[DailyRecord],
  threshold : Double,
) -> Array[PainEpisode] {
  let episodes = []
  let mut run = 0
  for index, record in records {
    if record.pain_level >= threshold {
      run += 1
      let previous = if index == 0 {
        0.0
      } else {
        records[index - 1].pain_level
      }
      episodes.push({
        date: record.date,
        level: record.pain_level,
        site: pain_site_name(record.pain_site),
        persistent_days: run,
        escalating: record.pain_level > previous,
      })
    } else {
      run = 0
    }
  }
  episodes
}

///|
pub fn summarize_pain(
  records : Array[DailyRecord],
  threshold : Double,
  persistence_days : Int,
) -> PainSummary {
  let painful = painful_records(records, threshold)
  let episodes = pain_episodes(records, threshold)
  let persistent = persistent_pain_sites(records, threshold, persistence_days)
  {
    observed_days: records.length(),
    painful_days: painful.length(),
    maximum_level: max_pain_level(records),
    average_level: mean_load_values(pain_levels(records)),
    burden: pain_burden(records),
    persistent_sites: persistent,
    latest_episode: if episodes.length() == 0 {
      None
    } else {
      Some(episodes[episodes.length() - 1])
    },
    escalation: pain_escalating(records, 2.0),
  }
}

///|
pub fn pain_summary_text(summary : PainSummary) -> String {
  "painful_days=" +
  summary.painful_days.to_string() +
  " maximum=" +
  summary.maximum_level.to_string() +
  " average=" +
  summary.average_level.to_string() +
  " burden=" +
  summary.burden.to_string() +
  " escalation=" +
  summary.escalation.to_string()
}
