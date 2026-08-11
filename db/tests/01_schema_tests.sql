\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_name TEXT;
    v_patient_id UUID;
    v_expected_tables TEXT[] := ARRAY[
        'patients',
        'doctors',
        'appointments',
        'medical_records',
        'payments',
        'audit_log'
    ];
    v_expected_foreign_keys TEXT[] := ARRAY[
        'fk_appointments_patient',
        'fk_appointments_doctor',
        'fk_medical_records_appointment_identity',
        'fk_medical_records_patient',
        'fk_medical_records_doctor',
        'fk_payments_appointment'
    ];
    v_expected_extensions TEXT[] := ARRAY[
        'uuid-ossp',
        'pg_trgm',
        'btree_gist'
    ];
    v_error_seen BOOLEAN;
BEGIN
    FOREACH v_name IN ARRAY v_expected_tables LOOP
        IF to_regclass('public.' || v_name) IS NULL THEN
            RAISE EXCEPTION 'Schema test failed: expected table public.% does not exist', v_name;
        END IF;
    END LOOP;

    FOREACH v_name IN ARRAY v_expected_foreign_keys LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_constraint
            WHERE conname = v_name
              AND contype = 'f'
        ) THEN
            RAISE EXCEPTION 'Schema test failed: expected foreign key % does not exist', v_name;
        END IF;
    END LOOP;

    FOREACH v_name IN ARRAY ARRAY['uk_patients_email', 'uk_patients_phone'] LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_constraint
            WHERE conrelid = 'public.patients'::regclass
              AND conname = v_name
              AND contype = 'u'
        ) THEN
            RAISE EXCEPTION 'Schema test failed: expected patient unique constraint % does not exist', v_name;
        END IF;
    END LOOP;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.appointments'::regclass
          AND conname = 'excl_appointments_booked_doctor_time'
          AND contype = 'x'
    ) THEN
        RAISE EXCEPTION 'Schema test failed: booked appointment exclusion constraint does not exist';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND tablename = 'appointments'
          AND indexname = 'idx_appointments_booked_doctor_start'
    ) THEN
        RAISE EXCEPTION 'Schema test failed: BOOKED doctor/start partial index does not exist';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_indexes
        WHERE schemaname = 'public'
          AND indexdef ~* '(now\s*\(|current_timestamp|clock_timestamp\s*\()'
    ) THEN
        RAISE EXCEPTION 'Schema test failed: an index definition contains a volatile clock expression';
    END IF;

    FOREACH v_name IN ARRAY v_expected_extensions LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = v_name) THEN
            RAISE EXCEPTION 'Schema test failed: required extension % is not installed', v_name;
        END IF;
    END LOOP;

    INSERT INTO patients (first_name, last_name, dob, phone, email)
    VALUES ('Schema', 'Unique', DATE '1990-01-01', '+910000000001', 'schema-unique@example.invalid')
    RETURNING patient_id INTO v_patient_id;

    v_error_seen := FALSE;
    BEGIN
        INSERT INTO patients (first_name, last_name, dob, phone, email)
        VALUES ('Duplicate', 'Email', DATE '1991-01-01', '+910000000002', 'schema-unique@example.invalid');
    EXCEPTION
        WHEN unique_violation THEN
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Patient uniqueness test failed: duplicate email was accepted';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        INSERT INTO patients (first_name, last_name, dob, phone, email)
        VALUES ('Duplicate', 'Phone', DATE '1992-01-01', '+910000000001', 'schema-phone@example.invalid');
    EXCEPTION
        WHEN unique_violation THEN
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Patient uniqueness test failed: duplicate phone was accepted';
    END IF;

    RAISE NOTICE 'Schema, extension, foreign-key, exclusion, and patient uniqueness tests passed';
END;
$$ LANGUAGE plpgsql;

ROLLBACK;
