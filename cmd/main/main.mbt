///|
fn main {
  let args = @env.args()
  if args.contains("--bench") {
    println(@lib.benchmark_result_text(@lib.run_benchmark(100, 120)))
    return
  }
  let json = args.contains("--json")
  println("==================================================")
  println("  MOONBIT INJURY RISK RULE ENGINE DEMO")
  println("==================================================")

  // 1. Healthy Athlete
  let healthy_records = @lib.generate_healthy_athlete()
  match
    @lib.assess_comprehensive(
      healthy_records,
      "2026-08-30",
      @lib.default_risk_policy(),
    ) {
    Some(report) => {
      println(
        "\n>>> SCENARIO 1: HEALTHY ATHLETE (Balanced Workload & Recovery)",
      )
      println("Report Summary:")
      if json {
        println(@json.to_json(report).stringify())
      } else {
        println(report.summary)
      }
    }
    None => println("Failed to generate report for Healthy Athlete.")
  }

  // 2. Workload Spike Athlete
  let spike_records = @lib.generate_workload_spike_athlete()
  match
    @lib.assess_comprehensive(
      spike_records,
      "2026-08-30",
      @lib.default_risk_policy(),
    ) {
    Some(report) => {
      println("\n>>> SCENARIO 2: WORKLOAD SPIKE ATHLETE (ACWR > 1.5)")
      println("Report Summary:")
      if json {
        println(@json.to_json(report).stringify())
      } else {
        println(report.summary)
      }
    }
    None => println("Failed to generate report for Workload Spike Athlete.")
  }

  // 3. Overtired Athlete
  let overtired_records = @lib.generate_overtired_athlete()
  match
    @lib.assess_comprehensive(
      overtired_records,
      "2026-08-30",
      @lib.default_risk_policy(),
    ) {
    Some(report) => {
      println(
        "\n>>> SCENARIO 3: OVERTIRED ATHLETE (Sleep Deprived & High Fatigue)",
      )
      println("Report Summary:")
      if json {
        println(@json.to_json(report).stringify())
      } else {
        println(report.summary)
      }
    }
    None => println("Failed to generate report for Overtired Athlete.")
  }

  // 4. Injured Athlete
  let injured_records = @lib.generate_injured_athlete()
  match
    @lib.assess_comprehensive(
      injured_records,
      "2026-08-30",
      @lib.default_risk_policy(),
    ) {
    Some(report) => {
      println("\n>>> SCENARIO 4: INJURED ATHLETE (Severe Pain Reported)")
      println("Report Summary:")
      if json {
        println(@json.to_json(report).stringify())
      } else {
        println(report.summary)
      }
    }
    None => println("Failed to generate report for Injured Athlete.")
  }
}
