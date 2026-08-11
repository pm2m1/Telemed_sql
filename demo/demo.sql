\set ON_ERROR_STOP on
\pset pager off
\echo '=== Telemedicine database workflow demo ==='

BEGIN;
SET LOCAL TIME ZONE 'UTC';

-- Fixed synthetic identities make the script deterministic. Everything below
-- is rolled back, so the development database remains unchanged.
DELETE FROM medical_records
WHERE patient_id = 'd0000000-0000-0000-0000-000000000001';
DELETE FROM payments
WHERE appointment_id IN (
    SELECT appointment_id
    FROM appointments
    WHERE patient_id = 'd0000000-0000-0000-0000-000000000001'
);
DELETE FROM appointments
WHERE patient_id = 'd0000000-0000-0000-0000-000000000001';
DELETE FROM patients
WHERE patient_id = 'd0000000-0000-0000-0000-000000000001';
DELETE FROM doctors
WHERE doctor_id = 'd0000000-0000-0000-0000-000000000002';

INSERT INTO patients (
    patient_id,
    first_name,
    last_name,
    dob,
    phone,
    email
) VALUES (
    'd0000000-0000-0000-0000-000000000001',
    'Demo',
    'Patient',
    DATE '1990-01-01',
    '+91-7999999991',
    'demo.patient@example.invalid'
);

INSERT INTO doctors (doctor_id, full_name, specialty)
VALUES (
    'd0000000-0000-0000-0000-000000000002',
    'Dr. Demo Clinician',
    'Demonstration Medicine'
);

CREATE TEMP TABLE demo_context (
    appointment_id UUID PRIMARY KEY,
    patient_id UUID NOT NULL,
    doctor_id UUID NOT NULL
) ON COMMIT DROP;

DO $$
DECLARE
    v_appointment_id UUID;
    v_start TIMESTAMPTZ := date_trunc('day', CURRENT_TIMESTAMP)
        + INTERVAL '20 years 10 hours';
BEGIN
    v_appointment_id := book_appointment(
        'd0000000-0000-0000-0000-000000000001',
        'd0000000-0000-0000-0000-000000000002',
        v_start,
        v_start + INTERVAL '30 minutes',
        1250.00,
        'UPI'
    );

    INSERT INTO demo_context (appointment_id, patient_id, doctor_id)
    VALUES (
        v_appointment_id,
        'd0000000-0000-0000-0000-000000000001',
        'd0000000-0000-0000-0000-000000000002'
    );
END;
$$;

\echo '\n1. Appointment created by book_appointment()'
SELECT
    a.appointment_id,
    p.first_name || ' ' || p.last_name AS patient,
    d.full_name AS doctor,
    a.start_ts,
    a.end_ts,
    a.status
FROM demo_context c
JOIN appointments a USING (appointment_id)
JOIN patients p ON p.patient_id = a.patient_id
JOIN doctors d ON d.doctor_id = a.doctor_id;

\echo '\n2. Automatically created PENDING payment'
SELECT p.payment_id, p.appointment_id, p.amount_rs, p.method, p.status
FROM demo_context c
JOIN payments p USING (appointment_id);

\echo '\n3. Process payment successfully'
SELECT process_payment(appointment_id, 'SUCCESS') AS payment_processed
FROM demo_context;

SELECT p.payment_id, p.amount_rs, p.method, p.status, p.paid_at
FROM demo_context c
JOIN payments p USING (appointment_id);

\echo '\n4. Complete appointment'
SELECT complete_appointment(appointment_id) AS appointment_completed
FROM demo_context;

SELECT a.appointment_id, a.status, a.updated_at
FROM demo_context c
JOIN appointments a USING (appointment_id);

\echo '\n5. Appointment audit trail'
SELECT al.audit_id, al.action, al.row_id_text, al.changed_at,
       al.before_json ->> 'status' AS before_status,
       al.after_json ->> 'status' AS after_status
FROM demo_context c
JOIN audit_log al ON al.row_id_text = c.appointment_id::TEXT
ORDER BY al.audit_id;

\echo '\n6. Doctor utilization view'
SELECT doctor_id, doctor_name, total_appointments,
       completed_appointments, completion_rate_percent
FROM vw_doctor_utilization
WHERE doctor_id = 'd0000000-0000-0000-0000-000000000002';

\echo '\n7. Revenue per day view'
SELECT payment_date, total_payments, total_revenue, avg_payment_amount
FROM vw_revenue_per_day
WHERE payment_date = CURRENT_DATE;

\echo '\n8. Patient statistics view'
SELECT patient_id, patient_name, total_appointments,
       completed_appointments, total_paid
FROM vw_patient_statistics
WHERE patient_id = 'd0000000-0000-0000-0000-000000000001';

DO $$
DECLARE
    v_appointment_id UUID;
BEGIN
    SELECT appointment_id INTO STRICT v_appointment_id FROM demo_context;

    IF NOT EXISTS (
        SELECT 1
        FROM appointments
        WHERE appointment_id = v_appointment_id
          AND status = 'COMPLETED'
    ) THEN
        RAISE EXCEPTION 'Demo assertion failed: appointment was not completed';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM payments
        WHERE appointment_id = v_appointment_id
          AND status = 'SUCCESS'
          AND paid_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Demo assertion failed: payment was not successful';
    END IF;

    IF (SELECT COUNT(*) FROM audit_log
        WHERE row_id_text = v_appointment_id::TEXT) < 2 THEN
        RAISE EXCEPTION 'Demo assertion failed: audit trail is incomplete';
    END IF;
END;
$$;

ROLLBACK;
\echo '\nDemo passed. Transaction rolled back; no demo rows were retained.'
