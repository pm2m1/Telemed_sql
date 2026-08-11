\set ON_ERROR_STOP on

\if :{?login_name}
\else
DO $$ BEGIN RAISE EXCEPTION 'login_name is required'; END $$;
\endif

\if :{?membership}
\else
DO $$ BEGIN RAISE EXCEPTION 'membership is required'; END $$;
\endif

SELECT set_config('telemed.test.login_name', :'login_name', false);
SELECT set_config('telemed.test.membership', :'membership', false);

DO $$
DECLARE
    v_login_name TEXT := current_setting('telemed.test.login_name');
    v_membership TEXT := current_setting('telemed.test.membership');
    v_extra_memberships INTEGER;
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = v_login_name
          AND rolcanlogin
    ) THEN
        RAISE EXCEPTION
            'Login provisioning test failed: role % is absent or cannot log in',
            v_login_name;
    END IF;

    IF NOT pg_has_role(v_login_name, v_membership, 'member') THEN
        RAISE EXCEPTION
            'Login provisioning test failed: % is not a member of %',
            v_login_name,
            v_membership;
    END IF;

    SELECT COUNT(*)
    INTO v_extra_memberships
    FROM unnest(ARRAY[
        'telemed_owner',
        'telemed_admin',
        'telemed_app',
        'telemed_doctor',
        'telemed_billing',
        'telemed_analyst'
    ]) AS group_role(role_name)
    WHERE role_name <> v_membership
      AND pg_has_role(v_login_name, role_name, 'member');

    IF v_extra_memberships <> 0 THEN
        RAISE EXCEPTION
            'Login provisioning test failed: % retained % extra memberships',
            v_login_name,
            v_extra_memberships;
    END IF;

    RAISE NOTICE 'Runtime login provisioning test passed';
END;
$$;

SELECT format('DROP ROLE %I', :'login_name') \gexec
