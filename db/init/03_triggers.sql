-- Create trigger functions and triggers for business rules enforcement

-- Function to prevent appointments from being created or rescheduled in the past
CREATE OR REPLACE FUNCTION fn_no_past_appointments()
RETURNS TRIGGER AS $$
BEGIN
    -- Status-only updates remain valid after the appointment has started. This
    -- permits legitimate completion and cancellation while still protecting the
    -- scheduled time on inserts and reschedules.
    IF TG_OP = 'INSERT' THEN
        IF NEW.start_ts < CURRENT_TIMESTAMP THEN
            RAISE EXCEPTION
                'Cannot create or reschedule an appointment in the past. Start time: %, Current time: %',
                NEW.start_ts,
                CURRENT_TIMESTAMP;
        END IF;
    ELSIF NEW.start_ts IS DISTINCT FROM OLD.start_ts
          AND NEW.start_ts < CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION
            'Cannot create or reschedule an appointment in the past. Start time: %, Current time: %',
            NEW.start_ts,
            CURRENT_TIMESTAMP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function for audit logging
CREATE OR REPLACE FUNCTION fn_audit_appointments()
RETURNS TRIGGER AS $$
DECLARE
    before_data JSONB;
    after_data JSONB;
    affected_appointment_id UUID;
BEGIN
    IF TG_OP = 'DELETE' THEN
        before_data := to_jsonb(OLD);
        after_data := NULL;
        affected_appointment_id := OLD.appointment_id;
    ELSIF TG_OP = 'UPDATE' THEN
        before_data := to_jsonb(OLD);
        after_data := to_jsonb(NEW);
        affected_appointment_id := NEW.appointment_id;
    ELSE
        before_data := NULL;
        after_data := to_jsonb(NEW);
        affected_appointment_id := NEW.appointment_id;
    END IF;

    INSERT INTO audit_log (
        table_name,
        action,
        row_id_text,
        before_json,
        after_json
    ) VALUES (
        TG_TABLE_NAME,
        TG_OP,
        affected_appointment_id::TEXT,
        before_data,
        after_data
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION fn_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := clock_timestamp();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
-- Prevent past appointments
CREATE TRIGGER trg_no_past_appointments
    BEFORE INSERT OR UPDATE ON appointments
    FOR EACH ROW
    EXECUTE FUNCTION fn_no_past_appointments();

-- Audit appointments changes
CREATE TRIGGER trg_audit_appointments
    AFTER INSERT OR UPDATE OR DELETE ON appointments
    FOR EACH ROW
    EXECUTE FUNCTION fn_audit_appointments();

-- Update timestamps for patients
CREATE TRIGGER trg_patients_updated_at
    BEFORE UPDATE ON patients
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_updated_at();

-- Update timestamps for doctors
CREATE TRIGGER trg_doctors_updated_at
    BEFORE UPDATE ON doctors
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_updated_at();

-- Update timestamps for appointments
CREATE TRIGGER trg_appointments_updated_at
    BEFORE UPDATE ON appointments
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_updated_at();

-- Update timestamps for medical_records
CREATE TRIGGER trg_medical_records_updated_at
    BEFORE UPDATE ON medical_records
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_updated_at();

-- Update timestamps for payments
CREATE TRIGGER trg_payments_updated_at
    BEFORE UPDATE ON payments
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_updated_at();

-- Display created triggers
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers 
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

