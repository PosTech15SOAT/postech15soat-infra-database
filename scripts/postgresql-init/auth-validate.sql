-- Somente leitura, executado como runtime após revogar o SET ROLE do master.
-- A estrutura abaixo corresponde ao SQL fixado em auth/source.json (PostgreSQL 17).
SET default_transaction_read_only = on;
SET search_path = pg_catalog, public;
WITH
owner_role AS (SELECT * FROM pg_roles WHERE rolname = 'numberone_auth_owner'),
runtime_role AS (SELECT * FROM pg_roles WHERE rolname = 'numberone_auth_runtime'),
app_tables AS (
    SELECT c.* FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname IN ('auth_perfil', 'auth_perfil_permissao', 'auth_usuario')
),
expected_columns(table_name, column_name, data_type, not_null, default_value) AS (VALUES
    ('auth_perfil', 'nome', 'text', true, NULL::text),
    ('auth_perfil_permissao', 'perfil', 'text', true, NULL),
    ('auth_perfil_permissao', 'permissao', 'text', true, NULL),
    ('auth_usuario', 'id', 'uuid', true, 'gen_random_uuid()'),
    ('auth_usuario', 'perfil', 'text', true, NULL),
    ('auth_usuario', 'cliente_id', 'uuid', false, NULL),
    ('auth_usuario', 'cpf', 'text', true, NULL),
    ('auth_usuario', 'senha_hash', 'text', true, NULL),
    ('auth_usuario', 'ativo', 'boolean', true, 'true')
),
actual_columns AS (
    SELECT c.relname::text, a.attname::text, format_type(a.atttypid, a.atttypmod), a.attnotnull,
           pg_get_expr(d.adbin, d.adrelid)
    FROM app_tables c JOIN pg_attribute a ON a.attrelid = c.oid
    LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum
    WHERE a.attnum > 0 AND NOT a.attisdropped
),
expected_constraints(table_name, definition) AS (VALUES
    ('auth_perfil', $$CHECK ((nome = ANY (ARRAY['CUSTOMER'::text, 'ADMIN'::text])))$$),
    ('auth_perfil', 'PRIMARY KEY (nome)'),
    ('auth_perfil_permissao', 'FOREIGN KEY (perfil) REFERENCES auth_perfil(nome)'),
    ('auth_perfil_permissao', $$CHECK ((permissao ~ '^[A-Za-z][A-Za-z0-9_:.-]{0,119}$'::text))$$),
    ('auth_perfil_permissao', 'PRIMARY KEY (perfil, permissao)'),
    ('auth_usuario', $$CHECK (((perfil = 'CUSTOMER'::text) = (cliente_id IS NOT NULL)))$$),
    ('auth_usuario', 'UNIQUE (perfil, cpf)'),
    ('auth_usuario', 'UNIQUE (cliente_id)'),
    ('auth_usuario', $$CHECK ((cpf ~ '^[0-9]{11}$'::text))$$),
    ('auth_usuario', 'FOREIGN KEY (perfil) REFERENCES auth_perfil(nome)'),
    ('auth_usuario', 'PRIMARY KEY (id)'),
    ('auth_usuario', $$CHECK ((senha_hash ~ '^[0-9a-f]{32}:[0-9a-f]{64}$'::text))$$)
),
actual_constraints AS (
    SELECT c.relname::text, pg_get_constraintdef(con.oid)
    FROM app_tables c JOIN pg_constraint con ON con.conrelid = c.oid
),
expected_permissions(perfil, permissao) AS (VALUES
    ('ADMIN', 'ADMIN_ACCESS'), ('ADMIN', 'ordem-servico:read'),
    ('ADMIN', 'ordem-servico:create'), ('ADMIN', 'ordem-servico:update'),
    ('ADMIN', 'cliente:read'), ('ADMIN', 'cliente:update'),
    ('ADMIN', 'estoque:read'), ('ADMIN', 'estoque:update'),
    ('CUSTOMER', 'ordem-servico:read'), ('CUSTOMER', 'cliente:read'),
    ('CUSTOMER', 'SERVICE_ORDER_TRACK_OWN'), ('CUSTOMER', 'BUDGET_RESPOND_OWN')
),
checks(name, valid) AS (
    SELECT 'identidade', current_user = 'numberone_auth_runtime' AND current_database() = 'numberone_auth'
    UNION ALL
    SELECT 'roles', NOT o.rolcanlogin AND r.rolcanlogin
        AND NOT o.rolsuper AND NOT o.rolcreatedb AND NOT o.rolcreaterole AND NOT o.rolreplication AND NOT o.rolbypassrls
        AND NOT r.rolsuper AND NOT r.rolcreatedb AND NOT r.rolcreaterole AND NOT r.rolreplication AND NOT r.rolbypassrls
        AND NOT EXISTS (
            SELECT 1 FROM pg_auth_members m
            WHERE m.member IN (o.oid, r.oid)
               OR (m.roleid IN (o.oid, r.oid) AND
                   (m.member <> (SELECT oid FROM pg_roles WHERE rolname = :'master_username')
                    OR m.set_option OR m.inherit_option))
        ) FROM owner_role o CROSS JOIN runtime_role r
    UNION ALL
    SELECT 'database/ACL', d.datdba = o.oid AND d.datallowconn
        AND has_database_privilege(r.oid, d.oid, 'CONNECT')
        AND NOT has_database_privilege(r.oid, d.oid, 'CREATE,TEMPORARY')
        AND NOT EXISTS (
            SELECT 1 FROM aclexplode(coalesce(d.datacl, acldefault('d', d.datdba))) a
            WHERE a.grantee <> o.oid AND
                (a.grantee <> r.oid OR a.privilege_type <> 'CONNECT' OR a.is_grantable)
        )
        AND NOT EXISTS (SELECT 1 FROM pg_database WHERE datdba = r.oid)
        FROM pg_database d CROSS JOIN owner_role o CROSS JOIN runtime_role r
        WHERE d.datname = 'numberone_auth'
    UNION ALL
    SELECT 'isolamento', NOT EXISTS (
        SELECT 1 FROM pg_database d WHERE d.datname IN ('numberone_os','numberone_billing','numberone_inventory')
        AND (has_database_privilege('numberone_auth_runtime', d.oid, 'CONNECT')
             OR has_database_privilege(d.datname, 'numberone_auth', 'CONNECT'))
    )
    UNION ALL
    SELECT 'schema/ACL', pg_get_userbyid(n.nspowner) IN ('numberone_auth_owner', 'pg_database_owner')
        AND has_schema_privilege(o.oid, n.oid, 'CREATE') AND has_schema_privilege(o.oid, n.oid, 'USAGE')
        AND has_schema_privilege(r.oid, n.oid, 'USAGE')
        AND NOT has_schema_privilege(r.oid, n.oid, 'CREATE')
        AND NOT EXISTS (
            SELECT 1 FROM aclexplode(coalesce(n.nspacl, acldefault('n', n.nspowner))) a
            WHERE a.grantee NOT IN (o.oid, n.nspowner) AND
                (a.grantee <> r.oid OR a.privilege_type <> 'USAGE' OR a.is_grantable)
        ) FROM pg_namespace n CROSS JOIN owner_role o CROSS JOIN runtime_role r WHERE n.nspname = 'public'
    UNION ALL
    SELECT 'tabelas/owner', (SELECT count(*) FROM app_tables WHERE relkind = 'r' AND relpersistence = 'p'
        AND NOT relrowsecurity AND NOT relforcerowsecurity AND NOT relispartition) = 3
        AND NOT EXISTS (SELECT 1 FROM app_tables WHERE relowner <> o.oid)
        AND NOT EXISTS (
            SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relowner = r.oid
        )
        AND NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspowner = r.oid)
        AND NOT EXISTS (SELECT 1 FROM pg_proc WHERE proowner = r.oid)
        AND NOT EXISTS (SELECT 1 FROM pg_type WHERE typowner = r.oid)
        FROM owner_role o CROSS JOIN runtime_role r
    UNION ALL
    SELECT 'colunas', NOT EXISTS (
        (SELECT * FROM expected_columns EXCEPT SELECT * FROM actual_columns)
        UNION ALL
        (SELECT * FROM actual_columns EXCEPT SELECT * FROM expected_columns)
    ) AND NOT EXISTS (
        SELECT 1 FROM app_tables c JOIN pg_attribute a ON a.attrelid = c.oid
        WHERE a.attnum > 0 AND NOT a.attisdropped
            AND (a.attacl IS NOT NULL OR a.attidentity <> '' OR a.attgenerated <> '')
    )
    UNION ALL
    SELECT 'constraints/indices', NOT EXISTS (
        (SELECT * FROM expected_constraints EXCEPT SELECT * FROM actual_constraints)
        UNION ALL
        (SELECT * FROM actual_constraints EXCEPT SELECT * FROM expected_constraints)
    ) AND NOT EXISTS (
        SELECT 1 FROM app_tables c JOIN pg_constraint con ON con.conrelid = c.oid
        WHERE NOT con.convalidated OR con.condeferrable OR con.condeferred
    ) AND NOT EXISTS (
        SELECT 1 FROM app_tables c JOIN pg_index i ON i.indrelid = c.oid
        WHERE NOT i.indisvalid OR NOT i.indisready
    )
    UNION ALL
    SELECT 'tabelas/grants', NOT EXISTS (
        SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
        CROSS JOIN LATERAL aclexplode(coalesce(c.relacl, acldefault(
            CASE WHEN c.relkind = 'S' THEN 's'::"char" ELSE 'r'::"char" END, c.relowner))) a
        WHERE n.nspname = 'public' AND c.relkind IN ('r','p','v','m','S','f') AND a.grantee <> o.oid
            AND (c.relname NOT IN ('auth_usuario','auth_perfil_permissao') OR a.grantee <> r.oid
                 OR a.privilege_type <> 'SELECT' OR a.is_grantable)
    ) AND has_table_privilege(r.oid, 'public.auth_usuario', 'SELECT')
      AND has_table_privilege(r.oid, 'public.auth_perfil_permissao', 'SELECT')
      AND NOT EXISTS (
          SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
          JOIN pg_attribute a ON a.attrelid = c.oid
          WHERE n.nspname = 'public' AND a.attacl IS NOT NULL
      ) FROM owner_role o CROSS JOIN runtime_role r
    UNION ALL
    SELECT 'default privileges', NOT EXISTS (
        SELECT 1 FROM pg_default_acl d CROSS JOIN LATERAL aclexplode(d.defaclacl) a
        WHERE d.defaclrole IN (o.oid, r.oid)
            AND (d.defaclnamespace = 0 OR d.defaclnamespace = 'public'::regnamespace)
            AND a.grantee <> d.defaclrole
    ) FROM owner_role o CROSS JOIN runtime_role r
    UNION ALL
    SELECT 'permissoes base', NOT EXISTS (
        SELECT * FROM expected_permissions EXCEPT SELECT perfil, permissao FROM public.auth_perfil_permissao
    )
)
SELECT coalesce(string_agg(name, ', ' ORDER BY name) FILTER (WHERE NOT coalesce(valid, false)), '1') FROM checks;
