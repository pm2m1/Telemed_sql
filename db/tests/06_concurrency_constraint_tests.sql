\set ON_ERROR_STOP on

BEGIN;

-- This verifies the database invariant directly. It is intentionally not
-- described as a multi-session concurrency harness.
DO $$
DECLARE
    v_patient_id UUID;
    v_doctor_one_id UUID;
    v_doctor_two_id UUID;
    v_initial_id UUID;
    v_replacement_id UUID;
    v_other_doctor_id UUID;
    v_adjacent_id UUID;
    v_start TIMESTAMPTZ := date_trunc('hour', CURRENT_TIMESTAMP) + INTERVAL '53 years';
    v_error_seen BOOLEAN := FALSE;
BEGIN
    INSERT INTO patients (first_name, last_name, dob, phone, email)
    VALUES ('Constraint', 'Patient', DATE '1990-01-01', '+910000000051', 'constraint-test@example.invalid')
    RETURNING patient_id INTO v_patient_id;

    INSERT INTO doctors (full_name, specialty)
    VALUES ('Dr. Constraint One', 'Test Medicine')
    RETURNING doctor_id INTO v_doctor_one_id;

    INSERT INTO doctors (full_name, specialty)
    VALUES ('Dr. Constraint Two', 'Test Medicine')
    RETURNING doctor_id INTO v_doctor_two_id;

    INSERT INTO appointments (patient_id, doctor_id, start_ts, end_ts, status)
    VALUES (
        v_patient_id,
        v_doctor_one_id,
        v_start,
        v_start + INTERVAL '1 hour',
        'BOOKED'
    )
    RETURNING appointment_id INTO v_initial_id;

    BEGIN
        INSERT INTO appointments (patient_id, doctor_id, start_ts, end_ts, status)
        VALUES (
            v_patient_id,
            v_doctor_one_id,
            v_start + INTERVAL '30 minutes',
            v_start + INTERVAL '1 hour 30 minutes',
            'BOOKED'
        );
    EXCEPTION
        WHEN exclusion_violation THEN
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Exclusion constraint test failed: direct overlapping BOOKED insert was accepted';
    END IF;

    PERFORM cancel_appointment(v_initial_id);

    INSERT INTO appointments (patient_id, doctor_id, start_ts, end_ts, status)
    VALUES (
        v_patient_id,
        v_doctor_one_id,
        v_start,
        v_start + INTERVAL '1 hour',
        'BOOKED'
    )
    RETURNING appointment_id INTO v_replacement_id;

    INSERT INTO appointments (patient_id, doctor_id, start_ts, end_ts, status)
    VALUES (
        v_patient_id,
        v_doctor_two_id,
        v_start,
        v_start + INTERVAL '1 hour',
        'BOOKED'
    )
    RETURNING appointment_id INTO v_other_doctor_id;

    INSERT INTO appointments (patient_id, doctor_id, start_ts, end_ts, status)
    VALUES (
        v_patient_id,
        v_doctor_one_id,
        v_start + INTERVAL '1 hour',
        v_start + INTERVAL '2 hours',
        'BOOKED'
    )
    RETURNING appointment_id INTO v_adjacent_id;

    IF v_replacement_id IS NULL OR v_other_doctor_id IS NULL OR v_adjacent_id IS NULL THEN
        RAISE EXCEPTION 'Exclusion constraint test failed: an allowed appointment was not created';
    END IF;

    IF (SELECT status FROM appointments WHERE appointment_id = v_initial_id) <> 'CANCELLED' THEN
        RAISE EXCEPTION 'Exclusion constraint test failed: cancelled appointment status was not preserved';
    END IF;

    RAISE NOTICE 'Exclusion constraint invariant tests passed';
END;
$$ LANGUAGE plpgsql;

ROLLBACK;
