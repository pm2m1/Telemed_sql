# Telemedicine Database System

A comprehensive PostgreSQL database system for managing telemedicine operations including patient records, doctor appointments, medical records, and payment tracking.

## Features

- Patient management
- Doctor profiles and specialties
- Appointment scheduling
- Medical records storage
- Payment tracking
- Audit logging

## Technology Stack

- PostgreSQL 16
- Docker & Docker Compose
- pgAdmin for database management

## Getting Started

### Prerequisites

- Docker Desktop
- Docker Compose

### Setup

1. Copy env file and adjust values if needed:
   
   ```bash
   cp env.example .env
   ```

2. Start services:
   
   ```bash
   docker compose up -d
   ```

3. Access:
   - Postgres: localhost:5432 (`POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD`)
   - pgAdmin: http://localhost:8080 (login with `PGADMIN_DEFAULT_EMAIL` / `PGADMIN_DEFAULT_PASSWORD`)

### Project Structure

- `db/init/` – ordered SQL initialization scripts:
  - `00_extensions.sql` – required extensions
  - `01_tables.sql` – tables
  - `02_constraints_indexes.sql` – FKs, unique constraints, indexes
  - `03_triggers.sql` – triggers
  - `04_functions.sql` – PL/pgSQL helper functions
  - `05_views_kpis.sql` – analytical views and KPIs
  - `06_seed.sql` – seed/sample data

### Development Workflow

- Modify SQL in `db/init/` and recreate containers if schema changes:
  
  ```bash
  docker compose down -v && docker compose up -d --build
  ```

### Transparency

This repository was built by me. I used tooling and general guidance for best practices (e.g., CI ideas, docs structure), but all schema design decisions and code were implemented and reviewed by me.
