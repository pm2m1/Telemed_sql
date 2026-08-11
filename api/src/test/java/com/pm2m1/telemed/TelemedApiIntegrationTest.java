package com.pm2m1.telemed;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.Statement;
import java.time.Duration;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
class TelemedApiIntegrationTest {

    private static final String APP_USER = "telemed_test_app";
    private static final String APP_PASSWORD = "test-only-password";
    private static final UUID PATIENT_A = UUID.fromString(
            "91000000-0000-4000-8000-000000000001"
    );
    private static final UUID PATIENT_B = UUID.fromString(
            "91000000-0000-4000-8000-000000000002"
    );
    private static final UUID DOCTOR_A = UUID.fromString(
            "91000000-0000-4000-8000-000000000011"
    );
    private static final UUID DOCTOR_B = UUID.fromString(
            "91000000-0000-4000-8000-000000000012"
    );
    private static final Pattern APPOINTMENT_ID = Pattern.compile(
            "\\\"appointmentId\\\":\\\"([0-9a-f-]{36})\\\""
    );

    private static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(
            DockerImageName.parse("postgres:16.14")
    )
            .withDatabaseName("telemed_api_test")
            .withUsername("postgres")
            .withPassword("test-database-password");

    static {
        POSTGRES.start();
        Path migrations = resolveMigrations();
        Flyway.configure()
                .dataSource(
                        POSTGRES.getJdbcUrl(),
                        POSTGRES.getUsername(),
                        POSTGRES.getPassword()
                )
                .locations("filesystem:" + migrations.toString().replace('\\', '/'))
                .validateMigrationNaming(true)
                .cleanDisabled(true)
                .load()
                .migrate();

        try (Connection connection = adminConnection();
             Statement statement = connection.createStatement()) {
            statement.execute("""
                    CREATE ROLE telemed_test_app
                    LOGIN INHERIT PASSWORD 'test-only-password'
                    IN ROLE telemed_app
                    """);
        } catch (Exception exception) {
            POSTGRES.stop();
            throw new ExceptionInInitializerError(exception);
        }
    }

    @LocalServerPort
    private int port;

