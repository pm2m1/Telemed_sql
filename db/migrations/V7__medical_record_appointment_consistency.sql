-- Preserve standalone medical records while ensuring an optional appointment
-- matches the same patient and doctor stored on the record.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM medical_records mr
        JOIN appointments a ON a.appointment_id = mr.appointment_id
        WHERE mr.appointment_id IS NOT NULL
          AND (mr.patient_id <> a.patient_id OR mr.doctor_id <> a.doctor_id)
    ) THEN
        RAISE EXCEPTION
            'Cannot apply medical-record consistency constraint: mismatched legacy rows exist';
    END IF;
END;
$$;

ALTER TABLE appointments
    ADD CONSTRAINT uk_appointments_identity
    UNIQUE (appointment_id, patient_id, doctor_id);

ALTER TABLE medical_records
    DROP CONSTRAINT fk_medical_records_appointment;

-- MATCH SIMPLE preserves standalone records when appointment_id is NULL.
-- PostgreSQL's column-specific SET NULL keeps patient_id and doctor_id intact
-- when an appointment is deleted.
ALTER TABLE medical_records
    ADD CONSTRAINT fk_medical_records_appointment_identity
    FOREIGN KEY (appointment_id, patient_id, doctor_id)
    REFERENCES appointments (appointment_id, patient_id, doctor_id)
    MATCH SIMPLE
    ON DELETE SET NULL (appointment_id);
