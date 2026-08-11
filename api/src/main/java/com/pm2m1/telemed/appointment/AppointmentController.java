package com.pm2m1.telemed.appointment;

import com.pm2m1.telemed.appointment.AppointmentModels.AppointmentResponse;
import com.pm2m1.telemed.appointment.AppointmentModels.BookAppointmentRequest;
import com.pm2m1.telemed.appointment.AppointmentModels.PaymentResponse;
import com.pm2m1.telemed.appointment.AppointmentModels.ProcessPaymentRequest;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.URI;
import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api")
public class AppointmentController {

    private final AppointmentService service;

    public AppointmentController(AppointmentService service) {
        this.service = service;
    }

    @PostMapping("/appointments")
    public ResponseEntity<AppointmentResponse> book(
            @Valid @RequestBody BookAppointmentRequest request
    ) {
        AppointmentResponse appointment = service.book(request);
        return ResponseEntity
                .created(URI.create("/api/appointments/" + appointment.appointmentId()))
                .body(appointment);
    }

    @GetMapping("/appointments/{appointmentId}")
    public AppointmentResponse get(@PathVariable UUID appointmentId) {
        return service.get(appointmentId);
    }

    @PostMapping("/appointments/{appointmentId}/cancel")
    public AppointmentResponse cancel(@PathVariable UUID appointmentId) {
        return service.cancel(appointmentId);
    }

    @PostMapping("/appointments/{appointmentId}/complete")
    public AppointmentResponse complete(@PathVariable UUID appointmentId) {
        return service.complete(appointmentId);
    }

    @PostMapping("/appointments/{appointmentId}/payments")
    public PaymentResponse processPayment(
            @PathVariable UUID appointmentId,
            @Valid @RequestBody ProcessPaymentRequest request
    ) {
        return service.processPayment(appointmentId, request.status());
    }

    @GetMapping("/doctors/{doctorId}/appointments")
    public List<AppointmentResponse> doctorAppointments(
            @PathVariable UUID doctorId
    ) {
        return service.forDoctor(doctorId);
    }
}
