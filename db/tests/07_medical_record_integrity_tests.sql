\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_patient_a UUID;
    v_patient_b UUID;
    v_doctor_a UUID;
    v_doctor_b UUID;
    v_appointment UUID;
    v_linked_record UUID;
    v_standalone_record UUID;
    v_error_seen BOOLEAN;
BEGIN
    INSERT INTO patients (first_name, last_name, dob, phone, email)
    VALUES ('Integrity', 'Patient A', DATE '1990-01-01', '+910000000071', 'integrity-a@example.invalid')
    RETURNING patient_id INTO v_patient_a;

    INSERT INTO patients (first_name, last_name, dob, phone, email)
    VALUES ('Integrity', 'Patient B', DATE '1991-01-01', '+910000000072', 'integrity-b@example.invalid')
    RETURNING patient_id INTO v_patient_b;

    INSERT INTO doctors (full_name, specialty)
    VALUES ('Dr. Integrity A', 'Test Medicine')
    RETURNING doctor_id INTO v_doctor_a;

    INSERT INTO doctors (full_name, specialty)
    VALUES ('Dr. Integrity B', 'Test Medicine')
    RETURNING doctor_id INTO v_doctor_b;

    INSERT INTO appointments (
        patient_id,
        doctor_id,
        start_ts,
        end_ts,
        status
    ) VALUES (
        v_patient_a,
        v_doctor_a,
        TIMESTAMPTZ '2098-07-01 10:00:00+00',
        TIMESTAMPTZ '2098-07-01 10:30:00+00',
        'BOOKED'
    )
    RETURNING appointment_id INTO v_appointment;

    INSERT INTO medical_records (
        appointment_id,
        patient_id,
        doctor_id,
        diagnosis,
        notes
    ) VALUES (
        v_appointment,
        v_patient_a,
        v_doctor_a,
        'Consistent linked record',
        'Accepted by the composite relationship constraint.'
    )
    RETURNING record_id INTO v_linked_record;

    v_error_seen := FALSE;
    BEGIN
        INSERT INTO medical_records (
            appointment_id, patient_id, doctor_id, diagnosis
        ) VALUES (
            v_appointment, v_patient_b, v_doctor_a, 'Wrong patient'
        );
    EXCEPTION
        WHEN foreign_key_violation THEN
            v_error_seen := TRUE;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Medical-record test failed: mismatched patient was accepted';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        INSERT INTO medical_records (
            appointment_id, patient_id, doctor_id, diagnosis
        ) VALUES (
            v_appointment, v_patient_a, v_doctor_b, 'Wrong doctor'
        );
    EXCEPTION
        WHEN foreign_key_violation THEN
            v_error_seen := TRUE;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Medical-record test failed: mismatched doctor was accepted';
    END IF;

    INSERT INTO medical_records (
        appointment_id,
        patient_id,
        doctor_id,
        diagnosis
    ) VALUES (
        NULL,
        v_patient_b,
        v_doctor_b,
        'Standalone consultation record'
    )
    RETURNING record_id INTO v_standalone_record;

    DELETE FROM appointments WHERE appointment_id = v_appointment;

    IF EXISTS (
        SELECT 1
        FROM medical_records
        WHERE record_id = v_linked_record
          AND (
              appointment_id IS NOT NULL
              OR patient_id <> v_patient_a
              OR doctor_id <> v_doctor_a
          )
    ) THEN
        RAISE EXCEPTION
            'Medical-record test failed: appointment deletion did not clear only appointment_id';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM medical_records
        WHERE record_id = v_standalone_record
          AND appointment_id IS NULL
    ) THEN
        RAISE EXCEPTION 'Medical-record test failed: standalone record was not preserved';
    END IF;

    RAISE NOTICE 'Medical-record relationship consistency tests passed';
END;
$$ LANGUAGE plpgsql;

ROLLBACK;
