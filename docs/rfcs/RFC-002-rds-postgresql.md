# RFC-002 — PostgreSQL no Amazon RDS

## Status
Aceito

## Contexto
O projeto necessita de banco relacional PostgreSQL compatível com o modelo existente e com operação simplificada em AWS.

## Decisão
Utilizar Amazon RDS for PostgreSQL 17 em subnets privadas, com armazenamento criptografado, backups automáticos e Parameter Group customizado.

O Parameter Group estabelece:
- TLS obrigatório com `rds.force_ssl = 1`;
- log de conexões e desconexões;
- log de statements cuja duração ultrapasse 1000 ms.

## Segurança
O banco não é público. O acesso é permitido preferencialmente pelo Security Group da aplicação. Enquanto o Security Group da aplicação não estiver disponível no ambiente, o módulo utiliza temporariamente o CIDR da VPC como fallback.

## Trade-offs
Single-AZ e classe `db.t4g.micro` foram escolhidos para o ambiente acadêmico por custo. Uma implantação de produção deveria avaliar Multi-AZ, deletion protection, Performance Insights, CloudWatch alarms e política de snapshots finais.
