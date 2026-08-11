\set ON_ERROR_STOP on
SET application_name = 'telemed_concurrency_a';

BEGIN;

INSERT INTO appointments (
    appointment_id,
    patient_id,
    doctor_id,
    start_ts,
    end_ts,
    status
) VALUES (
    'c0000000-0000-0000-0000-000000000010',
    'c0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000002',
    TIMESTAMPTZ '2099-01-01 10:00:00+00',
    TIMESTAMPTZ '2099-01-01 10:30:00+00',
    'BOOKED'
);

-- The runner polls pg_stat_activity until this exact query is active. The
-- controlled hold then gives Session B time to reach the conflicting insert.
SELECT pg_sleep(8);

COMMIT;
