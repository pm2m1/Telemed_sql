package com.pm2m1.telemed.common;

import org.springframework.core.NestedExceptionUtils;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.sql.SQLException;
import java.time.Instant;
import java.util.LinkedHashMap;
import java.util.Map;

@RestControllerAdvice
public class ApiExceptionHandler {

    @ExceptionHandler(ApiBadRequestException.class)
    public ResponseEntity<ApiError> badRequest(ApiBadRequestException exception) {
        return response(HttpStatus.BAD_REQUEST, exception.code(), exception.getMessage());
    }

    @ExceptionHandler(ApiNotFoundException.class)
    public ResponseEntity<ApiError> notFound(ApiNotFoundException exception) {
        return response(HttpStatus.NOT_FOUND, exception.code(), exception.getMessage());
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ApiError> validation(MethodArgumentNotValidException exception) {
        Map<String, String> fields = new LinkedHashMap<>();
        for (FieldError error : exception.getBindingResult().getFieldErrors()) {
            fields.putIfAbsent(error.getField(), error.getDefaultMessage());
        }
        return ResponseEntity.badRequest().body(new ApiError(
                Instant.now(),
                HttpStatus.BAD_REQUEST.value(),
                "VALIDATION_FAILED",
                "Request validation failed",
                fields
        ));
    }

    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ApiError> typeMismatch() {
        return response(
                HttpStatus.BAD_REQUEST,
                "INVALID_PATH_PARAMETER",
                "Path parameter has an invalid format"
        );
    }

    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<ApiError> database(DataAccessException exception) {
        Throwable root = NestedExceptionUtils.getMostSpecificCause(exception);
        if (!(root instanceof SQLException sqlException)) {
            return response(
                    HttpStatus.INTERNAL_SERVER_ERROR,
                    "DATABASE_ERROR",
                    "Database operation failed"
            );
        }

        String state = sqlException.getSQLState();
        String message = sqlException.getMessage() == null
                ? ""
                : sqlException.getMessage();

        if ("23P01".equals(state)) {
            return response(
                    HttpStatus.CONFLICT,
                    "APPOINTMENT_OVERLAP",
                    "Doctor already has an overlapping appointment"
            );
        }
        if (message.contains("Patient not found")) {
            return response(HttpStatus.NOT_FOUND, "PATIENT_NOT_FOUND", "Patient not found");
        }
        if (message.contains("Doctor not found")) {
            return response(HttpStatus.NOT_FOUND, "DOCTOR_NOT_FOUND", "Doctor not found");
        }
        if (message.contains("Appointment not found")) {
            return response(HttpStatus.NOT_FOUND, "APPOINTMENT_NOT_FOUND", "Appointment not found");
        }
        if (message.contains("Payment not found")) {
            return response(HttpStatus.NOT_FOUND, "PAYMENT_NOT_FOUND", "Payment not found");
        }
        if (message.contains("Only BOOKED") || message.contains("Only PENDING")) {
            return response(
                    HttpStatus.CONFLICT,
                    "INVALID_WORKFLOW_STATE",
                    "Resource is not in the required workflow state"
            );
        }
        if (state != null && (state.startsWith("22") || state.startsWith("23"))) {
            return response(
                    HttpStatus.BAD_REQUEST,
                    "DATABASE_CONSTRAINT_REJECTED",
                    "Request violates a database constraint"
            );
        }

        return response(
                HttpStatus.INTERNAL_SERVER_ERROR,
                "DATABASE_ERROR",
                "Database operation failed"
        );
    }

    private ResponseEntity<ApiError> response(
            HttpStatus status,
            String code,
            String message
    ) {
        return ResponseEntity.status(status).body(new ApiError(
                Instant.now(),
                status.value(),
                code,
                message,
                Map.of()
        ));
    }
}
