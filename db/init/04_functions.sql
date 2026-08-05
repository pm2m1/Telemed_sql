-- Create stored procedures for appointment management
-- All functions use plpgsql and run in implicit transactions

-- Function to book an appointment
CREATE OR REPLACE FUNCTION book_appointment(
    p_patient_id UUID,
    p_doctor_id UUID,
    p_start_ts TIMESTAMPTZ,
    p_end_ts TIMESTAMPTZ,
    p_amount_rs NUMERIC(10,2),
    p_payment_method VARCHAR(20) DEFAULT 'UPI'
)
RETURNS UUID AS $$
DECLARE
    v_appointment_id UUID;
BEGIN
    IF p_start_ts IS NULL OR p_end_ts IS NULL THEN
        RAISE EXCEPTION 'Appointment start and end times are required';
    END IF;

    IF p_end_ts <= p_start_ts THEN
        RAISE EXCEPTION 'End time must be after start time. Start: %, End: %', p_start_ts, p_end_ts;
    END IF;

    IF p_start_ts < CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'Cannot book appointment in the past. Start time: %, Current time: %',
            p_start_ts, CURRENT_TIMESTAMP;
    END IF;

    IF p_amount_rs IS NULL OR p_amount_rs < 0 THEN
        RAISE EXCEPTION 'Payment amount cannot be negative. Amount: %', p_amount_rs;
    END IF;

    IF p_payment_method IS NULL
       OR p_payment_method NOT IN ('CASH', 'UPI', 'CARD', 'WALLET') THEN
        RAISE EXCEPTION 'Invalid payment method: %. Must be one of: CASH, UPI, CARD, WALLET', p_payment_method;
    END IF;

    -- Verify patient and doctor exist
    IF NOT EXISTS (SELECT 1 FROM patients WHERE patient_id = p_patient_id) THEN
        RAISE EXCEPTION 'Patient not found. Patient ID: %', p_patient_id;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM doctors WHERE doctor_id = p_doctor_id) THEN
        RAISE EXCEPTION 'Doctor not found. Doctor ID: %', p_doctor_id;
    END IF;

    -- This early check provides a friendly error in the common case. The
    -- exclusion constraint remains the authoritative protection against races.
    IF EXISTS (
        SELECT 1
        FROM appointments
        WHERE doctor_id = p_doctor_id
          AND status = 'BOOKED'
          AND tstzrange(start_ts, end_ts, '[)')
              && tstzrange(p_start_ts, p_end_ts, '[)')
    ) THEN
        RAISE EXCEPTION USING
            ERRCODE = '23P01',
            MESSAGE = format(
                'Doctor has an overlapping appointment. Doctor ID: %s, Start: %s, End: %s',
                p_doctor_id,
                p_start_ts,
                p_end_ts
            );
    END IF;

    BEGIN
        INSERT INTO appointments (
            patient_id,
            doctor_id,
            start_ts,
            end_ts,
            status
        ) VALUES (
            p_patient_id,
            p_doctor_id,
            p_start_ts,
            p_end_ts,
            'BOOKED'
        ) RETURNING appointment_id INTO v_appointment_id;
    EXCEPTION
        WHEN exclusion_violation THEN
            RAISE EXCEPTION USING
                ERRCODE = '23P01',
                MESSAGE = format(
                    'Doctor has an overlapping appointment. Doctor ID: %s, Start: %s, End: %s',
                    p_doctor_id,
                    p_start_ts,
                    p_end_ts
                );
    END;

    -- Insert corresponding payment record
    INSERT INTO payments (
        appointment_id,
        amount_rs,
        method,
        status
    ) VALUES (
        v_appointment_id,
        p_amount_rs,
        p_payment_method,
        'PENDING'
    );

    RETURN v_appointment_id;
END;
$$ LANGUAGE plpgsql;

-- Function to cancel an appointment
CREATE OR REPLACE FUNCTION cancel_appointment(p_appointment_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_appointment_status VARCHAR(20);
    v_payment_status VARCHAR(20);
    v_payment_id UUID;
BEGIN
    SELECT status INTO v_appointment_status
    FROM appointments
    WHERE appointment_id = p_appointment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Appointment not found. Appointment ID: %', p_appointment_id;
    END IF;

    IF v_appointment_status != 'BOOKED' THEN
        RAISE EXCEPTION 'Only BOOKED appointments can be cancelled. Current status: %', v_appointment_status;
    END IF;

    SELECT payment_id, status INTO v_payment_id, v_payment_status
    FROM payments
    WHERE appointment_id = p_appointment_id
    FOR UPDATE;

    UPDATE appointments
    SET status = 'CANCELLED'
    WHERE appointment_id = p_appointment_id;

    IF v_payment_status = 'SUCCESS' THEN
        UPDATE payments
        SET status = 'REFUNDED'
        WHERE payment_id = v_payment_id;
    ELSIF v_payment_status = 'PENDING' THEN
        UPDATE payments
        SET status = 'FAILED',
            paid_at = NULL
        WHERE payment_id = v_payment_id;
    END IF;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to complete an appointment
CREATE OR REPLACE FUNCTION complete_appointment(p_appointment_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_appointment_status VARCHAR(20);
BEGIN
    SELECT status INTO v_appointment_status
    FROM appointments
    WHERE appointment_id = p_appointment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Appointment not found. Appointment ID: %', p_appointment_id;
    END IF;

    IF v_appointment_status != 'BOOKED' THEN
        RAISE EXCEPTION 'Only BOOKED appointments can be completed. Current status: %', v_appointment_status;
    END IF;

    UPDATE appointments
    SET status = 'COMPLETED'
    WHERE appointment_id = p_appointment_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to process payment
CREATE OR REPLACE FUNCTION process_payment(
    p_appointment_id UUID,
    p_payment_status VARCHAR(20)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_current_status VARCHAR(20);
BEGIN
    IF p_payment_status IS NULL
       OR p_payment_status NOT IN ('SUCCESS', 'FAILED') THEN
        RAISE EXCEPTION 'Invalid payment status: %. Must be SUCCESS or FAILED', p_payment_status;
    END IF;

    SELECT status INTO v_current_status
    FROM payments
    WHERE appointment_id = p_appointment_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Payment not found for appointment. Appointment ID: %', p_appointment_id;
    END IF;

    IF v_current_status != 'PENDING' THEN
        RAISE EXCEPTION 'Only PENDING payments can be processed. Current status: %', v_current_status;
    END IF;

    UPDATE payments
    SET status = p_payment_status,
        paid_at = CASE
            WHEN p_payment_status = 'SUCCESS' THEN clock_timestamp()
            ELSE NULL
        END
    WHERE appointment_id = p_appointment_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Display created functions
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_schema = 'public'
    AND routine_type = 'FUNCTION'
ORDER BY routine_name;

