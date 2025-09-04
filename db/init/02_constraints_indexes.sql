-- Add foreign key constraints and indexes
-- This file runs after tables are created

-- Foreign Key Constraints
ALTER TABLE appointments 
    ADD CONSTRAINT fk_appointments_patient 
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE RESTRICT;

ALTER TABLE appointments 
    ADD CONSTRAINT fk_appointments_doctor 
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE RESTRICT;

ALTER TABLE medical_records 
    ADD CONSTRAINT fk_medical_records_appointment 
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE SET NULL;

ALTER TABLE medical_records 
    ADD CONSTRAINT fk_medical_records_patient 
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) ON DELETE RESTRICT;

ALTER TABLE medical_records 
    ADD CONSTRAINT fk_medical_records_doctor 
    FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id) ON DELETE RESTRICT;

ALTER TABLE payments 
    ADD CONSTRAINT fk_payments_appointment 
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id) ON DELETE RESTRICT;

-- Unique Constraints
ALTER TABLE patients 
    ADD CONSTRAINT uk_patients_phone UNIQUE (phone);

ALTER TABLE patients 
    ADD CONSTRAINT uk_patients_email UNIQUE (email);

ALTER TABLE payments 
    ADD CONSTRAINT uk_payments_appointment UNIQUE (appointment_id);

-- Indexes for Performance
-- Appointments indexes
CREATE INDEX idx_appointments_doctor_start ON appointments(doctor_id, start_ts);
CREATE INDEX idx_appointments_patient_start ON appointments(patient_id, start_ts);
CREATE INDEX idx_appointments_status ON appointments(status);
CREATE INDEX idx_appointments_start_ts ON appointments(start_ts);

-- Partial index for upcoming appointments
CREATE INDEX idx_appointments_upcoming ON appointments(doctor_id, start_ts) 
WHERE status = 'BOOKED' AND start_ts > NOW();

-- Patients indexes
CREATE INDEX idx_patients_phone ON patients(phone);
CREATE INDEX idx_patients_email ON patients(email);
CREATE INDEX idx_patients_name ON patients(first_name, last_name);

-- Trigram indexes for fuzzy search
CREATE INDEX idx_patients_name_trgm ON patients USING gin((first_name || ' ' || last_name) gin_trgm_ops);
CREATE INDEX idx_patients_phone_trgm ON patients USING gin(phone gin_trgm_ops);

-- Medical records indexes
CREATE INDEX idx_medical_records_appointment ON medical_records(appointment_id);
CREATE INDEX idx_medical_records_patient ON medical_records(patient_id);
CREATE INDEX idx_medical_records_doctor ON medical_records(doctor_id);

-- Payments indexes
CREATE INDEX idx_payments_appointment ON payments(appointment_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_paid_at ON payments(paid_at);

-- Audit log indexes
CREATE INDEX idx_audit_log_table_action ON audit_log(table_name, action);
CREATE INDEX idx_audit_log_changed_at ON audit_log(changed_at);

-- Display constraints and indexes
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as definition
FROM pg_constraint 
WHERE conrelid = 'appointments'::regclass
ORDER BY contype, conname;

SELECT 
    indexname,
    indexdef
FROM pg_indexes 
WHERE schemaname = 'public' 
ORDER BY tablename, indexname;

