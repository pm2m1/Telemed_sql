\set ON_ERROR_STOP on
SET application_name = 'telemed_concurrency_b';

BEGIN;

DO $$
DECLARE
    v_caught BOOLEAN := FALSE;
    v_sqlstate TEXT;
BEGIN
    BEGIN
        INSERT INTO appointments (
            appointment_id,
            patient_id,
            doctor_id,
            start_ts,
            end_ts,
            status
        ) VALUES (
            'c0000000-0000-0000-0000-000000000011',
            'c0000000-0000-0000-0000-000000000001',
            'c0000000-0000-0000-0000-000000000002',
            TIMESTAMPTZ '2099-01-01 10:15:00+00',
            TIMESTAMPTZ '2099-01-01 10:45:00+00',
            'BOOKED'
        );
    EXCEPTION
        WHEN exclusion_violation THEN
            GET STACKED DIAGNOSTICS v_sqlstate = RETURNED_SQLSTATE;
            IF v_sqlstate <> '23P01' THEN
                RAISE EXCEPTION
                    'Expected SQLSTATE 23P01, received %', v_sqlstate;
            END IF;
            v_caught := TRUE;
            RAISE NOTICE 'EXPECTED_SQLSTATE=23P01';
    END;

    IF NOT v_caught THEN
        RAISE EXCEPTION
            'Concurrent overlap test failed: Session B insert committed';
    END IF;
END;
$$;

COMMIT;
