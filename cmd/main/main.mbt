///|
fn main {
  let rules = @lib.get_default_rules()

  println("==================================================")
  println("  MOONBIT INJURY RISK RULE ENGINE DEMO")
  println("==================================================")

  // 1. Healthy Athlete
  let healthy_records = @lib.generate_healthy_athlete()
  match @lib.assess_injury_risk(healthy_records, "2026-08-30", rules) {
    Some(report) => {
      println(
        "\n>>> SCENARIO 1: HEALTHY ATHLETE (Balanced Workload & Recovery)",
      )
      println("Report Summary:")
      println(report.summary)
    }
    None => println("Failed to generate report for Healthy Athlete.")
  }

  // 2. Workload Spike Athlete
  let spike_records = @lib.generate_workload_spike_athlete()
  match @lib.assess_injury_risk(spike_records, "2026-08-30", rules) {
    Some(report) => {
      println("\n>>> SCENARIO 2: WORKLOAD SPIKE ATHLETE (ACWR > 1.5)")
      println("Report Summary:")
      println(report.summary)
    }
    None => println("Failed to generate report for Workload Spike Athlete.")
  }

  // 3. Overtired Athlete
  let overtired_records = @lib.generate_overtired_athlete()
  match @lib.assess_injury_risk(overtired_records, "2026-08-30", rules) {
    Some(report) => {
      println(
        "\n>>> SCENARIO 3: OVERTIRED ATHLETE (Sleep Deprived & High Fatigue)",
      )
      println("Report Summary:")
      println(report.summary)
    }
    None => println("Failed to generate report for Overtired Athlete.")
  }

  // 4. Injured Athlete
  let injured_records = @lib.generate_injured_athlete()
  match @lib.assess_injury_risk(injured_records, "2026-08-30", rules) {
    Some(report) => {
      println("\n>>> SCENARIO 4: INJURED ATHLETE (Severe Pain Reported)")
      println("Report Summary:")
      println(report.summary)
    }
    None => println("Failed to generate report for Injured Athlete.")
  }
}
