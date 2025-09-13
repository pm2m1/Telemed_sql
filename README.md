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

- SQL 
- Docker & Docker Compose
- pgAdmin for database management


### Project Structure

- `db/init/` – SQL initialization scripts:
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



This project was developed as a complete telemedicine database solution with proper SQL structure, Docker configuration, and documentation.
