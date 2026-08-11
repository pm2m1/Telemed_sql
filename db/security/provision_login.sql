\set ON_ERROR_STOP on

\if :{?login_name}
\else
DO $$ BEGIN RAISE EXCEPTION 'login_name is required'; END $$;
\endif
\if :{?login_password}
\else
DO $$ BEGIN RAISE EXCEPTION 'login_password is required'; END $$;
\endif
\if :{?membership}
\else
DO $$ BEGIN RAISE EXCEPTION 'membership is required'; END $$;
\endif

SELECT set_config('telemed.provision.login_name', :'login_name', false);
SELECT set_config('telemed.provision.membership', :'membership', false);

DO $$
DECLARE
    v_login_name TEXT := current_setting('telemed.provision.login_name');
    v_membership TEXT := current_setting('telemed.provision.membership');
BEGIN
    IF v_login_name !~ '^[a-z][a-z0-9_]{2,62}$' THEN
        RAISE EXCEPTION 'Invalid login role name';
    END IF;

    IF v_membership NOT IN (
        'telemed_admin',
        'telemed_app',
        'telemed_doctor',
        'telemed_billing',
        'telemed_analyst'
    ) THEN
        RAISE EXCEPTION 'Invalid group-role membership';
    END IF;

    IF v_login_name IN (
        'telemed_owner',
        'telemed_admin',
        'telemed_app',
        'telemed_doctor',
        'telemed_billing',
        'telemed_analyst'
    ) THEN
        RAISE EXCEPTION 'Refusing to convert a protected group role into a login';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = v_login_name
          AND (
              NOT rolcanlogin
              OR rolsuper
              OR rolcreaterole
              OR rolcreatedb
              OR rolreplication
              OR rolbypassrls
          )
    ) THEN
        RAISE EXCEPTION
            'Refusing to modify an existing NOLOGIN or elevated role';
    END IF;
END;
$$;

SELECT format('CREATE ROLE %I LOGIN INHERIT', :'login_name')
WHERE NOT EXISTS (
    SELECT 1 FROM pg_roles WHERE rolname = :'login_name'
)\gexec

SELECT format(
    'ALTER ROLE %I LOGIN INHERIT PASSWORD %L',
    :'login_name',
    :'login_password'
)\gexec

-- A reused operational login must not accumulate privileges when its
-- responsibility changes. Remove every other Telemed group first.
SELECT format('REVOKE %I FROM %I', candidate.role_name, :'login_name')
FROM (
    VALUES
        ('telemed_owner'),
        ('telemed_admin'),
        ('telemed_app'),
        ('telemed_doctor'),
        ('telemed_billing'),
        ('telemed_analyst')
) AS candidate(role_name)
WHERE candidate.role_name <> :'membership'
  AND pg_has_role(:'login_name', candidate.role_name, 'member')
\gexec

SELECT format('GRANT %I TO %I', :'membership', :'login_name')\gexec

SELECT format(
    'Provisioned login %I with membership %I',
    :'login_name',
    :'membership'
) AS result;
