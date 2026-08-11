\set ON_ERROR_STOP on

BEGIN;

INSERT INTO patients (
    patient_id, first_name, last_name, dob, phone, email
) VALUES
    ('85000000-0000-4000-8000-000000000001', 'Security', 'Patient A', DATE '1990-01-01', '+910000000081', 'security-a@example.invalid'),
    ('85000000-0000-4000-8000-000000000002', 'Security', 'Patient B', DATE '1991-01-01', '+910000000082', 'security-b@example.invalid');

INSERT INTO doctors (doctor_id, full_name, specialty) VALUES
    ('85000000-0000-4000-8000-000000000011', 'Dr. Security A', 'Test Medicine'),
    ('85000000-0000-4000-8000-000000000012', 'Dr. Security B', 'Test Medicine');

INSERT INTO appointments (
    appointment_id, patient_id, doctor_id, start_ts, end_ts, status
) VALUES
    (
        '85000000-0000-4000-8000-000000000021',
        '85000000-0000-4000-8000-000000000001',
        '85000000-0000-4000-8000-000000000011',
        TIMESTAMPTZ '2098-08-01 10:00:00+00',
        TIMESTAMPTZ '2098-08-01 10:30:00+00',
        'BOOKED'
    ),
    (
        '85000000-0000-4000-8000-000000000022',
        '85000000-0000-4000-8000-000000000002',
        '85000000-0000-4000-8000-000000000012',
        TIMESTAMPTZ '2098-08-01 10:00:00+00',
        TIMESTAMPTZ '2098-08-01 10:30:00+00',
        'BOOKED'
    );

INSERT INTO payments (
    payment_id, appointment_id, amount_rs, method, status
) VALUES
    (
        '85000000-0000-4000-8000-000000000031',
        '85000000-0000-4000-8000-000000000021',
        750.00,
        'UPI',
        'PENDING'
    ),
    (
        '85000000-0000-4000-8000-000000000032',
        '85000000-0000-4000-8000-000000000022',
        900.00,
        'CARD',
        'PENDING'
    );

INSERT INTO medical_records (
    record_id, appointment_id, patient_id, doctor_id, diagnosis
) VALUES
    (
        '85000000-0000-4000-8000-000000000041',
        '85000000-0000-4000-8000-000000000021',
        '85000000-0000-4000-8000-000000000001',
        '85000000-0000-4000-8000-000000000011',
        'Doctor A record'
    ),
    (
        '85000000-0000-4000-8000-000000000042',
        '85000000-0000-4000-8000-000000000022',
        '85000000-0000-4000-8000-000000000002',
        '85000000-0000-4000-8000-000000000012',
        'Doctor B record'
    );

SET LOCAL ROLE telemed_doctor;
SET LOCAL app.current_doctor_id = '85000000-0000-4000-8000-000000000011';

DO $$
DECLARE
    v_count INTEGER;
    v_error_seen BOOLEAN;
BEGIN
    SELECT COUNT(*) INTO v_count FROM appointments;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Doctor RLS test failed: expected 1 appointment, found %', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count FROM medical_records;
    IF v_count <> 1 THEN
        RAISE EXCEPTION 'Doctor RLS test failed: expected 1 record, found %', v_count;
    END IF;

    UPDATE medical_records
    SET notes = 'Doctor A may update own clinical notes'
    WHERE record_id = '85000000-0000-4000-8000-000000000041';

    INSERT INTO medical_records (
        appointment_id, patient_id, doctor_id, diagnosis
    ) VALUES (
        '85000000-0000-4000-8000-000000000021',
        '85000000-0000-4000-8000-000000000001',
        '85000000-0000-4000-8000-000000000011',
        'Doctor A authorized insert'
    );

    v_error_seen := FALSE;
    BEGIN
        INSERT INTO medical_records (
            appointment_id, patient_id, doctor_id, diagnosis
        ) VALUES (
            '85000000-0000-4000-8000-000000000022',
            '85000000-0000-4000-8000-000000000002',
            '85000000-0000-4000-8000-000000000012',
            'Unauthorized Doctor B insert'
        );
    EXCEPTION
        WHEN insufficient_privilege THEN
            v_error_seen := TRUE;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Doctor RLS test failed: cross-doctor insert was accepted';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        PERFORM COUNT(*) FROM payments;
    EXCEPTION
        WHEN insufficient_privilege THEN
            v_error_seen := TRUE;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Doctor privilege test failed: payment access was allowed';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        INSERT INTO appointments (
            patient_id, doctor_id, start_ts, end_ts, status
        ) VALUES (
            '85000000-0000-4000-8000-000000000001',
            '85000000-0000-4000-8000-000000000011',
            TIMESTAMPTZ '2098-08-02 10:00:00+00',
            TIMESTAMPTZ '2098-08-02 10:30:00+00',
            'BOOKED'
        );
    EXCEPTION
        WHEN insufficient_privilege THEN
            v_error_seen := TRUE;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Doctor privilege test failed: direct appointment write was allowed';
    END IF;
