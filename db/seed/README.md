# Development seed

`development_seed.sql` contains synthetic, idempotent local-development data.
It is not a Flyway migration and is never applied by normal CI or production
schema upgrades.

After migrations finish, run it explicitly:

```bash
docker compose --profile seed run --rm seed
```

PowerShell uses the same command. The fixed UUIDs and marker check make reruns
safe. Changing seed data does not alter Flyway checksums or production schema
history.
