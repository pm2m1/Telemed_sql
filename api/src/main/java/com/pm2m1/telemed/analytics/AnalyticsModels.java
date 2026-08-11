package com.pm2m1.telemed.analytics;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.UUID;

public final class AnalyticsModels {

    private AnalyticsModels() {
    }

    public record RevenueSummary(
            LocalDate paymentDate,
            long totalPayments,
            BigDecimal totalRevenue,
            BigDecimal averagePaymentAmount
    ) {
    }

    public record DoctorUtilization(
            UUID doctorId,
            String doctorName,
            String specialty,
            long totalAppointments,
            long completedAppointments,
            long cancelledAppointments,
            BigDecimal completionRatePercent,
            BigDecimal totalMinutesBooked,
            BigDecimal averageAppointmentDurationMinutes
    ) {
    }

    public record PatientStatistics(
            UUID patientId,
            String patientName,
            LocalDate dateOfBirth,
            BigDecimal age,
            long totalAppointments,
            long completedAppointments,
            long cancelledAppointments,
            OffsetDateTime lastAppointmentDate,
            BigDecimal totalPaid
    ) {
    }
}
