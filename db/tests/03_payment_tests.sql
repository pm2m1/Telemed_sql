\set ON_ERROR_STOP on

BEGIN;

DO $$
DECLARE
    v_patient_id UUID;
    v_doctor_id UUID;
    v_success_id UUID;
    v_cancel_success_id UUID;
    v_cancel_pending_id UUID;
    v_complete_id UUID;
    v_start TIMESTAMPTZ := date_trunc('hour', CURRENT_TIMESTAMP) + INTERVAL '51 years';
    v_error_seen BOOLEAN;
BEGIN
    INSERT INTO patients (first_name, last_name, dob, phone, email)
    VALUES ('Payment', 'Patient', DATE '1990-01-01', '+910000000021', 'payment-test@example.invalid')
    RETURNING patient_id INTO v_patient_id;

    INSERT INTO doctors (full_name, specialty)
    VALUES ('Dr. Payment Test', 'Test Medicine')
    RETURNING doctor_id INTO v_doctor_id;

    v_success_id := book_appointment(
        v_patient_id, v_doctor_id,
        v_start, v_start + INTERVAL '30 minutes',
        100.00, 'UPI'
    );
    v_cancel_success_id := book_appointment(
        v_patient_id, v_doctor_id,
        v_start + INTERVAL '30 minutes', v_start + INTERVAL '1 hour',
        200.00, 'CARD'
    );
    v_cancel_pending_id := book_appointment(
        v_patient_id, v_doctor_id,
        v_start + INTERVAL '1 hour', v_start + INTERVAL '1 hour 30 minutes',
        300.00, 'CASH'
    );
    v_complete_id := book_appointment(
        v_patient_id, v_doctor_id,
        v_start + INTERVAL '1 hour 30 minutes', v_start + INTERVAL '2 hours',
        400.00, 'WALLET'
    );

    IF NOT process_payment(v_success_id, 'SUCCESS') THEN
        RAISE EXCEPTION 'Payment test failed: process_payment did not return true';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM payments
        WHERE appointment_id = v_success_id
          AND status = 'SUCCESS'
          AND paid_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Payment test failed: PENDING payment did not become SUCCESS';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        PERFORM process_payment(v_complete_id, 'REFUNDED');
    EXCEPTION
        WHEN OTHERS THEN
            IF position('Invalid payment status' IN SQLERRM) = 0 THEN
                RAISE;
            END IF;
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Payment test failed: process_payment accepted an invalid status';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        UPDATE payments
        SET status = 'INVALID'
        WHERE appointment_id = v_complete_id;
    EXCEPTION
        WHEN check_violation THEN
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'Payment test failed: payment status check constraint accepted INVALID';
    END IF;

    PERFORM process_payment(v_cancel_success_id, 'SUCCESS');
    IF NOT cancel_appointment(v_cancel_success_id) THEN
        RAISE EXCEPTION 'Cancellation test failed: cancellation did not return true';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM appointments a
        JOIN payments p USING (appointment_id)
        WHERE a.appointment_id = v_cancel_success_id
          AND a.status = 'CANCELLED'
          AND p.status = 'REFUNDED'
          AND p.paid_at IS NOT NULL
    ) THEN
        RAISE EXCEPTION 'Cancellation test failed: SUCCESS payment did not become REFUNDED';
    END IF;

    PERFORM cancel_appointment(v_cancel_pending_id);
    IF NOT EXISTS (
        SELECT 1
        FROM appointments a
        JOIN payments p USING (appointment_id)
        WHERE a.appointment_id = v_cancel_pending_id
          AND a.status = 'CANCELLED'
          AND p.status = 'FAILED'
          AND p.paid_at IS NULL
    ) THEN
        RAISE EXCEPTION 'Cancellation test failed: PENDING payment did not become FAILED';
    END IF;

    IF NOT complete_appointment(v_complete_id) THEN
        RAISE EXCEPTION 'Completion test failed: completion did not return true';
    END IF;

    IF (SELECT status FROM appointments WHERE appointment_id = v_complete_id) <> 'COMPLETED' THEN
        RAISE EXCEPTION 'Completion test failed: appointment status is not COMPLETED';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        PERFORM process_payment(v_success_id, 'FAILED');
    EXCEPTION
        WHEN OTHERS THEN
            IF position('Only PENDING payments can be processed' IN SQLERRM) = 0 THEN
                RAISE;
            END IF;
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'State transition test failed: SUCCESS payment was processed again';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        PERFORM cancel_appointment(v_complete_id);
    EXCEPTION
        WHEN OTHERS THEN
            IF position('Only BOOKED appointments can be cancelled' IN SQLERRM) = 0 THEN
                RAISE;
            END IF;
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'State transition test failed: COMPLETED appointment was cancelled';
    END IF;

    v_error_seen := FALSE;
    BEGIN
        PERFORM complete_appointment(v_cancel_pending_id);
    EXCEPTION
        WHEN OTHERS THEN
            IF position('Only BOOKED appointments can be completed' IN SQLERRM) = 0 THEN
                RAISE;
            END IF;
            v_error_seen := TRUE;
    END;

    IF NOT v_error_seen THEN
        RAISE EXCEPTION 'State transition test failed: CANCELLED appointment was completed';
    END IF;

    RAISE NOTICE 'Payment, cancellation, completion, and state transition tests passed';
END;
$$ LANGUAGE plpgsql;

ROLLBACK;
