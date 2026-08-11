# Reproducible query-plan benchmark

This benchmark creates an isolated Docker Compose project named
`telemed_benchmark`, migrates a dedicated `telemed_benchmark` database,
generates synthetic rows with `generate_series()`, captures PostgreSQL query
plans, and removes its containers and volume. It does not use the development
database.

Default dataset:

- 1,000 doctors
- 20,000 patients
- 100,000 appointments
- 100,000 payments

Run on PowerShell:

```powershell
./benchmarks/run_benchmark.ps1
```

Run on Bash/WSL/Linux:

```bash
bash ./benchmarks/run_benchmark.sh
```

Use smaller data for a quick tooling check:

```powershell
./benchmarks/run_benchmark.ps1 -Doctors 25 -Patients 200 -Appointments 1000
```

```bash
BENCHMARK_DOCTORS=25 BENCHMARK_PATIENTS=200 \
  BENCHMARK_APPOINTMENTS=1000 bash ./benchmarks/run_benchmark.sh
```

Raw output is written to ignored `benchmarks/results/latest.txt`. The queries
cover an upcoming doctor schedule, patient history, successful-payment
aggregation, recent audit history, and fuzzy patient-name search. The patient
history query is also explained after temporarily dropping its supporting
index inside a transaction; `ROLLBACK` restores the index before the indexed
plan is measured.

`EXPLAIN (ANALYZE, BUFFERS)` values depend on hardware, Docker resources,
PostgreSQL cache state, and dataset size. This repository does not commit or
advertise machine-specific speedup claims.
