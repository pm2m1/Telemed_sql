-- Seed data for telemedicine system
-- This file populates the database with sample data for testing and demonstration

-- Insert sample doctors
INSERT INTO doctors (doctor_id, full_name, specialty) VALUES
    (uuid_generate_v4(), 'Dr. Sarah Johnson', 'Cardiology'),
    (uuid_generate_v4(), 'Dr. Michael Chen', 'Dermatology'),
    (uuid_generate_v4(), 'Dr. Emily Rodriguez', 'Pediatrics'),
    (uuid_generate_v4(), 'Dr. David Kumar', 'Orthopedics'),
    (uuid_generate_v4(), 'Dr. Lisa Wang', 'Neurology');

-- Insert sample patients
INSERT INTO patients (patient_id, first_name, last_name, dob, phone, email) VALUES
    (uuid_generate_v4(), 'John', 'Smith', '1985-03-15', '+1-555-0101', 'john.smith@email.com'),
    (uuid_generate_v4(), 'Jane', 'Doe', '1990-07-22', '+1-555-0102', 'jane.doe@email.com'),
    (uuid_generate_v4(), 'Robert', 'Johnson', '1978-11-08', '+1-555-0103', 'robert.johnson@email.com'),
    (uuid_generate_v4(), 'Maria', 'Garcia', '1992-05-14', '+1-555-0104', 'maria.garcia@email.com'),
    (uuid_generate_v4(), 'Ahmed', 'Hassan', '1988-09-30', '+1-555-0105', 'ahmed.hassan@email.com'),
    (uuid_generate_v4(), 'Priya', 'Patel', '1995-12-03', '+1-555-0106', 'priya.patel@email.com'),
    (uuid_generate_v4(), 'James', 'Wilson', '1983-01-18', '+1-555-0107', 'james.wilson@email.com'),
    (uuid_generate_v4(), 'Sofia', 'Martinez', '1991-08-25', '+1-555-0108', 'sofia.martinez@email.com');

-- Get doctor and patient IDs for appointment booking
DO $$
DECLARE
    dr_sarah_id UUID;
    dr_michael_id UUID;
    dr_emily_id UUID;
    dr_david_id UUID;
    dr_lisa_id UUID;
    
    john_id UUID;
    jane_id UUID;
    robert_id UUID;
    maria_id UUID;
    ahmed_id UUID;
    priya_id UUID;
    james_id UUID;
    sofia_id UUID;
    
    appt_id UUID;
BEGIN
    -- Get doctor IDs
    SELECT doctor_id INTO dr_sarah_id FROM doctors WHERE full_name = 'Dr. Sarah Johnson';
    SELECT doctor_id INTO dr_michael_id FROM doctors WHERE full_name = 'Dr. Michael Chen';
    SELECT doctor_id INTO dr_emily_id FROM doctors WHERE full_name = 'Dr. Emily Rodriguez';
    SELECT doctor_id INTO dr_david_id FROM doctors WHERE full_name = 'Dr. David Kumar';
    SELECT doctor_id INTO dr_lisa_id FROM doctors WHERE full_name = 'Dr. Lisa Wang';
    
    -- Get patient IDs
    SELECT patient_id INTO john_id FROM patients WHERE first_name = 'John' AND last_name = 'Smith';
    SELECT patient_id INTO jane_id FROM patients WHERE first_name = 'Jane' AND last_name = 'Doe';
    SELECT patient_id INTO robert_id FROM patients WHERE first_name = 'Robert' AND last_name = 'Johnson';
    SELECT patient_id INTO maria_id FROM patients WHERE first_name = 'Maria' AND last_name = 'Garcia';
    SELECT patient_id INTO ahmed_id FROM patients WHERE first_name = 'Ahmed' AND last_name = 'Hassan';
    SELECT patient_id INTO priya_id FROM patients WHERE first_name = 'Priya' AND last_name = 'Patel';
    SELECT patient_id INTO james_id FROM patients WHERE first_name = 'James' AND last_name = 'Wilson';
    SELECT patient_id INTO sofia_id FROM patients WHERE first_name = 'Sofia' AND last_name = 'Martinez';
    
    -- Book appointments using the book_appointment function
    -- Future appointments
    SELECT book_appointment(john_id, dr_sarah_id, NOW() + INTERVAL '2 hours', NOW() + INTERVAL '2 hours 30 minutes', 1500.00, 'UPI') INTO appt_id;
    SELECT book_appointment(jane_id, dr_michael_id, NOW() + INTERVAL '1 day', NOW() + INTERVAL '1 day' + INTERVAL '30 minutes', 1200.00, 'CARD') INTO appt_id;
    SELECT book_appointment(robert_id, dr_emily_id, NOW() + INTERVAL '2 days', NOW() + INTERVAL '2 days' + INTERVAL '45 minutes', 1000.00, 'CASH') INTO appt_id;
    SELECT book_appointment(maria_id, dr_david_id, NOW() + INTERVAL '3 days', NOW() + INTERVAL '3 days' + INTERVAL '1 hour', 2000.00, 'WALLET') INTO appt_id;
    SELECT book_appointment(ahmed_id, dr_lisa_id, NOW() + INTERVAL '4 days', NOW() + INTERVAL '4 days' + INTERVAL '30 minutes', 1800.00, 'UPI') INTO appt_id;
    SELECT book_appointment(priya_id, dr_sarah_id, NOW() + INTERVAL '5 days', NOW() + INTERVAL '5 days' + INTERVAL '45 minutes', 1500.00, 'CARD') INTO appt_id;
    SELECT book_appointment(james_id, dr_michael_id, NOW() + INTERVAL '6 days', NOW() + INTERVAL '6 days' + INTERVAL '30 minutes', 1200.00, 'UPI') INTO appt_id;
    SELECT book_appointment(sofia_id, dr_emily_id, NOW() + INTERVAL '7 days', NOW() + INTERVAL '7 days' + INTERVAL '1 hour', 1000.00, 'CASH') INTO appt_id;
    
    -- Book some appointments that will be completed and cancelled for demo
    SELECT book_appointment(john_id, dr_david_id, NOW() + INTERVAL '8 days', NOW() + INTERVAL '8 days' + INTERVAL '45 minutes', 2000.00, 'CARD') INTO appt_id;
    SELECT book_appointment(jane_id, dr_lisa_id, NOW() + INTERVAL '9 days', NOW() + INTERVAL '9 days' + INTERVAL '30 minutes', 1800.00, 'UPI') INTO appt_id;
    
