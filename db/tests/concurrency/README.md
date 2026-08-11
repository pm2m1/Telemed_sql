# True two-session appointment concurrency test

This harness is separate from `06_concurrency_constraint_tests.sql`:

- `06_concurrency_constraint_tests.sql` verifies range invariants in one session.
- This directory opens two independent `psql` sessions and exercises a race.

## Coordination

Session A begins a transaction, inserts a `BOOKED` appointment, and executes a
controlled eight-second `pg_sleep`. The runner does not guess when to launch
Session B: it polls `pg_stat_activity` until Session A is actively executing
that exact hold query, which proves the uncommitted insert has completed.

Session B then directly inserts an overlapping `BOOKED` row for the same
doctor. PostgreSQL waits on the exclusion conflict. After Session A commits,
Session B receives `exclusion_violation` (`SQLSTATE 23P01`), catches it, and
prints a marker that the runner validates.

The post-race verifier also proves that:

- overlapping times for different doctors are allowed;
- `10:00-10:30` and `10:30-11:00` are adjacent under `[)` ranges;
- a `CANCELLED` row does not block its former slot;
- both conflicting `BOOKED` rows cannot commit.

Fixtures use reserved synthetic UUIDs and are cleaned in success and failure
paths.

PowerShell:

```powershell
./db/tests/concurrency/run_concurrency_test.ps1
```

Bash, WSL, or Git Bash:

```bash
bash ./db/tests/concurrency/run_concurrency_test.sh
```
