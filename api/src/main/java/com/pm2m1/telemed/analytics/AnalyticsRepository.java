package com.pm2m1.telemed.analytics;

import com.pm2m1.telemed.analytics.AnalyticsModels.DoctorUtilization;
import com.pm2m1.telemed.analytics.AnalyticsModels.PatientStatistics;
import com.pm2m1.telemed.analytics.AnalyticsModels.RevenueSummary;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class AnalyticsRepository {

    private final NamedParameterJdbcTemplate jdbc;

    public AnalyticsRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public List<RevenueSummary> revenue() {
        return jdbc.query("""
                SELECT payment_date, total_payments, total_revenue,
                       avg_payment_amount
                FROM vw_revenue_per_day
                ORDER BY payment_date DESC
                """, (result, rowNumber) -> new RevenueSummary(
                result.getObject("payment_date", java.time.LocalDate.class),
                result.getLong("total_payments"),
                result.getBigDecimal("total_revenue"),
                result.getBigDecimal("avg_payment_amount")
        ));
    }

    public List<DoctorUtilization> doctors() {
        return jdbc.query("""
                SELECT doctor_id, doctor_name, specialty, total_appointments,
                       completed_appointments, cancelled_appointments,
                       completion_rate_percent, total_minutes_booked,
                       avg_appointment_duration_minutes
                FROM vw_doctor_utilization
                ORDER BY doctor_name
                """, (result, rowNumber) -> new DoctorUtilization(
                result.getObject("doctor_id", UUID.class),
                result.getString("doctor_name"),
                result.getString("specialty"),
                result.getLong("total_appointments"),
                result.getLong("completed_appointments"),
                result.getLong("cancelled_appointments"),
                result.getBigDecimal("completion_rate_percent"),
                result.getBigDecimal("total_minutes_booked"),
                result.getBigDecimal("avg_appointment_duration_minutes")
        ));
    }

    public Optional<PatientStatistics> patient(UUID patientId) {
        try {
            PatientStatistics value = jdbc.queryForObject("""
                    SELECT patient_id, patient_name, dob, age,
                           total_appointments, completed_appointments,
                           cancelled_appointments, last_appointment_date,
                           total_paid
                    FROM vw_patient_statistics
                    WHERE patient_id = :patientId
                    """, new MapSqlParameterSource("patientId", patientId),
                    (result, rowNumber) -> new PatientStatistics(
                            result.getObject("patient_id", UUID.class),
                            result.getString("patient_name"),
                            result.getObject("dob", java.time.LocalDate.class),
                            result.getBigDecimal("age"),
                            result.getLong("total_appointments"),
                            result.getLong("completed_appointments"),
                            result.getLong("cancelled_appointments"),
                            result.getObject("last_appointment_date", OffsetDateTime.class),
                            result.getBigDecimal("total_paid")
                    ));
            return Optional.ofNullable(value);
        } catch (EmptyResultDataAccessException ignored) {
            return Optional.empty();
        }
    }
}
