\set ON_ERROR_STOP on

\if :{?doctor_count}
\else
\set doctor_count 1000
\endif
\if :{?patient_count}
\else
\set patient_count 20000
\endif
\if :{?appointment_count}
\else
\set appointment_count 100000
\endif

DO $$
BEGIN
    IF current_database() !~ '_benchmark$' THEN
        RAISE EXCEPTION
            'Refusing benchmark data generation outside a *_benchmark database';
    END IF;
END;
$$;

CREATE TEMP TABLE benchmark_config AS
SELECT
    :doctor_count::INTEGER AS doctor_count,
    :patient_count::INTEGER AS patient_count,
    :appointment_count::INTEGER AS appointment_count,
    '70d5abf8-9cd8-4b85-9e92-8f21cbcf66ac'::UUID AS namespace_id;

DO $$
DECLARE
    v_config benchmark_config%ROWTYPE;
BEGIN
    SELECT * INTO v_config FROM benchmark_config;

    IF v_config.doctor_count NOT BETWEEN 1 AND 10000
       OR v_config.patient_count NOT BETWEEN 1 AND 200000
       OR v_config.appointment_count NOT BETWEEN 1 AND 1000000 THEN
        RAISE EXCEPTION
            'Benchmark sizes exceed guarded ranges (doctors 1-10000, patients 1-200000, appointments 1-1000000)';
    END IF;
END;
$$;

TRUNCATE TABLE
    medical_records,
    payments,
    appointments,
    audit_log,
    patients,
    doctors
RESTART IDENTITY CASCADE;

INSERT INTO doctors (doctor_id, full_name, specialty)
SELECT
    uuid_generate_v5(c.namespace_id, 'doctor-' || n),
    'Benchmark Doctor ' || lpad(n::TEXT, 5, '0'),
    (ARRAY[
        'Cardiology',
        'Dermatology',
        'Neurology',
        'Orthopedics',
        'Pediatrics'
    ])[1 + ((n - 1) % 5)]
FROM benchmark_config c
CROSS JOIN generate_series(1, c.doctor_count) AS series(n);

INSERT INTO patients (
    patient_id,
    first_name,
    last_name,
    dob,
    phone,
    email
)
SELECT
    uuid_generate_v5(c.namespace_id, 'patient-' || n),
    'Patient' || lpad(n::TEXT, 6, '0'),
    'Benchmark',
    DATE '1950-01-01' + ((n * 17) % 20000),
    '+91B' || lpad(n::TEXT, 12, '0'),
    'benchmark.patient.' || n || '@example.invalid'
FROM benchmark_config c
CROSS JOIN generate_series(1, c.patient_count) AS series(n);

WITH generated AS (
    SELECT
        n,
        c.doctor_count,
        c.patient_count,
        c.namespace_id,
        1 + ((n - 1) % c.doctor_count) AS doctor_number,
        1 + ((n - 1) % c.patient_count) AS patient_number,
        ((n - 1) / c.doctor_count) AS doctor_slot
    FROM benchmark_config c
    CROSS JOIN generate_series(1, c.appointment_count) AS series(n)
)
INSERT INTO appointments (
    appointment_id,
    patient_id,
    doctor_id,
    start_ts,
    end_ts,
    status,
    created_at,
    updated_at
)
SELECT
    uuid_generate_v5(namespace_id, 'appointment-' || n),
    uuid_generate_v5(namespace_id, 'patient-' || patient_number),
    uuid_generate_v5(namespace_id, 'doctor-' || doctor_number),
    date_trunc('day', CURRENT_TIMESTAMP) + INTERVAL '30 days'
        + doctor_slot * INTERVAL '45 minutes',
    date_trunc('day', CURRENT_TIMESTAMP) + INTERVAL '30 days'
        + doctor_slot * INTERVAL '45 minutes' + INTERVAL '30 minutes',
    CASE
        WHEN n % 10 = 0 THEN 'BOOKED'
        WHEN n % 4 = 0 THEN 'CANCELLED'
        ELSE 'COMPLETED'
    END,
    CURRENT_TIMESTAMP - ((n % 365) * INTERVAL '1 day'),
    CURRENT_TIMESTAMP - ((n % 30) * INTERVAL '1 day')
FROM generated;

INSERT INTO payments (
    payment_id,
    appointment_id,
    amount_rs,
    method,
    status,
    paid_at,
    created_at,
    updated_at
)
SELECT
    uuid_generate_v5(c.namespace_id, 'payment-' || n),
    uuid_generate_v5(c.namespace_id, 'appointment-' || n),
    (300 + (n % 20) * 75)::NUMERIC(10,2),
    (ARRAY['CASH', 'UPI', 'CARD', 'WALLET'])[1 + ((n - 1) % 4)],
    CASE
        WHEN n % 10 = 0 THEN 'PENDING'
        WHEN n % 4 = 0 THEN 'FAILED'
        ELSE 'SUCCESS'
    END,
    CASE
        WHEN n % 10 <> 0 AND n % 4 <> 0
            THEN CURRENT_TIMESTAMP - ((n % 365) * INTERVAL '1 day')
        ELSE NULL
    END,
    CURRENT_TIMESTAMP - ((n % 365) * INTERVAL '1 day'),
    CURRENT_TIMESTAMP - ((n % 30) * INTERVAL '1 day')
FROM benchmark_config c
CROSS JOIN generate_series(1, c.appointment_count) AS series(n);

ANALYZE patients;
ANALYZE doctors;
ANALYZE appointments;
ANALYZE payments;
ANALYZE audit_log;

SELECT
    (SELECT COUNT(*) FROM doctors) AS doctors,
    (SELECT COUNT(*) FROM patients) AS patients,
    (SELECT COUNT(*) FROM appointments) AS appointments,
    (SELECT COUNT(*) FROM payments) AS payments,
    (SELECT COUNT(*) FROM audit_log) AS audit_rows;
