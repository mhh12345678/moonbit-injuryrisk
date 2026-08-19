# Injury Risk Benchmarks

This benchmark is deterministic and runs entirely from generated in-memory
telemetry. It creates a 120-day progressive workload, executes 100 complete
latest-assessment passes, and reports a checksum over the resulting scores.
The checksum makes the result useful as a regression signal in addition to a
wall-clock measurement.

## Command

```bash
moon run --target native --release cmd/bench
```

Expected deterministic output:

```text
iterations=100 records=120 assessments=100 high_risk=100 checksum=9326.41248108302
```

## Local Measurement

Measured on Windows in the local development environment on 2026-08-19 with
MoonBit stable `0.1.20260807`, Moonc `0.10.7`, and a warm native release
build. Each measurement used PowerShell `Measure-Command` around the command
above, so it includes the process invocation and cached release-build check.

| Run | Wall time |
| ---: | ---: |
| 1 | 401.24 ms |
| 2 | 381.28 ms |
| 3 | 389.06 ms |
| 4 | 401.56 ms |
| 5 | 457.48 ms |
| Median | 401.24 ms |
| Mean | 406.12 ms |

The values are intended for regression comparison on the same or a similar
machine. They are not a claim about clinical accuracy or a universal hardware
throughput limit.

## Test Snapshot

On the same date and toolchain, the native suite passed 22 of 22 test groups.
The coverage report recorded 1,904 covered lines out of 3,821 instrumented
MoonBit lines (49.83%).
