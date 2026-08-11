# Spring Boot API

This optional Java 21 / Spring Boot 4.1 service is a thin HTTP adapter over the
database-owned workflows. It uses Spring JDBC rather than an ORM so stored
functions and PostgreSQL error states remain visible engineering boundaries.

## Start with Docker Compose

Set non-default local values in `.env`, then run:

```bash
docker compose --profile api up -d --build api
curl http://localhost:8081/actuator/health
```

The `app-user` one-shot service provisions a LOGIN role with membership in the
NOLOGIN `telemed_app` group. The API can execute supported workflows and read
domain state but cannot directly mutate transactional tables.

## Request examples

Book an appointment:

```bash
curl -i -X POST http://localhost:8081/api/appointments \
  -H 'Content-Type: application/json' \
  -d '{
    "patientId": "20000000-0000-0000-0000-000000000001",
    "doctorId": "10000000-0000-0000-0000-000000000001",
    "startTs": "2098-09-01T10:00:00Z",
    "endTs": "2098-09-01T10:30:00Z",
    "amountRs": 1500.00,
    "paymentMethod": "UPI"
  }'
```

Process its payment:

```bash
curl -i -X POST http://localhost:8081/api/appointments/APPOINTMENT_UUID/payments \
  -H 'Content-Type: application/json' \
  -d '{"status":"SUCCESS"}'
```

Other paths are listed in the root [README](../README.md#optional-spring-boot-api).

## Tests

With Java 21, Maven, and Docker available:

```bash
mvn -B -ntp -f api/pom.xml verify
```

Testcontainers creates PostgreSQL 16.14, Flyway applies V1-V7, and the suite
provisions a least-privilege application login. No existing local database is
used. Tests cover successful workflows, the authoritative overlap conflict,
input validation, missing entities, and analytics.

The HTTP service does not currently implement end-user authentication or RLS
doctor identity propagation. It must not be treated as an Internet-ready
clinical system.
