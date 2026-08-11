# Login provisioning

Versioned migrations create only `NOLOGIN` group roles and never store
passwords. `provision_login.sql` is an operational helper for creating or
rotating an application login and granting one approved group membership.
Values must be supplied at runtime.

The Compose `api` profile invokes it with `TELEMED_API_DB_USER` and
`TELEMED_API_DB_PASSWORD`. In a deployed system, manage login credentials with
the platform's secret store and rotate them independently of schema changes.

The helper refuses protected Telemed group names and existing NOLOGIN or
elevated roles. Re-provisioning a normal operational login rotates its password
and leaves it with exactly one approved Telemed group membership.
