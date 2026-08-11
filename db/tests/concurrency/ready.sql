\set ON_ERROR_STOP on
\set QUIET 1
\pset format unaligned
\pset tuples_only on
\set QUIET 0
SELECT EXISTS (
    SELECT 1
    FROM pg_stat_activity
    WHERE application_name = 'telemed_concurrency_a'
      AND state = 'active'
      AND query LIKE '%pg_sleep(8)%'
);
