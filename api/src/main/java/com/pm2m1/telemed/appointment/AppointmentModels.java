package com.pm2m1.telemed.appointment;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

public final class AppointmentModels {

    private AppointmentModels() {
    }

    public record BookAppointmentRequest(
            @NotNull UUID patientId,
            @NotNull UUID doctorId,
            @NotNull OffsetDateTime startTs,
            @NotNull OffsetDateTime endTs,
            @NotNull @DecimalMin(value = "0.00") BigDecimal amountRs,
            @NotBlank
            @Pattern(regexp = "CASH|UPI|CARD|WALLET")
            String paymentMethod
    ) {
    }

    public record ProcessPaymentRequest(
            @NotBlank
            @Pattern(regexp = "SUCCESS|FAILED")
            String status
    ) {
    }

    public record PaymentResponse(
            UUID paymentId,
            BigDecimal amountRs,
            String method,
            String status,
            OffsetDateTime paidAt
    ) {
    }

    public record AppointmentResponse(
            UUID appointmentId,
            UUID patientId,
            UUID doctorId,
            OffsetDateTime startTs,
            OffsetDateTime endTs,
            String status,
            PaymentResponse payment
    ) {
    }
}
