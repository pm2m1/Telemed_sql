\set ON_ERROR_STOP on

BEGIN;
SET LOCAL TIME ZONE 'UTC';

DO $$
DECLARE
    v_patient_id UUID;
    v_doctor_id UUID;
    v_completed_id UUID;
    v_cancelled_id UUID;
    v_booked_id UUID;
    v_name TEXT;
    v_day DATE := CURRENT_DATE + 10000;
    v_payment_day DATE := CURRENT_DATE + 10001;
    v_start TIMESTAMPTZ;
    v_total BIGINT;
    v_completed BIGINT;
    v_cancelled BIGINT;
    v_booked BIGINT;
    v_doctors BIGINT;
    v_amount NUMERIC;
    v_rate NUMERIC;
BEGIN
    FOREACH v_name IN ARRAY ARRAY[
        'vw_daily_appointments_per_doctor',
        'vw_revenue_per_day',
        'vw_doctor_utilization',
        'vw_patient_statistics',
        'vw_specialty_performance',
        'vw_recent_activity'
    ] LOOP
        IF to_regclass('public.' || v_name) IS NULL THEN
            RAISE EXCEPTION 'View test failed: expected view public.% does not exist', v_name;
        END IF;
    END LOOP;

    v_start := (v_day + TIME '09:00') AT TIME ZONE 'UTC';

    INSERT INTO patients (first_name, last_name, dob, phone, email)
    VALUES ('View', 'Patient', DATE '1990-01-01', '+910000000041', 'view-test@example.invalid')
    RETURNING patient_id INTO v_patient_id;

    INSERT INTO doctors (full_name, specialty)
    VALUES ('Dr. View Test', 'View Test Specialty')
    RETURNING doctor_id INTO v_doctor_id;

    INSERT INTO appointments (patient_id, doctor_id, start_ts, end_ts, status)
    VALUES (v_patient_id, v_doctor_id, v_start, v_start + INTERVAL '30 minutes', 'COMPLETED')
    RETURNING appointment_id INTO v_completed_id;

    INSERT INTO appointments (patient_id, doctor_id, start_ts, end_ts, status)
    VALUES (
        v_patient_id,
        v_doctor_id,
        v_start + INTERVAL '1 hour',
        v_start + INTERVAL '1 hour 30 minutes',
        'CANCELLED'
    )
    RETURNING appointment_id INTO v_cancelled_id;

    INSERT INTO appointments (patient_id, doctor_id, start_ts, end_ts, status)
    VALUES (
        v_patient_id,
        v_doctor_id,
        v_start + INTERVAL '2 hours',
        v_start + INTERVAL '2 hours 30 minutes',
        'BOOKED'
    )
    RETURNING appointment_id INTO v_booked_id;

    INSERT INTO payments (appointment_id, amount_rs, method, status, paid_at)
    VALUES
        (v_completed_id, 100.00, 'UPI', 'SUCCESS', (v_payment_day + TIME '10:00') AT TIME ZONE 'UTC'),
        (v_cancelled_id, 200.00, 'CARD', 'FAILED', (v_payment_day + TIME '11:00') AT TIME ZONE 'UTC'),
        (v_booked_id, 300.00, 'CASH', 'PENDING', (v_payment_day + TIME '12:00') AT TIME ZONE 'UTC');

    SELECT total_appointments, completed_count, cancelled_count, booked_count
    INTO v_total, v_completed, v_cancelled, v_booked
    FROM vw_daily_appointments_per_doctor
    WHERE doctor_id = v_doctor_id
      AND appointment_date = v_day;

    IF v_total IS DISTINCT FROM 3
       OR v_completed IS DISTINCT FROM 1
       OR v_cancelled IS DISTINCT FROM 1
       OR v_booked IS DISTINCT FROM 1 THEN
        RAISE EXCEPTION
            'View test failed: daily appointments expected total/completed/cancelled/booked 3/1/1/1, got %/%/%/%',
            v_total, v_completed, v_cancelled, v_booked;
    END IF;

    SELECT total_payments, total_revenue
    INTO v_total, v_amount
    FROM vw_revenue_per_day
    WHERE payment_date = v_payment_day;

    IF v_total IS DISTINCT FROM 1 OR v_amount IS DISTINCT FROM 100.00::NUMERIC THEN
        RAISE EXCEPTION
            'View test failed: revenue expected one SUCCESS payment totalling 100.00, got count % and amount %',
            v_total, v_amount;
    END IF;

    SELECT total_appointments, completed_appointments, cancelled_appointments, completion_rate_percent
    INTO v_total, v_completed, v_cancelled, v_rate
    FROM vw_doctor_utilization
    WHERE doctor_id = v_doctor_id;

    IF v_total IS DISTINCT FROM 3
       OR v_completed IS DISTINCT FROM 1
       OR v_cancelled IS DISTINCT FROM 1
       OR v_rate IS DISTINCT FROM 33.33::NUMERIC THEN
        RAISE EXCEPTION
            'View test failed: doctor utilization expected 3/1/1 and 33.33%%, got %/%/% and %%%',
            v_total, v_completed, v_cancelled, v_rate;
    END IF;

    SELECT total_appointments, completed_appointments, cancelled_appointments, total_paid
    INTO v_total, v_completed, v_cancelled, v_amount
    FROM vw_patient_statistics
    WHERE patient_id = v_patient_id;

    IF v_total IS DISTINCT FROM 3
       OR v_completed IS DISTINCT FROM 1
       OR v_cancelled IS DISTINCT FROM 1
       OR v_amount IS DISTINCT FROM 100.00::NUMERIC THEN
        RAISE EXCEPTION
            'View test failed: patient statistics expected 3/1/1 and 100.00 paid, got %/%/% and %',
            v_total, v_completed, v_cancelled, v_amount;
    END IF;

    SELECT total_doctors, total_appointments, completed_appointments,
           cancelled_appointments, completion_rate_percent, total_revenue
    INTO v_doctors, v_total, v_completed, v_cancelled, v_rate, v_amount
    FROM vw_specialty_performance
    WHERE specialty = 'View Test Specialty';

    IF v_doctors IS DISTINCT FROM 1
       OR v_total IS DISTINCT FROM 3
       OR v_completed IS DISTINCT FROM 1
       OR v_cancelled IS DISTINCT FROM 1
       OR v_rate IS DISTINCT FROM 33.33::NUMERIC
       OR v_amount IS DISTINCT FROM 100.00::NUMERIC THEN
        RAISE EXCEPTION
            'View test failed: specialty performance aggregates were incorrect';
    END IF;

    RAISE NOTICE 'Analytical view and KPI tests passed';
END;
$$ LANGUAGE plpgsql;

ROLLBACK;
