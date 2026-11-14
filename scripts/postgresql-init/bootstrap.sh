#!/usr/bin/env bash
set -Eeuo pipefail
set +x
export PGHOST="$RDS_HOST" PGPORT="$RDS_PORT" PGSSLMODE=require PGCONNECT_TIMEOUT=10
export PGUSER="$(cat /credentials/master-username)" PGPASSWORD="$(cat /credentials/master-password)"
roles=(numberone_os numberone_billing numberone_inventory)
admin_psql() { psql -X -qAt -w -v ON_ERROR_STOP=1 -d postgres "$@"; }
fail() { echo "ERRO: $*" >&2; exit 1; }

# A mistura de objetos existentes e ausentes exige inspeção humana.
count=$(admin_psql -c "SELECT (SELECT count(*) FROM pg_roles WHERE rolname IN ('numberone_os','numberone_billing','numberone_inventory')) + (SELECT count(*) FROM pg_database WHERE datname IN ('numberone_os','numberone_billing','numberone_inventory')); ")
case "$count" in
  0)
    for role in "${roles[@]}"; do
      echo "Criando role e database: $role"
      admin_psql -c "CREATE ROLE $role LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS"
      # psql cifra a senha antes de enviá-la; não passa senha em argv ou SQL.
      password=$(cat "/credentials/$role")
      printf '%s\n%s\n' "$password" "$password" | psql -X -q -w -d postgres -c "\\password $role" >/dev/null
      unset password
      # PostgreSQL 16+ exige SET ROLE para atribuir outro proprietário.
      printf "%s\n" "SELECT format('GRANT %I TO %I WITH SET TRUE', :'role', current_user) \gexec" | admin_psql -v role="$role"
      admin_psql -c "CREATE DATABASE $role OWNER $role"
      admin_psql -c "REVOKE CONNECT, TEMPORARY ON DATABASE $role FROM PUBLIC"
      printf "%s\n" 'SET client_min_messages TO error;' "SELECT format('REVOKE %I FROM %I', :'role', current_user) \gexec" | admin_psql -v role="$role"
    done
    PGPASSWORD="$(cat /credentials/numberone_inventory)" PGUSER=numberone_inventory psql -X -q -w -v ON_ERROR_STOP=1 -d numberone_inventory -c 'CREATE EXTENSION IF NOT EXISTS pgcrypto' >/dev/null
    ;;
  6) echo 'Objetos existentes: validando sem alterá-los.' ;;
  *) fail 'Estado parcial detectado; não houve alteração nesta execução. Inspecione os objetos antes de retomar.' ;;
esac

for role in "${roles[@]}"; do
  valid=$(admin_psql -v role="$role" <<'SQL'
SELECT (r.rolcanlogin AND NOT r.rolsuper AND NOT r.rolcreatedb AND NOT r.rolcreaterole AND NOT r.rolreplication AND NOT r.rolbypassrls
  AND d.datdba = r.oid AND d.datallowconn
  AND NOT EXISTS (SELECT 1 FROM pg_auth_members m WHERE m.member = r.oid OR (m.roleid = r.oid AND (m.member <> (SELECT oid FROM pg_roles WHERE rolname = current_user) OR m.set_option OR m.inherit_option)))
  AND NOT EXISTS (SELECT 1 FROM aclexplode(coalesce(d.datacl, acldefault('d', d.datdba))) a WHERE a.grantee <> r.oid)
)::int FROM pg_roles r JOIN pg_database d ON d.datname = r.rolname WHERE r.rolname = :'role';
SQL
)
  [[ "$valid" == 1 ]] || fail "Ownership, atributos, membership ou privilégios divergentes: $role"
  app_password=$(cat "/credentials/$role")
  schema_ok=$(PGUSER="$role" PGPASSWORD="$app_password" psql -X -qAt -w -v ON_ERROR_STOP=1 -d "$role" -c "SELECT (has_schema_privilege(current_user, 'public', 'CREATE') AND has_schema_privilege(current_user, 'public', 'USAGE'))::int") || fail "Autenticação ou conexão falhou: $role"
  [[ "$schema_ok" == 1 ]] || fail "Permissões do schema public divergentes: $role"
  for other in "${roles[@]}"; do
    [[ "$role" == "$other" ]] && continue
    access=$(printf "%s\n" "SELECT has_database_privilege(:'role', :'db', 'CONNECT')::int;" | admin_psql -v role="$role" -v db="$other")
    [[ "$access" == 0 ]] || fail "Acesso entre databases detectado: $role"
  done
  unset app_password
  echo "Validado: $role"
done
extension=$(PGUSER=numberone_inventory PGPASSWORD="$(cat /credentials/numberone_inventory)" psql -X -qAt -w -v ON_ERROR_STOP=1 -d numberone_inventory -c "SELECT count(*) FROM pg_extension WHERE extname='pgcrypto'")
[[ "$extension" == 1 ]] || fail 'Extensão pgcrypto ausente no Inventory.'
echo 'Inicialização e validação concluídas.'
