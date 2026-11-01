-- Execute conectado ao banco inventory_db, com usuario administrador.
-- Substitua a senha de exemplo por uma senha forte e unica ANTES de executar.
-- Nao comite uma senha real neste arquivo.
CREATE ROLE inventory_user LOGIN PASSWORD 'REPLACE_WITH_STRONG_SECRET';

GRANT CONNECT ON DATABASE inventory_db TO inventory_user;
GRANT USAGE, CREATE ON SCHEMA public TO inventory_user;
-- Flyway executado como inventory_user podera criar e manter suas tabelas.
-- Nao conceda privilegios em outros bancos ao inventory_user.
