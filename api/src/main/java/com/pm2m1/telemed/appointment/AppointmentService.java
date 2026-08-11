package com.pm2m1.telemed.appointment;

import com.pm2m1.telemed.appointment.AppointmentModels.AppointmentResponse;
import com.pm2m1.telemed.appointment.AppointmentModels.BookAppointmentRequest;
import com.pm2m1.telemed.appointment.AppointmentModels.PaymentResponse;
import com.pm2m1.telemed.common.ApiBadRequestException;
import com.pm2m1.telemed.common.ApiNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

@Service
public class AppointmentService {

    private final AppointmentRepository repository;

    public AppointmentService(AppointmentRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public AppointmentResponse book(BookAppointmentRequest request) {
        if (!request.endTs().isAfter(request.startTs())) {
            throw new ApiBadRequestException(
                    "INVALID_APPOINTMENT_RANGE",
                    "endTs must be after startTs"
            );
        }
        if (request.startTs().isBefore(OffsetDateTime.now())) {
            throw new ApiBadRequestException(
                    "APPOINTMENT_IN_PAST",
                    "startTs must be in the future"
            );
        }

        UUID appointmentId = repository.book(request);
        return requireAppointment(appointmentId);
    }

    @Transactional(readOnly = true)
    public AppointmentResponse get(UUID appointmentId) {
        return requireAppointment(appointmentId);
    }

    @Transactional(readOnly = true)
    public List<AppointmentResponse> forDoctor(UUID doctorId) {
        return repository.findByDoctor(doctorId);
    }

    @Transactional
    public AppointmentResponse cancel(UUID appointmentId) {
        repository.cancel(appointmentId);
        return requireAppointment(appointmentId);
    }

    @Transactional
    public AppointmentResponse complete(UUID appointmentId) {
        repository.complete(appointmentId);
        return requireAppointment(appointmentId);
    }

    @Transactional
    public PaymentResponse processPayment(UUID appointmentId, String status) {
        repository.processPayment(appointmentId, status);
        AppointmentResponse appointment = requireAppointment(appointmentId);
        if (appointment.payment() == null) {
            throw new ApiNotFoundException(
                    "PAYMENT_NOT_FOUND",
                    "Payment not found for appointment"
            );
        }
        return appointment.payment();
    }

    private AppointmentResponse requireAppointment(UUID appointmentId) {
        return repository.findById(appointmentId)
                .orElseThrow(() -> new ApiNotFoundException(
                        "APPOINTMENT_NOT_FOUND",
                        "Appointment not found"
                ));
    }
}
