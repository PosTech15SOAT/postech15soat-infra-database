#!/usr/bin/env bash
set -Eeuo pipefail
set +x
export PGHOST="$RDS_HOST" PGPORT="$RDS_PORT" PGSSLMODE=require PGCONNECT_TIMEOUT=10
master_username=$(cat /credentials/master-username)
PGUSER=$master_username
PGPASSWORD=$(cat /credentials/master-password)
export PGUSER PGPASSWORD
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
admin_psql() { psql -X -qAt -w -v ON_ERROR_STOP=1 -d postgres "$@"; }
fail() { echo "ERRO Auth: $*" >&2; exit 1; }

count=$(admin_psql -c "SELECT (SELECT count(*) FROM pg_roles WHERE rolname IN ('numberone_auth_owner','numberone_auth_runtime')) + (SELECT count(*) FROM pg_database WHERE datname = 'numberone_auth');")
case "$count" in
  0)
    echo 'Criando banco, roles e estrutura do Auth.'
    # O SQL de referência concede SET ROLE ao master. Revogar também em falhas.
    cleanup_owner() {
      admin_psql -c 'SET client_min_messages TO error' -c 'REVOKE numberone_auth_owner FROM CURRENT_USER' >/dev/null
    }
    trap cleanup_owner EXIT
    admin_psql -f "$script_dir/auth/db/phase4/bootstrap.psql" >/dev/null
    # \password cifra no cliente; o plaintext não entra no SQL nem no argv.
    password=$(cat /credentials/numberone_auth_runtime)
    printf '%s\n%s\n' "$password" "$password" |
      admin_psql -c '\password numberone_auth_runtime' >/dev/null
    unset password
    cleanup_owner
    trap - EXIT
    ;;
  3) echo 'Auth existente: validando sem alterar senha, grants ou dados.' ;;
  *) fail 'Estado parcial de roles/database; inspecione antes de retomar.' ;;
esac

password=$(cat /credentials/numberone_auth_runtime)
valid=$(PGUSER=numberone_auth_runtime PGPASSWORD="$password" \
  psql -X -qAt -w -v ON_ERROR_STOP=1 -d numberone_auth \
    -v master_username="$master_username" -f "$script_dir/auth-validate.sql" \
    -c 'SELECT 1 FROM public.auth_usuario LIMIT 0' \
    -c 'SELECT 1 FROM public.auth_perfil_permissao LIMIT 0') || fail 'Autenticação ou SELECT runtime falhou; a senha não foi redefinida.'
unset password
[[ "$valid" == 1 ]] || fail "Validação divergente: $valid"
echo 'Validado: numberone_auth (owner separado, runtime somente leitura).'
