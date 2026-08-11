# Screenshot capture guide

This directory intentionally contains no fabricated screenshots. Useful real
portfolio captures can be created after running the project locally:

1. Flyway `info` showing successful V1-V7 migrations.
2. The terminal demo showing booking, payment, completion, audit, and views.
3. pgAdmin's schema browser showing tables, functions, policies, and views.
4. The GitHub Actions run with database and API jobs passing.
5. One representative `EXPLAIN (ANALYZE, BUFFERS)` benchmark plan.

Before publishing a capture, remove passwords, connection strings, local user
paths, container identifiers, and any non-synthetic data. Record the command,
PostgreSQL version, and date beside benchmark screenshots so the context is
not misleading.
