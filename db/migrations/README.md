# Versioned database migrations

Flyway is the only authoritative schema-management path. Versioned files in
this directory create a database from zero and apply future upgrades in order.
Do not edit a migration after it has been applied; add a new `V<N>__name.sql`
file instead.

## Clean database

```bash
docker compose up -d postgres
docker compose run --rm flyway migrate
docker compose run --rm flyway info
```

`docker compose up -d` also runs the one-shot Flyway service before pgAdmin.
Development seed data is deliberately separate under `db/seed/`.

## Existing database created by the former `db/init` scripts

The old initialization scripts represented the state through migration V5.
Do not run ordinary `migrate` against such a non-empty database until it has
been baselined once. Use the guarded helper for your shell:

```powershell
./db/migrations/baseline_legacy.ps1
```

```bash
bash ./db/migrations/baseline_legacy.sh
```

The helper checks for the known legacy tables, views, functions, and overlap
constraint; refuses an empty, partially recognized, or already managed schema;
records a V5 baseline; and then applies V6 and later migrations. It never runs
Flyway `clean` and does not delete data.

Before using the helper on important data, take a database backup. A baseline
records existing schema state; it does not prove that manually edited objects
exactly match the historical scripts.