    private final HttpClient http = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(5))
            .build();

    @DynamicPropertySource
    static void databaseProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", () -> APP_USER);
        registry.add("spring.datasource.password", () -> APP_PASSWORD);
    }

    @BeforeEach
    void resetFixtures() throws Exception {
        try (Connection connection = adminConnection();
             Statement statement = connection.createStatement()) {
            statement.execute("""
                    TRUNCATE TABLE medical_records, payments, appointments,
                                   audit_log, patients, doctors
                    RESTART IDENTITY CASCADE
                    """);
            statement.execute("""
                    INSERT INTO patients (
                        patient_id, first_name, last_name, dob, phone, email
                    ) VALUES
                        ('91000000-0000-4000-8000-000000000001', 'API', 'Patient A', DATE '1990-01-01', '+910000000091', 'api-a@example.invalid'),
                        ('91000000-0000-4000-8000-000000000002', 'API', 'Patient B', DATE '1991-01-01', '+910000000092', 'api-b@example.invalid')
                    """);
            statement.execute("""
                    INSERT INTO doctors (doctor_id, full_name, specialty)
                    VALUES
                        ('91000000-0000-4000-8000-000000000011', 'Dr. API A', 'Cardiology'),
                        ('91000000-0000-4000-8000-000000000012', 'Dr. API B', 'Neurology')
                    """);
        }
    }

    @AfterAll
    static void stopPostgres() {
        POSTGRES.stop();
    }

    @Test
    void booksAndReadsAppointmentAndDoctorSchedule() throws Exception {
        HttpResponse<String> booked = post(
                "/api/appointments",
                bookingJson(PATIENT_A, DOCTOR_A, "2098-09-01T10:00:00Z", "2098-09-01T10:30:00Z")
        );
        assertEquals(201, booked.statusCode());
        UUID appointmentId = appointmentId(booked.body());
        assertTrue(booked.body().contains("\"status\":\"BOOKED\""));
        assertTrue(booked.body().contains("\"payment\""));
        assertTrue(booked.body().contains("\"status\":\"PENDING\""));

        HttpResponse<String> fetched = get("/api/appointments/" + appointmentId);
        assertEquals(200, fetched.statusCode());
        assertTrue(fetched.body().contains(appointmentId.toString()));

        HttpResponse<String> schedule = get(
                "/api/doctors/" + DOCTOR_A + "/appointments"
        );
        assertEquals(200, schedule.statusCode());
        assertTrue(schedule.body().contains(appointmentId.toString()));
    }

    @Test
    void mapsAuthoritativeOverlapConstraintToConflict() throws Exception {
        HttpResponse<String> first = post(
                "/api/appointments",
                bookingJson(PATIENT_A, DOCTOR_A, "2098-09-02T10:00:00Z", "2098-09-02T10:30:00Z")
        );
        assertEquals(201, first.statusCode());

        HttpResponse<String> conflict = post(
                "/api/appointments",
                bookingJson(PATIENT_B, DOCTOR_A, "2098-09-02T10:15:00Z", "2098-09-02T10:45:00Z")
        );
        assertEquals(409, conflict.statusCode());
        assertTrue(conflict.body().contains("APPOINTMENT_OVERLAP"));
    }

    @Test
    void processesPaymentAndSupportsCancellationAndCompletion() throws Exception {
        UUID cancelledId = appointmentId(post(
                "/api/appointments",
                bookingJson(PATIENT_A, DOCTOR_A, "2098-09-03T10:00:00Z", "2098-09-03T10:30:00Z")
        ).body());

        HttpResponse<String> payment = post(
                "/api/appointments/" + cancelledId + "/payments",
                "{\"status\":\"SUCCESS\"}"
        );
        assertEquals(200, payment.statusCode());
        assertTrue(payment.body().contains("\"status\":\"SUCCESS\""));

        HttpResponse<String> cancelled = post(
                "/api/appointments/" + cancelledId + "/cancel",
                null
        );
        assertEquals(200, cancelled.statusCode());
        assertTrue(cancelled.body().contains("\"status\":\"CANCELLED\""));
        assertTrue(cancelled.body().contains("\"status\":\"REFUNDED\""));

        UUID completedId = appointmentId(post(
                "/api/appointments",
                bookingJson(PATIENT_B, DOCTOR_B, "2098-09-03T11:00:00Z", "2098-09-03T11:30:00Z")
        ).body());
        HttpResponse<String> completed = post(
                "/api/appointments/" + completedId + "/complete",
                null
        );
        assertEquals(200, completed.statusCode());
        assertTrue(completed.body().contains("\"status\":\"COMPLETED\""));
    }

    @Test
    void rejectsInvalidInputAndReportsMissingEntities() throws Exception {
        HttpResponse<String> badUuid = get("/api/appointments/not-a-uuid");
        assertEquals(400, badUuid.statusCode());
        assertTrue(badUuid.body().contains("INVALID_PATH_PARAMETER"));

        HttpResponse<String> badRange = post(
                "/api/appointments",
                bookingJson(PATIENT_A, DOCTOR_A, "2098-09-04T11:00:00Z", "2098-09-04T10:00:00Z")
        );
        assertEquals(400, badRange.statusCode());
        assertTrue(badRange.body().contains("INVALID_APPOINTMENT_RANGE"));

        HttpResponse<String> missingPatient = post(
                "/api/appointments",
                bookingJson(
                        UUID.fromString("91000000-0000-4000-8000-000000000099"),
                        DOCTOR_A,
                        "2098-09-04T12:00:00Z",
                        "2098-09-04T12:30:00Z"
                )
        );
        assertEquals(404, missingPatient.statusCode());
        assertTrue(missingPatient.body().contains("PATIENT_NOT_FOUND"));

        HttpResponse<String> missingDoctor = post(
                "/api/appointments",
                bookingJson(
                        PATIENT_A,
                        UUID.fromString("91000000-0000-4000-8000-000000000099"),
                        "2098-09-04T13:00:00Z",
                        "2098-09-04T13:30:00Z"
                )
        );
        assertEquals(404, missingDoctor.statusCode());
        assertTrue(missingDoctor.body().contains("DOCTOR_NOT_FOUND"));

        HttpResponse<String> missingAppointment = get(
                "/api/appointments/91000000-0000-4000-8000-000000000098"
        );
        assertEquals(404, missingAppointment.statusCode());
    }

    @Test
    void returnsRevenueDoctorAndPatientAnalytics() throws Exception {
        UUID appointmentId = appointmentId(post(
                "/api/appointments",
                bookingJson(PATIENT_A, DOCTOR_A, "2098-09-05T10:00:00Z", "2098-09-05T10:30:00Z")
        ).body());
        assertEquals(200, post(
                "/api/appointments/" + appointmentId + "/payments",
                "{\"status\":\"SUCCESS\"}"
        ).statusCode());
        assertEquals(200, post(
                "/api/appointments/" + appointmentId + "/complete",
                null
        ).statusCode());

        HttpResponse<String> revenue = get("/api/analytics/revenue");
        assertEquals(200, revenue.statusCode());
        assertTrue(revenue.body().contains("750.00"));

        HttpResponse<String> doctors = get("/api/analytics/doctors");
        assertEquals(200, doctors.statusCode());
        assertTrue(doctors.body().contains("Dr. API A"));

        HttpResponse<String> patient = get("/api/analytics/patients/" + PATIENT_A);
        assertEquals(200, patient.statusCode());
        assertTrue(patient.body().contains("API Patient A"));
        assertTrue(patient.body().contains("750.00"));
    }

    private HttpResponse<String> get(String path) throws Exception {
        return http.send(
                HttpRequest.newBuilder(uri(path)).GET().build(),
                HttpResponse.BodyHandlers.ofString()
        );
    }

    private HttpResponse<String> post(String path, String body) throws Exception {
        HttpRequest.BodyPublisher publisher = body == null
                ? HttpRequest.BodyPublishers.noBody()
                : HttpRequest.BodyPublishers.ofString(body);
        return http.send(
                HttpRequest.newBuilder(uri(path))
                        .header("Content-Type", "application/json")
                        .POST(publisher)
                        .build(),
                HttpResponse.BodyHandlers.ofString()
        );
    }

    private URI uri(String path) {
        return URI.create("http://127.0.0.1:" + port + path);
    }

    private static String bookingJson(
            UUID patientId,
            UUID doctorId,
            String start,
            String end
    ) {
        return """
                {
                  "patientId": "%s",
                  "doctorId": "%s",
                  "startTs": "%s",
                  "endTs": "%s",
                  "amountRs": 750.00,
                  "paymentMethod": "UPI"
                }
                """.formatted(patientId, doctorId, start, end);
    }

    private static UUID appointmentId(String body) {
        Matcher matcher = APPOINTMENT_ID.matcher(body);
        assertTrue(matcher.find(), "Response did not contain appointmentId: " + body);
        return UUID.fromString(matcher.group(1));
    }

    private static Connection adminConnection() throws Exception {
        return DriverManager.getConnection(
                POSTGRES.getJdbcUrl(),
                POSTGRES.getUsername(),
                POSTGRES.getPassword()
        );
    }

    private static Path resolveMigrations() {
        Path fromRepositoryRoot = Path.of("db", "migrations").toAbsolutePath();
        if (Files.isDirectory(fromRepositoryRoot)) {
            return fromRepositoryRoot;
        }

        Path fromApiDirectory = Path.of("..", "db", "migrations")
                .toAbsolutePath()
                .normalize();
        if (Files.isDirectory(fromApiDirectory)) {
            return fromApiDirectory;
        }

        throw new IllegalStateException(
                "Cannot locate db/migrations; run Maven from the repository root or api directory"
        );
    }
}
