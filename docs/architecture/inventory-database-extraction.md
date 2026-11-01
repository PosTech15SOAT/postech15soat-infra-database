# Extração do Inventory DB

## Decisão
Repositório único `postech15soat-infra-database`; uma instância RDS, databases independentes por serviço. Inventory possui `inventory_db`, sem acesso SQL a outros databases.

## Fronteira
Inventory: `item_estoque`, `movimentacao_estoque`, `reserva_estoque`, `reserva_estoque_item`, `processed_message`, `outbox_event`.
OS: `ordem_servico_servico_item` continua no banco de OS, com `id_item_estoque` como UUID externo, sem FK cruzada.

## Migração segura
1. Backup consistente e interrupção controlada de gravações ou captura de alterações.
2. Auditar nulos e duplicatas: V1 do monólito permite campos nulos que as entidades JPA exigem.
3. Criar `inventory_db` e usuário de acesso exclusivo, provisionados por SQL com acesso privado ao RDS.
4. Aplicar V1 e V2 via Flyway somente em `inventory_db` vazio.
5. Copiar itens e depois movimentos, preservando UUIDs.
6. Comparar contagens, IDs e saldos; verificar referências de OS.
7. Trocar consumidores para o novo serviço, validar, e somente depois remover FKs e tabelas legadas por migration separada.

## Consultas de auditoria na origem
```sql
SELECT codigo,COUNT(*) FROM item_estoque GROUP BY codigo HAVING COUNT(*)>1;
SELECT COUNT(*) FROM item_estoque WHERE codigo IS NULL OR custo_unitario IS NULL OR preco_venda IS NULL OR created_at IS NULL OR updated_at IS NULL;
SELECT COUNT(*) FROM movimentacao_estoque WHERE origem_movimentacao IS NULL OR quantidade_antes IS NULL OR quantidade_depois IS NULL OR usuario_responsavel_id IS NULL;
SELECT COUNT(*) FROM movimentacao_estoque m LEFT JOIN item_estoque i ON i.id=m.id_item_estoque WHERE i.id IS NULL;
```

## Pendências de aplicação
`InventoryMovementService` precisa de transação e controle de concorrência; reserva deve bloquear linhas de estoque e calcular saldo disponível. Outbox e deduplicação precisam ser gravadas na mesma transação do comando. O SQL sozinho não garante isso. Migrations no repositório central precisam ser distribuídas ao artefato/pipeline do Inventory Service.

## Terraform
O módulo atual `aws_db_instance` cria um database inicial. Databases adicionais e usuários serão provisionados via SQL por processo separado, em rede com acesso privado ao RDS. Não executar `CREATE DATABASE` no Flyway do Inventory.
