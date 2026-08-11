\set ON_ERROR_STOP on

-- Optional, idempotent development data. This file is deliberately outside
-- Flyway migrations so production schema upgrades never insert demo records.

INSERT INTO doctors (doctor_id, full_name, specialty) VALUES
    ('10000000-0000-0000-0000-000000000001', 'Dr. Sarah Johnson', 'Cardiology'),
    ('10000000-0000-0000-0000-000000000002', 'Dr. Michael Chen', 'Dermatology'),
    ('10000000-0000-0000-0000-000000000003', 'Dr. Emily Rodriguez', 'Pediatrics'),
    ('10000000-0000-0000-0000-000000000004', 'Dr. David Kumar', 'Orthopedics'),
    ('10000000-0000-0000-0000-000000000005', 'Dr. Lisa Wang', 'Neurology')
ON CONFLICT (doctor_id) DO UPDATE
SET full_name = EXCLUDED.full_name,
    specialty = EXCLUDED.specialty;

INSERT INTO patients (
    patient_id,
    first_name,
    last_name,
    dob,
    phone,
    email
) VALUES
    ('20000000-0000-0000-0000-000000000001', 'John', 'Smith', '1985-03-15', '+91-7000000001', 'seed.john@example.invalid'),
    ('20000000-0000-0000-0000-000000000002', 'Jane', 'Doe', '1990-07-22', '+91-7000000002', 'seed.jane@example.invalid'),
    ('20000000-0000-0000-0000-000000000003', 'Robert', 'Johnson', '1978-11-08', '+91-7000000003', 'seed.robert@example.invalid'),
    ('20000000-0000-0000-0000-000000000004', 'Maria', 'Garcia', '1992-05-14', '+91-7000000004', 'seed.maria@example.invalid'),
    ('20000000-0000-0000-0000-000000000005', 'Ahmed', 'Hassan', '1988-09-30', '+91-7000000005', 'seed.ahmed@example.invalid'),
    ('20000000-0000-0000-0000-000000000006', 'Priya', 'Patel', '1995-12-03', '+91-7000000006', 'seed.priya@example.invalid'),
    ('20000000-0000-0000-0000-000000000007', 'James', 'Wilson', '1983-01-18', '+91-7000000007', 'seed.james@example.invalid'),
    ('20000000-0000-0000-0000-000000000008', 'Sofia', 'Martinez', '1991-08-25', '+91-7000000008', 'seed.sofia@example.invalid')
ON CONFLICT (patient_id) DO UPDATE
SET first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    dob = EXCLUDED.dob,
    phone = EXCLUDED.phone,
    email = EXCLUDED.email;

DO $$
DECLARE
    v_start TIMESTAMPTZ := date_trunc('day', CURRENT_TIMESTAMP)
        + INTERVAL '30 days 9 hours';
    v_completed UUID;
    v_cancelled UUID;
    v_appointment UUID;
BEGIN
    -- A single marker patient makes reruns deterministic without relying on
    -- relative timestamps to identify previously seeded appointments.
    IF EXISTS (
        SELECT 1
        FROM appointments
        WHERE patient_id = '20000000-0000-0000-0000-000000000001'
          AND doctor_id IN (
              '10000000-0000-0000-0000-000000000001',
              '10000000-0000-0000-0000-000000000004'
          )
    ) THEN
        RAISE NOTICE 'Development appointments already exist; workflow seed skipped';
        RETURN;
    END IF;

    v_completed := book_appointment(
        '20000000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000001',
        v_start,
        v_start + INTERVAL '30 minutes',
        1500.00,
        'UPI'
    );
    PERFORM process_payment(v_completed, 'SUCCESS');
    PERFORM complete_appointment(v_completed);

    v_cancelled := book_appointment(
        '20000000-0000-0000-0000-000000000002',
        '10000000-0000-0000-0000-000000000002',
        v_start + INTERVAL '1 day',
        v_start + INTERVAL '1 day 30 minutes',
        1200.00,
        'CARD'
    );
    PERFORM cancel_appointment(v_cancelled);

    v_appointment := book_appointment(
        '20000000-0000-0000-0000-000000000003',
        '10000000-0000-0000-0000-000000000003',
        v_start + INTERVAL '2 days',
        v_start + INTERVAL '2 days 45 minutes',
        1000.00,
        'CASH'
    );

    v_appointment := book_appointment(
        '20000000-0000-0000-0000-000000000004',
        '10000000-0000-0000-0000-000000000004',
        v_start + INTERVAL '3 days',
        v_start + INTERVAL '3 days 1 hour',
        2000.00,
        'WALLET'
    );

    INSERT INTO medical_records (
        appointment_id,
        patient_id,
        doctor_id,
        diagnosis,
        notes
    ) VALUES (
        v_completed,
        '20000000-0000-0000-0000-000000000001',
        '10000000-0000-0000-0000-000000000001',
        'Synthetic development diagnosis',
        'Non-clinical fixture used only for local development.'
    );
END;
$$;

SELECT 'doctors' AS entity, COUNT(*) AS row_count FROM doctors
UNION ALL
SELECT 'patients', COUNT(*) FROM patients
UNION ALL
SELECT 'appointments', COUNT(*) FROM appointments
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'medical_records', COUNT(*) FROM medical_records
ORDER BY entity;