END $$;

-- Process some payments as successful
UPDATE payments 
SET status = 'SUCCESS', paid_at = NOW() 
WHERE appointment_id IN (
    SELECT appointment_id FROM appointments 
    WHERE start_ts BETWEEN NOW() + INTERVAL '2 hours' AND NOW() + INTERVAL '1 day'
    LIMIT 3
);

-- Complete some appointments
UPDATE appointments 
SET status = 'COMPLETED' 
WHERE appointment_id IN (
    SELECT appointment_id FROM appointments 
    WHERE start_ts BETWEEN NOW() + INTERVAL '2 hours' AND NOW() + INTERVAL '1 day'
    LIMIT 2
);

-- Cancel one appointment to demonstrate cancellation logic
SELECT cancel_appointment(
    (SELECT appointment_id FROM appointments 
     WHERE start_ts > NOW() + INTERVAL '1 day' 
     ORDER BY start_ts 
     LIMIT 1)
);

-- Insert medical records for completed appointments
INSERT INTO medical_records (appointment_id, patient_id, doctor_id, diagnosis, notes)
SELECT 
    a.appointment_id,
    a.patient_id,
    a.doctor_id,
    CASE 
        WHEN d.specialty = 'Cardiology' THEN 'Hypertension - Stage 1'
        WHEN d.specialty = 'Dermatology' THEN 'Acne vulgaris - mild to moderate'
        WHEN d.specialty = 'Pediatrics' THEN 'Common cold with mild fever'
        WHEN d.specialty = 'Orthopedics' THEN 'Lower back pain - muscular strain'
        WHEN d.specialty = 'Neurology' THEN 'Tension headache'
        ELSE 'General consultation'
    END as diagnosis,
    CASE 
        WHEN d.specialty = 'Cardiology' THEN 'Patient reports occasional chest discomfort. Blood pressure elevated. Recommended lifestyle changes and follow-up in 3 months.'
        WHEN d.specialty = 'Dermatology' THEN 'Patient presents with facial acne. Prescribed topical treatment and recommended skincare routine.'
        WHEN d.specialty = 'Pediatrics' THEN 'Child presents with runny nose and low-grade fever. No signs of serious infection. Recommended rest and fluids.'
        WHEN d.specialty = 'Orthopedics' THEN 'Patient reports lower back pain after lifting heavy objects. Recommended physical therapy and pain management.'
        WHEN d.specialty = 'Neurology' THEN 'Patient reports frequent tension headaches. Discussed stress management and prescribed mild pain relief.'
        ELSE 'General health consultation completed successfully.'
    END as notes
FROM appointments a
JOIN doctors d ON a.doctor_id = d.doctor_id
WHERE a.status = 'COMPLETED'
LIMIT 2;

-- Display summary of seeded data
SELECT 'SEED DATA SUMMARY' as info;
SELECT 'Doctors' as table_name, COUNT(*) as record_count FROM doctors
UNION ALL
SELECT 'Patients', COUNT(*) FROM patients
UNION ALL
SELECT 'Appointments', COUNT(*) FROM appointments
UNION ALL
SELECT 'Payments', COUNT(*) FROM payments
UNION ALL
SELECT 'Medical Records', COUNT(*) FROM medical_records
UNION ALL
SELECT 'Audit Log', COUNT(*) FROM audit_log;

-- Display appointment status distribution
SELECT 'APPOINTMENT STATUS DISTRIBUTION' as info;
SELECT status, COUNT(*) as count 
FROM appointments 
GROUP BY status 
ORDER BY count DESC;

-- Display payment status distribution
SELECT 'PAYMENT STATUS DISTRIBUTION' as info;
SELECT status, COUNT(*) as count 
FROM payments 
GROUP BY status 
ORDER BY count DESC;

