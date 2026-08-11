\set ON_ERROR_STOP on

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM appointments
        WHERE appointment_id = 'c0000000-0000-0000-0000-000000000010'
          AND status = 'BOOKED'
    ) THEN
        RAISE EXCEPTION 'Session A appointment did not commit';
    END IF;

    IF EXISTS (
        SELECT 1 FROM appointments
        WHERE appointment_id = 'c0000000-0000-0000-0000-000000000011'
    ) THEN
        RAISE EXCEPTION 'Conflicting Session B appointment also committed';
    END IF;
END;
$$;

-- Different doctors may overlap.
INSERT INTO appointments (
    appointment_id, patient_id, doctor_id, start_ts, end_ts, status
) VALUES (
    'c0000000-0000-0000-0000-000000000012',
    'c0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000003',
    TIMESTAMPTZ '2099-01-01 10:00:00+00',
    TIMESTAMPTZ '2099-01-01 10:30:00+00',
    'BOOKED'
);

-- Half-open ranges permit adjacency.
INSERT INTO appointments (
    appointment_id, patient_id, doctor_id, start_ts, end_ts, status
) VALUES (
    'c0000000-0000-0000-0000-000000000013',
    'c0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000002',
    TIMESTAMPTZ '2099-01-01 10:30:00+00',
    TIMESTAMPTZ '2099-01-01 11:00:00+00',
    'BOOKED'
);

-- A cancelled row releases its range.
UPDATE appointments
SET status = 'CANCELLED'
WHERE appointment_id = 'c0000000-0000-0000-0000-000000000010';

INSERT INTO appointments (
    appointment_id, patient_id, doctor_id, start_ts, end_ts, status
) VALUES (
    'c0000000-0000-0000-0000-000000000014',
    'c0000000-0000-0000-0000-000000000001',
    'c0000000-0000-0000-0000-000000000002',
    TIMESTAMPTZ '2099-01-01 10:00:00+00',
    TIMESTAMPTZ '2099-01-01 10:30:00+00',
    'BOOKED'
);

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM appointments WHERE appointment_id IN (
        'c0000000-0000-0000-0000-000000000012',
        'c0000000-0000-0000-0000-000000000013',
        'c0000000-0000-0000-0000-000000000014'
    )) <> 3 THEN
        RAISE EXCEPTION 'Allowed overlap/adjacency/cancellation cases failed';
    END IF;
END;
$$;

ROLLBACK;
\echo 'True two-session concurrency and range-invariant checks passed.'
