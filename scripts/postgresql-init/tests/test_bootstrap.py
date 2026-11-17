"""SQL integration tests; require an explicitly supplied, disposable local container.

Set POSTGRESQL_TEST_CONTAINER only for a PostgreSQL 17 container with
cluster_name=numberone-bootstrap-test and /bootstrap mounted from this repository.
The tests reset databases/roles inside that container. They never connect to AWS.
"""
import hashlib
import os
import subprocess
import unittest

CONTAINER = os.environ.get('POSTGRESQL_TEST_CONTAINER')
DATABASES = ['numberone_auth', 'numberone_os', 'numberone_billing', 'numberone_inventory']
ROLES = ['numberone_auth_runtime', 'numberone_auth_owner', *DATABASES[1:]]


@unittest.skipUnless(CONTAINER, 'requires an explicitly supplied disposable local PostgreSQL 17 container')
class BootstrapIntegrationTest(unittest.TestCase):
    @classmethod
    def execute(cls, *args, data=None, check=True):
        return subprocess.run(['docker', 'exec', '-i', CONTAINER, *args], input=data,
                              text=True, capture_output=True, check=check)

    @classmethod
    def sql(cls, query, database='postgres'):
        return cls.execute('psql', '-X', '-qAt', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1',
                           '-d', database, data=query).stdout.strip()

    @classmethod
    def setUpClass(cls):
        if cls.sql('SHOW cluster_name') != 'numberone-bootstrap-test':
            raise RuntimeError('Refusing to reset a container without the disposable test marker')
        if not cls.sql('SHOW server_version').startswith('17.'):
            raise RuntimeError('Tests require PostgreSQL 17')
        if cls.sql("SELECT bool_and(auth_method = 'scram-sha-256') FROM pg_hba_file_rules WHERE type LIKE 'host%'") != 't':
            raise RuntimeError('Tests require SCRAM authentication, including loopback connections')

    def setUp(self):
        # Only the marked local fixture is ever reset.
        for database in DATABASES:
            self.sql(f'DROP DATABASE IF EXISTS {database} WITH (FORCE)')
        for role in ROLES:
            self.sql(f'DROP ROLE IF EXISTS {role}')
        if not self.sql("SELECT 1 FROM pg_roles WHERE rolname = 'test_master'"):
            self.sql("CREATE ROLE test_master LOGIN CREATEROLE CREATEDB PASSWORD 'local-master-fixture'")
        credentials = {'master-username': 'test_master', 'master-password': 'local-master-fixture',
                       **{role: 'local-' + role + '-fixture' for role in ROLES if role != 'numberone_auth_owner'}}
        self.execute('mkdir', '-p', '/credentials')
        for name, value in credentials.items():
            self.execute('sh', '-c', 'cat > /credentials/' + name, data=value)

    def bootstrap(self, script='auth-bootstrap.sh', succeeds=True):
        result = self.execute('env', 'RDS_HOST=127.0.0.1', 'RDS_PORT=5432',
                              'bash', '/bootstrap/' + script, check=False)
        if succeeds:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, 'Expected bootstrap to reject the divergent fixture')
        return result

    def snapshot(self):
        # Compare hashes so assertion output cannot expose password verifiers or data.
        content = self.sql("SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolcanlogin, rolpassword "
                           "FROM pg_authid ORDER BY rolname")
        content += self.sql('SELECT roleid, member, grantor, admin_option, inherit_option, set_option '
                            'FROM pg_auth_members ORDER BY roleid, member, grantor')
        content += self.sql('SELECT datname, datdba, datacl FROM pg_database ORDER BY datname')
        for database in DATABASES:
            if self.sql(f"SELECT 1 FROM pg_database WHERE datname = '{database}'"):
                content += self.execute('pg_dump', '-U', 'postgres', '-d', database).stdout
        # PostgreSQL 17 emits a new random \restrict key on every dump.
        stable = '\n'.join(line for line in content.splitlines()
                           if not line.startswith(('\\restrict ', '\\unrestrict ')))
        return hashlib.sha256(stable.encode()).hexdigest()

    def test_first_run_and_rerun_preserve_all_credentials_and_data(self):
        self.bootstrap('bootstrap.sh')
        self.bootstrap()
        self.assertEqual(self.sql('SELECT count(*) FROM auth_usuario', 'numberone_auth'), '0')
        self.assertEqual(self.sql('SELECT count(*) FROM auth_perfil', 'numberone_auth'), '2')
        self.assertEqual(self.sql('SELECT count(*) FROM auth_perfil_permissao', 'numberone_auth'), '12')
        for database in DATABASES[1:]:
            self.sql('CREATE TABLE preserved_fixture (id integer PRIMARY KEY); INSERT INTO preserved_fixture VALUES (1)', database)
        self.sql("INSERT INTO auth_perfil_permissao VALUES ('CUSTOMER', 'PRESERVED_PERMISSION')", 'numberone_auth')
        before = self.snapshot()
        self.bootstrap('bootstrap.sh')
        self.bootstrap()
        self.assertEqual(before, self.snapshot(), 'Rerun changed passwords, schema, privileges or data')

    def test_partial_roles_are_rejected_without_changes(self):
        self.sql('CREATE ROLE numberone_auth_owner NOLOGIN')
        before = self.snapshot()
        result = self.bootstrap(succeeds=False)
        self.assertIn('Estado parcial', result.stderr)
        self.assertEqual(before, self.snapshot())

    def test_incomplete_schema_is_rejected_without_rebuilding(self):
        self.bootstrap()
        self.sql('DROP TABLE auth_usuario', 'numberone_auth')
        before = self.snapshot()
        self.bootstrap(succeeds=False)
        self.assertEqual(before, self.snapshot())

    def test_wrong_current_password_is_rejected_without_reset(self):
        self.bootstrap()
        self.execute('sh', '-c', 'cat > /credentials/numberone_auth_runtime', data='wrong-local-fixture')
        before = self.snapshot()
        result = self.bootstrap(succeeds=False)
        self.assertIn('Autenticação', result.stderr)
        self.assertEqual(before, self.snapshot())

    def test_divergent_structure_ownership_and_grants_are_rejected_without_repair(self):
        self.bootstrap('bootstrap.sh')
        cases = [
            ('postgres', 'ALTER ROLE numberone_auth_runtime CREATEDB'),
            ('postgres', 'GRANT numberone_auth_owner TO numberone_auth_runtime'),
            ('postgres', 'ALTER DATABASE numberone_auth OWNER TO numberone_auth_runtime'),
            ('postgres', 'GRANT CONNECT ON DATABASE numberone_auth TO PUBLIC'),
            ('postgres', 'GRANT CONNECT ON DATABASE numberone_os TO numberone_auth_runtime'),
            ('numberone_auth', 'GRANT CREATE ON SCHEMA public TO numberone_auth_runtime'),
            ('numberone_auth', 'GRANT INSERT ON auth_usuario TO numberone_auth_runtime'),
            ('numberone_auth', 'GRANT SELECT ON auth_perfil TO numberone_auth_runtime'),
            ('numberone_auth', 'GRANT SELECT ON auth_usuario TO numberone_auth_runtime WITH GRANT OPTION'),
            ('numberone_auth', 'GRANT SELECT (nome) ON auth_perfil TO numberone_auth_runtime'),
            ('numberone_auth', 'ALTER TABLE auth_usuario OWNER TO numberone_auth_runtime'),
            ('numberone_auth', 'ALTER TABLE auth_usuario ADD COLUMN unexpected text'),
            ('numberone_auth', 'ALTER TABLE auth_usuario DROP CONSTRAINT auth_cliente_obrigatorio'),
            ('numberone_auth', 'ALTER TABLE auth_usuario ALTER COLUMN ativo SET DEFAULT false'),
            ('numberone_auth', 'ALTER DEFAULT PRIVILEGES FOR ROLE numberone_auth_owner GRANT INSERT ON TABLES TO numberone_auth_runtime'),
            ('numberone_auth', "DELETE FROM auth_perfil_permissao WHERE permissao = 'ADMIN_ACCESS'"),
        ]
        for database, query in cases:
            with self.subTest(query=query):
                # Start each case with an independently bootstrapped Auth database.
                self.sql('DROP DATABASE IF EXISTS numberone_auth WITH (FORCE)')
                if self.sql("SELECT 1 FROM pg_roles WHERE rolname = 'numberone_auth_runtime'"):
                    self.sql('DROP OWNED BY numberone_auth_runtime')
                self.sql('DROP ROLE IF EXISTS numberone_auth_runtime; DROP ROLE IF EXISTS numberone_auth_owner')
                self.bootstrap()
                self.sql(query, database)
                before = self.snapshot()
                self.bootstrap(succeeds=False)
                self.assertEqual(before, self.snapshot(), 'Failure path changed the divergent fixture')


if __name__ == '__main__':
    unittest.main()
