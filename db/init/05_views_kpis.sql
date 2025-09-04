-- Create views and KPI queries for telemedicine system analytics

-- View: Daily appointments per doctor
CREATE OR REPLACE VIEW vw_daily_appointments_per_doctor AS
SELECT 
    DATE(a.start_ts) as appointment_date,
    d.doctor_id,
    d.full_name as doctor_name,
    d.specialty,
    COUNT(*) as total_appointments,
    COUNT(CASE WHEN a.status = 'BOOKED' THEN 1 END) as booked_count,
    COUNT(CASE WHEN a.status = 'COMPLETED' THEN 1 END) as completed_count,
    COUNT(CASE WHEN a.status = 'CANCELLED' THEN 1 END) as cancelled_count
FROM appointments a
JOIN doctors d ON a.doctor_id = d.doctor_id
GROUP BY DATE(a.start_ts), d.doctor_id, d.full_name, d.specialty
ORDER BY appointment_date DESC, doctor_name;

-- View: Revenue per day
CREATE OR REPLACE VIEW vw_revenue_per_day AS
SELECT 
    DATE(p.paid_at) as payment_date,
    COUNT(*) as total_payments,
    SUM(p.amount_rs) as total_revenue,
    AVG(p.amount_rs) as avg_payment_amount,
    COUNT(CASE WHEN p.method = 'UPI' THEN 1 END) as upi_count,
    COUNT(CASE WHEN p.method = 'CARD' THEN 1 END) as card_count,
    COUNT(CASE WHEN p.method = 'CASH' THEN 1 END) as cash_count,
    COUNT(CASE WHEN p.method = 'WALLET' THEN 1 END) as wallet_count
FROM payments p
WHERE p.status = 'SUCCESS' 
    AND p.paid_at IS NOT NULL
GROUP BY DATE(p.paid_at)
ORDER BY payment_date DESC;

-- View: Doctor utilization
CREATE OR REPLACE VIEW vw_doctor_utilization AS
SELECT 
    d.doctor_id,
    d.full_name as doctor_name,
    d.specialty,
    COUNT(a.appointment_id) as total_appointments,
    COUNT(CASE WHEN a.status = 'COMPLETED' THEN 1 END) as completed_appointments,
    COUNT(CASE WHEN a.status = 'CANCELLED' THEN 1 END) as cancelled_appointments,
    ROUND(
        COUNT(CASE WHEN a.status = 'COMPLETED' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(a.appointment_id), 0), 2
    ) as completion_rate_percent,
    SUM(EXTRACT(EPOCH FROM (a.end_ts - a.start_ts))/60) as total_minutes_booked,
    ROUND(AVG(EXTRACT(EPOCH FROM (a.end_ts - a.start_ts))/60), 2) as avg_appointment_duration_minutes
FROM doctors d
LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
GROUP BY d.doctor_id, d.full_name, d.specialty
ORDER BY total_appointments DESC;

-- View: Patient statistics
CREATE OR REPLACE VIEW vw_patient_statistics AS
SELECT 
    p.patient_id,
    p.first_name || ' ' || p.last_name as patient_name,
    p.dob,
    EXTRACT(YEAR FROM AGE(p.dob)) as age,
    COUNT(a.appointment_id) as total_appointments,
    COUNT(CASE WHEN a.status = 'COMPLETED' THEN 1 END) as completed_appointments,
    COUNT(CASE WHEN a.status = 'CANCELLED' THEN 1 END) as cancelled_appointments,
    MAX(a.start_ts) as last_appointment_date,
    SUM(CASE WHEN pay.status = 'SUCCESS' THEN pay.amount_rs ELSE 0 END) as total_paid
FROM patients p
LEFT JOIN appointments a ON p.patient_id = a.patient_id
LEFT JOIN payments pay ON a.appointment_id = pay.appointment_id
GROUP BY p.patient_id, p.first_name, p.last_name, p.dob
ORDER BY total_appointments DESC;

-- View: Specialty performance
CREATE OR REPLACE VIEW vw_specialty_performance AS
SELECT 
    d.specialty,
    COUNT(DISTINCT d.doctor_id) as total_doctors,
    COUNT(a.appointment_id) as total_appointments,
    COUNT(CASE WHEN a.status = 'COMPLETED' THEN 1 END) as completed_appointments,
    COUNT(CASE WHEN a.status = 'CANCELLED' THEN 1 END) as cancelled_appointments,
    ROUND(
        COUNT(CASE WHEN a.status = 'COMPLETED' THEN 1 END) * 100.0 / 
        NULLIF(COUNT(a.appointment_id), 0), 2
    ) as completion_rate_percent,
    SUM(CASE WHEN pay.status = 'SUCCESS' THEN pay.amount_rs ELSE 0 END) as total_revenue,
    ROUND(AVG(CASE WHEN pay.status = 'SUCCESS' THEN pay.amount_rs END), 2) as avg_revenue_per_appointment
FROM doctors d
LEFT JOIN appointments a ON d.doctor_id = a.doctor_id
LEFT JOIN payments pay ON a.appointment_id = pay.appointment_id
GROUP BY d.specialty
ORDER BY total_appointments DESC;

-- View: Recent activity
CREATE OR REPLACE VIEW vw_recent_activity AS
SELECT 
    'APPOINTMENT' as activity_type,
    a.appointment_id::TEXT as activity_id,
    p.first_name || ' ' || p.last_name as patient_name,
    d.full_name as doctor_name,
    a.start_ts as activity_time,
    a.status as status,
    NULL as amount
FROM appointments a
JOIN patients p ON a.patient_id = p.patient_id
JOIN doctors d ON a.doctor_id = d.doctor_id

UNION ALL

SELECT 
    'PAYMENT' as activity_type,
    pay.payment_id::TEXT as activity_id,
    p.first_name || ' ' || p.last_name as patient_name,
    d.full_name as doctor_name,
    pay.paid_at as activity_time,
    pay.status as status,
    pay.amount_rs as amount
FROM payments pay
JOIN appointments a ON pay.appointment_id = a.appointment_id
JOIN patients p ON a.patient_id = p.patient_id
JOIN doctors d ON a.doctor_id = d.doctor_id
WHERE pay.paid_at IS NOT NULL

ORDER BY activity_time DESC;

-- Display created views
SELECT 
    schemaname,
    viewname,
    definition
FROM pg_views 
WHERE schemaname = 'public'
ORDER BY viewname;

