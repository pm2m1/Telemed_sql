\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_patient_id UUID;
    v_doctor_id UUID;
    v_appointment_id UUID;
    v_original_updated_at TIMESTAMPTZ;
    v_new_updated_at TIMESTAMPTZ;
    v_start TIMESTAMPTZ := date_trunc('hour', CURRENT_TIMESTAMP) + INTERVAL '52 years';
    v_error_seen BOOLEAN;
BEGIN
    INSERT INTO patients (first_name, last_name, dob, phone, email)
    VALUES ('Trigger', 'Patient', DATE '1990-01-01', '+910000000031', 'trigger-test@example.invalid')
    RETURNING patient_id INTO v_patient_id;

    INSERT INTO doctors (full_name, specialty)
    VALUES ('Dr. Trigger Test', 'Test Medicine')
    RETURNING doctor_id INTO v_doctor_id;

    INSERT INTO appointments (patient_id, doctor_id, start_ts, end_ts, status)
    VALUES (v_patient_id, v_doctor_id, v_start, v_start + INTERVAL '30 minutes', 'BOOKED')
    RETURNING appointment_id, updated_at
    INTO v_appointment_id, v_original_updated_at;

    IF NOT EXISTS (
        SELECT 1
        FROM audit_log
        WHERE table_name = 'appointments'
          AND action = 'INSERT'
          AND row_id_text = v_appointment_id::TEXT
          AND before_json IS NULL
          AND after_json ->> 'appointment_id' = v_appointment_id::TEXT
          AND after_json ->> 'status' = 'BOOKED'
    ) THEN
        RAISE EXCEPTION 'Trigger test failed: INSERT audit row is missing or malformed';
    END IF;

    PERFORM pg_sleep(0.01);

    UPDATE appointments
    SET status = 'CANCELLED'
    WHERE appointment_id = v_appointment_id
    RETURNING updated_at INTO v_new_updated_at;

    IF v_new_updated_at <= v_original_updated_at THEN
        RAISE EXCEPTION 'Trigger test failed: updated_at did not advance after UPDATE';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM audit_log
        WHERE table_name = 'appointments'
          AND action = 'UPDATE'
          AND row_id_text = v_appointment_id::TEXT
          AND before_json ->> 'status' = 'BOOKED'
          AND after_json ->> 'status' = 'CANCELLED'
    ) THEN
        RAISE EXCEPTION 'Trigger test failed: UPDATE audit row is missing or malformed';
    END IF;

    DELETE FROM appointments
    WHERE appointment_id = v_appointment_id;

    IF NOT EXISTS (
        SELECT 1
        FROM audit_log
        WHERE table_name = 'appointments'
          AND action = 'DELETE'
          AND row_id_text = v_appointment_id::TEXT
          AND before_json ->> 'status' = 'CANCELLED'
          AND after_json IS NULL
    ) THEN
        RAISE EXCEPTION 'Trigger test failed: DELETE audit row is missing or malformed';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        INSERT INTO appointments (patient_id, doctor_id, start_ts, end_ts, status)
        VALUES (
            v_patient_id,
            v_doctor_id,
            CURRENT_TIMESTAMP - INTERVAL '2 hours',
            CURRENT_TIMESTAMP - INTERVAL '1 hour',
            'BOOKED'
        );
    EXCEPTION
        WHEN OTHERS THEN
            IF position('Cannot create or reschedule an appointment in the past' IN SQLERRM) = 0 THEN
                RAISE;
            END IF;
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Trigger test failed: direct creation of a past appointment was accepted';
    END IF;

    RAISE NOTICE 'Appointment audit, updated_at, and past-time trigger tests passed';
END;
$$ LANGUAGE plpgsql;

ROLLBACK;
