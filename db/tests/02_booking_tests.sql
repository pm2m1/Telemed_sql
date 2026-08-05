\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_patient_id UUID;
    v_doctor_id UUID;
    v_missing_id UUID;
    v_appointment_id UUID;
    v_adjacent_appointment_id UUID;
    v_start TIMESTAMPTZ := date_trunc('hour', CURRENT_TIMESTAMP) + INTERVAL '50 years';
    v_error_seen BOOLEAN;
BEGIN
    INSERT INTO patients (first_name, last_name, dob, phone, email)
    VALUES ('Booking', 'Patient', DATE '1990-01-01', '+910000000011', 'booking-test@example.invalid')
    RETURNING patient_id INTO v_patient_id;

    INSERT INTO doctors (full_name, specialty)
    VALUES ('Dr. Booking Test', 'Test Medicine')
    RETURNING doctor_id INTO v_doctor_id;

    v_appointment_id := book_appointment(
        v_patient_id,
        v_doctor_id,
        v_start,
        v_start + INTERVAL '30 minutes',
        750.00,
        'UPI'
    );

    IF NOT EXISTS (
        SELECT 1
        FROM appointments
        WHERE appointment_id = v_appointment_id
          AND status = 'BOOKED'
    ) THEN
        RAISE EXCEPTION 'Booking test failed: valid appointment was not created as BOOKED';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM payments
        WHERE appointment_id = v_appointment_id
          AND status = 'PENDING'
          AND amount_rs = 750.00
          AND method = 'UPI'
    ) THEN
        RAISE EXCEPTION 'Booking test failed: associated PENDING payment was not created';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        PERFORM book_appointment(
            v_patient_id,
            v_doctor_id,
            CURRENT_TIMESTAMP - INTERVAL '2 hours',
            CURRENT_TIMESTAMP - INTERVAL '1 hour',
            500.00,
            'CASH'
        );
    EXCEPTION
        WHEN OTHERS THEN
            IF position('Cannot book appointment in the past' IN SQLERRM) = 0 THEN
                RAISE;
            END IF;
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Booking test failed: a past appointment was accepted';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        PERFORM book_appointment(
            v_patient_id,
            v_doctor_id,
            v_start + INTERVAL '2 hours',
            v_start + INTERVAL '2 hours',
            500.00,
            'CASH'
        );
    EXCEPTION
        WHEN OTHERS THEN
            IF position('End time must be after start time' IN SQLERRM) = 0 THEN
                RAISE;
            END IF;
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Booking test failed: end_ts <= start_ts was accepted';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        PERFORM book_appointment(
            v_patient_id,
            v_doctor_id,
            v_start + INTERVAL '15 minutes',
            v_start + INTERVAL '45 minutes',
            500.00,
            'CARD'
        );
    EXCEPTION
        WHEN exclusion_violation THEN
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Booking test failed: overlapping BOOKED appointment was accepted';
    END IF;

    v_adjacent_appointment_id := book_appointment(
        v_patient_id,
        v_doctor_id,
        v_start + INTERVAL '30 minutes',
        v_start + INTERVAL '1 hour',
        500.00,
        'CARD'
    );

    IF v_adjacent_appointment_id IS NULL THEN
        RAISE EXCEPTION 'Booking test failed: back-to-back appointment was not created';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        PERFORM book_appointment(
            v_patient_id,
            v_doctor_id,
            v_start + INTERVAL '2 hours',
            v_start + INTERVAL '2 hours 30 minutes',
            500.00,
            'BANK_TRANSFER'
        );
    EXCEPTION
        WHEN OTHERS THEN
            IF position('Invalid payment method' IN SQLERRM) = 0 THEN
                RAISE;
            END IF;
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Booking test failed: invalid payment method was accepted';
    END IF;

    v_missing_id := uuid_generate_v4();
    v_error_seen := FALSE;
    BEGIN
        PERFORM book_appointment(
            v_missing_id,
            v_doctor_id,
            v_start + INTERVAL '3 hours',
            v_start + INTERVAL '3 hours 30 minutes',
            500.00,
            'UPI'
        );
    EXCEPTION
        WHEN OTHERS THEN
            IF position('Patient not found' IN SQLERRM) = 0 THEN
                RAISE;
            END IF;
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Booking test failed: missing patient was accepted';
    END IF;

    v_missing_id := uuid_generate_v4();
    v_error_seen := FALSE;
    BEGIN
        PERFORM book_appointment(
            v_patient_id,
            v_missing_id,
            v_start + INTERVAL '4 hours',
            v_start + INTERVAL '4 hours 30 minutes',
            500.00,
            'UPI'
        );
    EXCEPTION
        WHEN OTHERS THEN
            IF position('Doctor not found' IN SQLERRM) = 0 THEN
                RAISE;
            END IF;
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Booking test failed: missing doctor was accepted';
    END IF;

    RAISE NOTICE 'Booking workflow and validation tests passed';
END;
$$ LANGUAGE plpgsql;

ROLLBACK;
