-- Least-privilege NOLOGIN group roles and demonstrative doctor-scoped RLS.
-- Authentication and login-role provisioning belong outside schema migrations.

DO $$
DECLARE
    v_role TEXT;
BEGIN
    FOREACH v_role IN ARRAY ARRAY[
        'telemed_owner',
        'telemed_admin',
        'telemed_app',
        'telemed_doctor',
        'telemed_billing',
        'telemed_analyst'
    ] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = v_role) THEN
            EXECUTE format('CREATE ROLE %I NOLOGIN', v_role);
        END IF;
    END LOOP;
END;
$$;

-- Trusted function owner and administrators may bypass row policies. Neither
-- role can log in directly, and no password is stored in migrations.
ALTER ROLE telemed_owner BYPASSRLS;
ALTER ROLE telemed_admin BYPASSRLS;

DO $$
BEGIN
    EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC', current_database());
    EXECUTE format(
        'GRANT CONNECT ON DATABASE %I TO telemed_admin, telemed_app, telemed_doctor, telemed_billing, telemed_analyst',
        current_database()
    );
END;
$$;

REVOKE CREATE ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- Future objects created by the migration user start closed to PUBLIC too.
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

GRANT USAGE ON SCHEMA public TO
    telemed_owner,
    telemed_admin,
    telemed_app,
    telemed_doctor,
    telemed_billing,
    telemed_analyst;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public
    TO telemed_owner, telemed_admin;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public
    TO telemed_owner, telemed_admin;

-- Application callers read domain state and execute transactional workflows,
-- but cannot directly mutate transactional tables.
GRANT SELECT ON patients, doctors, appointments, medical_records, payments
    TO telemed_app;
GRANT SELECT ON
    vw_daily_appointments_per_doctor,
    vw_revenue_per_day,
    vw_doctor_utilization,
    vw_patient_statistics,
    vw_specialty_performance,
    vw_recent_activity
    TO telemed_app, telemed_admin;

-- Clinicians receive only doctor-scoped appointment and record access. They
-- can author/update their own record content but cannot alter identifiers.
GRANT SELECT ON appointments, medical_records TO telemed_doctor;
GRANT INSERT ON medical_records TO telemed_doctor;
GRANT UPDATE (diagnosis, notes) ON medical_records TO telemed_doctor;

-- Billing is isolated from clinical records.
GRANT SELECT ON payments TO telemed_billing;

-- Analysts receive aggregate/non-patient-detail views only. Patient-level and
-- recent-activity views intentionally remain unavailable.
GRANT SELECT ON
    vw_daily_appointments_per_doctor,
    vw_revenue_per_day,
    vw_doctor_utilization,
    vw_specialty_performance
    TO telemed_analyst;

CREATE OR REPLACE FUNCTION current_app_doctor_id()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SET search_path = pg_catalog
AS $$
DECLARE
    v_value TEXT;
BEGIN
    v_value := current_setting('app.current_doctor_id', true);
    IF v_value IS NULL OR btrim(v_value) = '' THEN
        RETURN NULL;
    END IF;

    BEGIN
        RETURN v_value::UUID;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RETURN NULL;
    END;
END;
$$;

ALTER FUNCTION current_app_doctor_id() OWNER TO telemed_owner;
REVOKE ALL ON FUNCTION current_app_doctor_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION current_app_doctor_id()
    TO telemed_doctor, telemed_admin, telemed_owner;

ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE medical_records ENABLE ROW LEVEL SECURITY;

CREATE POLICY app_read_appointments
    ON appointments
    FOR SELECT
    TO telemed_app
    USING (TRUE);

CREATE POLICY app_read_medical_records
    ON medical_records
    FOR SELECT
    TO telemed_app
    USING (TRUE);

CREATE POLICY doctor_read_appointments
    ON appointments
    FOR SELECT
    TO telemed_doctor
    USING (doctor_id = current_app_doctor_id());

CREATE POLICY doctor_read_medical_records
    ON medical_records
    FOR SELECT
    TO telemed_doctor
    USING (doctor_id = current_app_doctor_id());

CREATE POLICY doctor_insert_medical_records
    ON medical_records
    FOR INSERT
    TO telemed_doctor
    WITH CHECK (doctor_id = current_app_doctor_id());

CREATE POLICY doctor_update_medical_records
    ON medical_records
    FOR UPDATE
    TO telemed_doctor
    USING (doctor_id = current_app_doctor_id())
    WITH CHECK (doctor_id = current_app_doctor_id());

-- Workflow functions are SECURITY DEFINER so application/billing roles need
-- no direct table mutation grants. A dedicated NOLOGIN owner, fixed search_path,
-- typed parameters, and revoked PUBLIC execution bound the privilege elevation.
ALTER FUNCTION book_appointment(
    UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, NUMERIC, VARCHAR
) OWNER TO telemed_owner;
ALTER FUNCTION cancel_appointment(UUID) OWNER TO telemed_owner;
ALTER FUNCTION complete_appointment(UUID) OWNER TO telemed_owner;
ALTER FUNCTION process_payment(UUID, VARCHAR) OWNER TO telemed_owner;

ALTER FUNCTION book_appointment(
    UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, NUMERIC, VARCHAR
) SECURITY DEFINER;
ALTER FUNCTION cancel_appointment(UUID) SECURITY DEFINER;
ALTER FUNCTION complete_appointment(UUID) SECURITY DEFINER;
ALTER FUNCTION process_payment(UUID, VARCHAR) SECURITY DEFINER;

ALTER FUNCTION book_appointment(
    UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, NUMERIC, VARCHAR
) SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION cancel_appointment(UUID)
    SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION complete_appointment(UUID)
    SET search_path = pg_catalog, public, pg_temp;
ALTER FUNCTION process_payment(UUID, VARCHAR)
    SET search_path = pg_catalog, public, pg_temp;

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public
    TO telemed_owner;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public
    TO telemed_owner;

GRANT EXECUTE ON FUNCTION book_appointment(
    UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, NUMERIC, VARCHAR
) TO telemed_app, telemed_admin;
GRANT EXECUTE ON FUNCTION cancel_appointment(UUID)
    TO telemed_app, telemed_admin;
GRANT EXECUTE ON FUNCTION complete_appointment(UUID)
    TO telemed_app, telemed_admin;
GRANT EXECUTE ON FUNCTION process_payment(UUID, VARCHAR)
    TO telemed_app, telemed_billing, telemed_admin;

GRANT EXECUTE ON FUNCTION uuid_generate_v4()
    TO telemed_owner, telemed_admin, telemed_app, telemed_doctor;
