-- Live analytical views over the transactional schema.

CREATE OR REPLACE VIEW vw_daily_appointments_per_doctor AS
SELECT
    DATE(a.start_ts) AS appointment_date,
    d.doctor_id,
    d.full_name AS doctor_name,
    d.specialty,
    COUNT(*) AS total_appointments,
    COUNT(*) FILTER (WHERE a.status = 'BOOKED') AS booked_count,
    COUNT(*) FILTER (WHERE a.status = 'COMPLETED') AS completed_count,
    COUNT(*) FILTER (WHERE a.status = 'CANCELLED') AS cancelled_count
FROM appointments a
JOIN doctors d ON a.doctor_id = d.doctor_id
GROUP BY DATE(a.start_ts), d.doctor_id, d.full_name, d.specialty;

CREATE OR REPLACE VIEW vw_revenue_per_day AS
SELECT
    DATE(p.paid_at) AS payment_date,
    COUNT(*) AS total_payments,
    SUM(p.amount_rs) AS total_revenue,
    AVG(p.amount_rs) AS avg_payment_amount,
    COUNT(*) FILTER (WHERE p.method = 'UPI') AS upi_count,
    COUNT(*) FILTER (WHERE p.method = 'CARD') AS card_count,
    COUNT(*) FILTER (WHERE p.method = 'CASH') AS cash_count,
    COUNT(*) FILTER (WHERE p.method = 'WALLET') AS wallet_count
FROM payments p
WHERE p.status = 'SUCCESS'
  AND p.paid_at IS NOT NULL
GROUP BY DATE(p.paid_at);

CREATE OR REPLACE VIEW vw_doctor_utilization AS
SELECT
    d.doctor_id,
    d.full_name AS doctor_name,
    d.specialty,
    COUNT(a.appointment_id) AS total_appointments,
    COUNT(a.appointment_id) FILTER (
        WHERE a.status = 'COMPLETED'
    ) AS completed_appointments,
    COUNT(a.appointment_id) FILTER (
        WHERE a.status = 'CANCELLED'
    ) AS cancelled_appointments,
    ROUND(
        COUNT(a.appointment_id) FILTER (
            WHERE a.status = 'COMPLETED'
        ) * 100.0 / NULLIF(COUNT(a.appointment_id), 0),
        2
    ) AS completion_rate_percent,
    SUM(EXTRACT(EPOCH FROM (a.end_ts - a.start_ts)) / 60)
        AS total_minutes_booked,
    ROUND(
        AVG(EXTRACT(EPOCH FROM (a.end_ts - a.start_ts)) / 60),
        2
    ) AS avg_appointment_duration_minutes
FROM doctors d
LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
GROUP BY d.doctor_id, d.full_name, d.specialty;

CREATE OR REPLACE VIEW vw_patient_statistics AS
SELECT
    p.patient_id,
    p.first_name || ' ' || p.last_name AS patient_name,
    p.dob,
    EXTRACT(YEAR FROM AGE(p.dob)) AS age,
    COUNT(a.appointment_id) AS total_appointments,
    COUNT(a.appointment_id) FILTER (
        WHERE a.status = 'COMPLETED'
    ) AS completed_appointments,
    COUNT(a.appointment_id) FILTER (
        WHERE a.status = 'CANCELLED'
    ) AS cancelled_appointments,
    MAX(a.start_ts) AS last_appointment_date,
    SUM(
        CASE WHEN pay.status = 'SUCCESS' THEN pay.amount_rs ELSE 0 END
    ) AS total_paid
FROM patients p
LEFT JOIN appointments a ON p.patient_id = a.patient_id
LEFT JOIN payments pay ON a.appointment_id = pay.appointment_id
GROUP BY p.patient_id, p.first_name, p.last_name, p.dob;

CREATE OR REPLACE VIEW vw_specialty_performance AS
SELECT
    d.specialty,
    COUNT(DISTINCT d.doctor_id) AS total_doctors,
    COUNT(a.appointment_id) AS total_appointments,
    COUNT(a.appointment_id) FILTER (
        WHERE a.status = 'COMPLETED'
    ) AS completed_appointments,
    COUNT(a.appointment_id) FILTER (
        WHERE a.status = 'CANCELLED'
    ) AS cancelled_appointments,
    ROUND(
        COUNT(a.appointment_id) FILTER (
            WHERE a.status = 'COMPLETED'
        ) * 100.0 / NULLIF(COUNT(a.appointment_id), 0),
        2
    ) AS completion_rate_percent,
    SUM(
        CASE WHEN pay.status = 'SUCCESS' THEN pay.amount_rs ELSE 0 END
    ) AS total_revenue,
    ROUND(
        AVG(CASE WHEN pay.status = 'SUCCESS' THEN pay.amount_rs END),
        2
    ) AS avg_revenue_per_appointment
FROM doctors d
LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
LEFT JOIN payments pay ON a.appointment_id = pay.appointment_id
GROUP BY d.specialty;

CREATE OR REPLACE VIEW vw_recent_activity AS
SELECT
    'APPOINTMENT'::TEXT AS activity_type,
    a.appointment_id::TEXT AS activity_id,
    p.first_name || ' ' || p.last_name AS patient_name,
    d.full_name AS doctor_name,
    a.start_ts AS activity_time,
    a.status AS status,
    NULL::NUMERIC AS amount
FROM appointments a
JOIN patients p ON a.patient_id = p.patient_id
JOIN doctors d ON a.doctor_id = d.doctor_id

UNION ALL

SELECT
    'PAYMENT'::TEXT AS activity_type,
    pay.payment_id::TEXT AS activity_id,
    p.first_name || ' ' || p.last_name AS patient_name,
    d.full_name AS doctor_name,
    pay.paid_at AS activity_time,
    pay.status AS status,
    pay.amount_rs AS amount
FROM payments pay
JOIN appointments a ON pay.appointment_id = a.appointment_id
JOIN patients p ON a.patient_id = p.patient_id
JOIN doctors d ON a.doctor_id = d.doctor_id
WHERE pay.paid_at IS NOT NULL;
