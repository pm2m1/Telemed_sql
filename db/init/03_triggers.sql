-- Create trigger functions and triggers for business rules enforcement

-- Function to prevent past appointments
CREATE OR REPLACE FUNCTION fn_no_past_appointments()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the appointment start time is in the past
    IF NEW.start_ts < NOW() THEN
        RAISE EXCEPTION 'Cannot create or update appointment with start time in the past. Start time: %, Current time: %', 
            NEW.start_ts, NOW();
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
BEGIN
    -- Prepare before and after data
    IF TG_OP = 'DELETE' THEN
        before_data = to_jsonb(OLD);
        after_data = NULL;
    ELSIF TG_OP = 'UPDATE' THEN
        before_data = to_jsonb(OLD);
        after_data = to_jsonb(NEW);
    ELSIF TG_OP = 'INSERT' THEN
        before_data = NULL;
        after_data = to_jsonb(NEW);
    END IF;
    
    -- Insert audit record
    INSERT INTO audit_log (
        table_name,
        action,
        row_id_text,
        before_json,
        after_json
    ) VALUES (
        TG_TABLE_NAME,
        TG_OP,
        COALESCE(NEW.appointment_id::TEXT, OLD.appointment_id::TEXT),
        before_data,
        after_data
    );
    
    -- Return appropriate record
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION fn_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
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