END;
$$ LANGUAGE plpgsql;

RESET ROLE;

SET LOCAL ROLE telemed_billing;
DO $$
DECLARE
    v_count INTEGER;
    v_error_seen BOOLEAN;
BEGIN
    SELECT COUNT(*) INTO v_count FROM payments;
    IF v_count <> 2 THEN
        RAISE EXCEPTION 'Billing test failed: expected payment read access';
    END IF;

    PERFORM process_payment(
        '85000000-0000-4000-8000-000000000021',
        'SUCCESS'
    );

    v_error_seen := FALSE;
    BEGIN
        UPDATE payments
        SET amount_rs = 1
        WHERE payment_id = '85000000-0000-4000-8000-000000000032';
    EXCEPTION
        WHEN insufficient_privilege THEN
            v_error_seen := TRUE;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Billing test failed: direct payment update was allowed';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        PERFORM COUNT(*) FROM medical_records;
    EXCEPTION
        WHEN insufficient_privilege THEN
            v_error_seen := TRUE;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Billing test failed: clinical-record access was allowed';
    END IF;
END;
$$ LANGUAGE plpgsql;
RESET ROLE;

SET LOCAL ROLE telemed_analyst;
DO $$
DECLARE
    v_error_seen BOOLEAN;
BEGIN
    PERFORM COUNT(*) FROM vw_doctor_utilization;
    PERFORM COUNT(*) FROM vw_revenue_per_day;

    v_error_seen := FALSE;
    BEGIN
        PERFORM COUNT(*) FROM patients;
    EXCEPTION
        WHEN insufficient_privilege THEN
            v_error_seen := TRUE;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Analyst test failed: transactional patient access was allowed';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        PERFORM COUNT(*) FROM vw_patient_statistics;
    EXCEPTION
        WHEN insufficient_privilege THEN
            v_error_seen := TRUE;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Analyst test failed: patient-detail view access was allowed';
    END IF;
END;
$$ LANGUAGE plpgsql;
RESET ROLE;

SET LOCAL ROLE telemed_app;
DO $$
DECLARE
    v_appointment UUID;
    v_error_seen BOOLEAN;
BEGIN
    SELECT book_appointment(
        '85000000-0000-4000-8000-000000000001',
        '85000000-0000-4000-8000-000000000011',
        TIMESTAMPTZ '2098-08-03 10:00:00+00',
        TIMESTAMPTZ '2098-08-03 10:30:00+00',
        600.00,
        'CASH'
    ) INTO v_appointment;

    IF v_appointment IS NULL THEN
        RAISE EXCEPTION 'Application role test failed: workflow returned NULL';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        INSERT INTO appointments (
            patient_id, doctor_id, start_ts, end_ts, status
        ) VALUES (
            '85000000-0000-4000-8000-000000000001',
            '85000000-0000-4000-8000-000000000011',
            TIMESTAMPTZ '2098-08-04 10:00:00+00',
            TIMESTAMPTZ '2098-08-04 10:30:00+00',
            'BOOKED'
        );
    EXCEPTION
        WHEN insufficient_privilege THEN
            v_error_seen := TRUE;
    END;
    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Application role test failed: direct write was allowed';
    END IF;
END;
$$ LANGUAGE plpgsql;
RESET ROLE;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_class
        WHERE oid = 'public.appointments'::regclass
          AND relrowsecurity
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_class
        WHERE oid = 'public.medical_records'::regclass
          AND relrowsecurity
    ) THEN
        RAISE EXCEPTION 'Security test failed: expected RLS is not enabled';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname IN (
            'telemed_owner',
            'telemed_admin',
            'telemed_app',
            'telemed_doctor',
            'telemed_billing',
            'telemed_analyst'
        )
          AND rolcanlogin
    ) THEN
        RAISE EXCEPTION 'Security test failed: a group role has LOGIN';
    END IF;

    IF (SELECT status FROM payments WHERE appointment_id = '85000000-0000-4000-8000-000000000021') <> 'SUCCESS' THEN
        RAISE EXCEPTION 'Security test failed: billing workflow result was not persisted in the transaction';
    END IF;

    RAISE NOTICE 'Role, least-privilege, workflow, and row-level security tests passed';
END;
$$ LANGUAGE plpgsql;

ROLLBACK;
