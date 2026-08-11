\set ON_ERROR_STOP on
\pset tuples_only on
\pset format unaligned

DO $$
DECLARE
    v_table_count INTEGER;
    v_view_count INTEGER;
    v_function_count INTEGER;
BEGIN
    IF to_regclass('public.flyway_schema_history') IS NOT NULL THEN
        RAISE EXCEPTION 'Flyway history already exists; use ordinary migrate';
    END IF;

    SELECT COUNT(*)
    INTO v_table_count
    FROM unnest(ARRAY[
        'patients',
        'doctors',
        'appointments',
        'medical_records',
        'payments',
        'audit_log'
    ]) AS expected(name)
    WHERE to_regclass('public.' || expected.name) IS NOT NULL;

    IF v_table_count = 0 THEN
        RAISE EXCEPTION 'Schema is empty; run Flyway migrate without baselining';
    END IF;
    IF v_table_count <> 6 THEN
        RAISE EXCEPTION
            'Legacy preflight failed: found % of 6 expected tables',
            v_table_count;
    END IF;

    SELECT COUNT(*)
    INTO v_view_count
    FROM unnest(ARRAY[
        'vw_daily_appointments_per_doctor',
        'vw_revenue_per_day',
        'vw_doctor_utilization',
        'vw_patient_statistics',
        'vw_specialty_performance',
        'vw_recent_activity'
    ]) AS expected(name)
    WHERE to_regclass('public.' || expected.name) IS NOT NULL;

    SELECT COUNT(*)
    INTO v_function_count
    FROM unnest(ARRAY[
        'book_appointment',
        'cancel_appointment',
        'complete_appointment',
        'process_payment'
    ]) AS expected(name)
    WHERE to_regprocedure(
        CASE expected.name
            WHEN 'book_appointment' THEN
                'public.book_appointment(uuid,uuid,timestamptz,timestamptz,numeric,character varying)'
            WHEN 'process_payment' THEN
                'public.process_payment(uuid,character varying)'
            ELSE 'public.' || expected.name || '(uuid)'
        END
    ) IS NOT NULL;

    IF v_view_count <> 6 OR v_function_count <> 4 THEN
        RAISE EXCEPTION
            'Legacy preflight failed: expected 6 views and 4 workflows, found % and %',
            v_view_count,
            v_function_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.appointments'::regclass
          AND conname = 'excl_appointments_booked_doctor_time'
          AND contype = 'x'
    ) THEN
        RAISE EXCEPTION 'Legacy preflight failed: overlap constraint is absent';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.appointments'::regclass
          AND conname = 'uk_appointments_identity'
    ) THEN
        RAISE EXCEPTION 'Schema already contains post-V5 objects';
    END IF;
END;
$$;

SELECT 'LEGACY_V5_SCHEMA_CONFIRMED';
