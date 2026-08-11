\set ON_ERROR_STOP on
\pset pager off
\timing on

SELECT version() AS postgres_version;
SELECT
    COUNT(*) AS doctors,
    (SELECT COUNT(*) FROM patients) AS patients,
    (SELECT COUNT(*) FROM appointments) AS appointments,
    (SELECT COUNT(*) FROM payments) AS payments
FROM doctors;

\echo 'Q1: upcoming BOOKED appointments for one doctor'
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT appointment_id, patient_id, start_ts, end_ts
FROM appointments
WHERE doctor_id = uuid_generate_v5(
        '70d5abf8-9cd8-4b85-9e92-8f21cbcf66ac'::UUID,
        'doctor-10'
    )
  AND status = 'BOOKED'
  AND start_ts > CURRENT_TIMESTAMP
ORDER BY start_ts
LIMIT 25;

\echo 'Q2a: patient history with its supporting index temporarily absent'
BEGIN;
DROP INDEX idx_appointments_patient_start;
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT appointment_id, doctor_id, start_ts, status
FROM appointments
WHERE patient_id = uuid_generate_v5(
        '70d5abf8-9cd8-4b85-9e92-8f21cbcf66ac'::UUID,
        'patient-1'
    )
ORDER BY start_ts DESC;
ROLLBACK;

\echo 'Q2b: patient history with idx_appointments_patient_start restored'
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT appointment_id, doctor_id, start_ts, status
FROM appointments
WHERE patient_id = uuid_generate_v5(
        '70d5abf8-9cd8-4b85-9e92-8f21cbcf66ac'::UUID,
        'patient-1'
    )
ORDER BY start_ts DESC;

\echo 'Q3: successful-payment aggregation by paid date'
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT DATE(paid_at) AS payment_date, SUM(amount_rs) AS revenue
FROM payments
WHERE status = 'SUCCESS'
  AND paid_at >= CURRENT_TIMESTAMP - INTERVAL '90 days'
GROUP BY DATE(paid_at)
ORDER BY payment_date DESC;

\echo 'Q4: recent appointment audit history'
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT audit_id, action, row_id_text, changed_at
FROM audit_log
WHERE table_name = 'appointments'
ORDER BY changed_at DESC
LIMIT 100;

\echo 'Q5: trigram-assisted fuzzy patient-name search'
EXPLAIN (ANALYZE, BUFFERS, SETTINGS)
SELECT patient_id, first_name, last_name
FROM patients
WHERE (first_name || ' ' || last_name) % 'Patient000042 Benchmark'
ORDER BY similarity(
    first_name || ' ' || last_name,
    'Patient000042 Benchmark'
) DESC
LIMIT 20;
