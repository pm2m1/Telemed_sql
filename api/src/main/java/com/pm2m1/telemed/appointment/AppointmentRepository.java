package com.pm2m1.telemed.appointment;

import com.pm2m1.telemed.appointment.AppointmentModels.AppointmentResponse;
import com.pm2m1.telemed.appointment.AppointmentModels.BookAppointmentRequest;
import com.pm2m1.telemed.appointment.AppointmentModels.PaymentResponse;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate;
import org.springframework.stereotype.Repository;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class AppointmentRepository {

    private static final String APPOINTMENT_SELECT = """
            SELECT
                a.appointment_id,
                a.patient_id,
                a.doctor_id,
                a.start_ts,
                a.end_ts,
                a.status,
                p.payment_id,
                p.amount_rs,
                p.method,
                p.status AS payment_status,
                p.paid_at
            FROM appointments a
            LEFT JOIN payments p ON p.appointment_id = a.appointment_id
            """;

    private final NamedParameterJdbcTemplate jdbc;

    public AppointmentRepository(NamedParameterJdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public UUID book(BookAppointmentRequest request) {
        var parameters = new MapSqlParameterSource()
                .addValue("patientId", request.patientId())
                .addValue("doctorId", request.doctorId())
                .addValue("startTs", request.startTs())
                .addValue("endTs", request.endTs())
                .addValue("amountRs", request.amountRs())
                .addValue("paymentMethod", request.paymentMethod());

        return jdbc.queryForObject("""
                SELECT book_appointment(
                    CAST(:patientId AS UUID),
                    CAST(:doctorId AS UUID),
                    CAST(:startTs AS TIMESTAMPTZ),
                    CAST(:endTs AS TIMESTAMPTZ),
                    CAST(:amountRs AS NUMERIC),
                    CAST(:paymentMethod AS VARCHAR)
                )
                """, parameters, UUID.class);
    }

    public Optional<AppointmentResponse> findById(UUID appointmentId) {
        try {
            var result = jdbc.queryForObject(
                    APPOINTMENT_SELECT + " WHERE a.appointment_id = :appointmentId",
                    new MapSqlParameterSource("appointmentId", appointmentId),
                    this::mapAppointment
            );
            return Optional.ofNullable(result);
        } catch (EmptyResultDataAccessException ignored) {
            return Optional.empty();
        }
    }

    public List<AppointmentResponse> findByDoctor(UUID doctorId) {
        return jdbc.query(
                APPOINTMENT_SELECT + """
                         WHERE a.doctor_id = :doctorId
                         ORDER BY a.start_ts
                        """,
                new MapSqlParameterSource("doctorId", doctorId),
                this::mapAppointment
        );
    }

    public void cancel(UUID appointmentId) {
        jdbc.queryForObject(
                "SELECT cancel_appointment(CAST(:appointmentId AS UUID))",
                new MapSqlParameterSource("appointmentId", appointmentId),
                Boolean.class
        );
    }

    public void complete(UUID appointmentId) {
        jdbc.queryForObject(
                "SELECT complete_appointment(CAST(:appointmentId AS UUID))",
                new MapSqlParameterSource("appointmentId", appointmentId),
                Boolean.class
        );
    }

    public void processPayment(UUID appointmentId, String status) {
        jdbc.queryForObject("""
                SELECT process_payment(
                    CAST(:appointmentId AS UUID),
                    CAST(:status AS VARCHAR)
                )
                """, new MapSqlParameterSource()
                .addValue("appointmentId", appointmentId)
                .addValue("status", status), Boolean.class);
    }

    private AppointmentResponse mapAppointment(ResultSet result, int rowNumber)
            throws SQLException {
        PaymentResponse payment = null;
        UUID paymentId = result.getObject("payment_id", UUID.class);
        if (paymentId != null) {
            payment = new PaymentResponse(
                    paymentId,
                    result.getBigDecimal("amount_rs"),
                    result.getString("method"),
                    result.getString("payment_status"),
                    result.getObject("paid_at", OffsetDateTime.class)
            );
        }

        return new AppointmentResponse(
                result.getObject("appointment_id", UUID.class),
                result.getObject("patient_id", UUID.class),
                result.getObject("doctor_id", UUID.class),
                result.getObject("start_ts", OffsetDateTime.class),
                result.getObject("end_ts", OffsetDateTime.class),
                result.getString("status"),
                payment
        );
    }
}
