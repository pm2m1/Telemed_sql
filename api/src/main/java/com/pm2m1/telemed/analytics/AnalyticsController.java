package com.pm2m1.telemed.analytics;

import com.pm2m1.telemed.analytics.AnalyticsModels.DoctorUtilization;
import com.pm2m1.telemed.analytics.AnalyticsModels.PatientStatistics;
import com.pm2m1.telemed.analytics.AnalyticsModels.RevenueSummary;
import com.pm2m1.telemed.common.ApiNotFoundException;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.UUID;

@RestController
@RequestMapping("/api/analytics")
public class AnalyticsController {

    private final AnalyticsRepository repository;

    public AnalyticsController(AnalyticsRepository repository) {
        this.repository = repository;
    }

    @GetMapping("/revenue")
    public List<RevenueSummary> revenue() {
        return repository.revenue();
    }

    @GetMapping("/doctors")
    public List<DoctorUtilization> doctors() {
        return repository.doctors();
    }

    @GetMapping("/patients/{patientId}")
    public PatientStatistics patient(@PathVariable UUID patientId) {
        return repository.patient(patientId)
                .orElseThrow(() -> new ApiNotFoundException(
                        "PATIENT_NOT_FOUND",
                        "Patient not found"
                ));
    }
}
