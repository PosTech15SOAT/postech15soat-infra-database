# RFC-002 — PostgreSQL no Amazon RDS

## Status
Aceito

## Contexto
O projeto NumberOne possui domínio transacional com entidades relacionadas, constraints de integridade e necessidade de consistência entre clientes, veículos, serviços, estoque, orçamentos e ordens de serviço.

O ecossistema da aplicação utiliza Spring Boot/JPA e se beneficia de um banco relacional maduro, com bom suporte a SQL, chaves estrangeiras, transações e integração gerenciada na AWS.

## Decisão
Utilizar Amazon RDS for PostgreSQL 17 em subnets privadas, com armazenamento criptografado, backups automáticos e Parameter Group customizado.

PostgreSQL foi escolhido por:

- adequação a modelos relacionais com entidades e relacionamentos explícitos;
- suporte a consistência transacional;
- suporte a constraints, chaves primárias, chaves estrangeiras, índices e integridade referencial;
- compatibilidade direta com Spring/JPA;
- disponibilidade como serviço gerenciado no Amazon RDS;
- maturidade e ecossistema amplamente adotados.

O Parameter Group estabelece:
- TLS obrigatório com `rds.force_ssl = 1`;
- log de conexões e desconexões;
- log de statements cuja duração ultrapasse 1000 ms.

## Segurança
O banco não é público. No root module atual, o acesso é permitido pelo Security Group do EKS consumido do remote state do `postech15soat-infra-cloud`.

O módulo RDS mantém fallback por CIDR da VPC apenas para o caso de `application_security_group_id` ser `null`, mas essa não é a configuração ativa esperada pelo root module atual.

## Trade-offs
Single-AZ e classe `db.t4g.micro` foram escolhidos para o ambiente acadêmico por custo. Uma implantação de produção deveria avaliar Multi-AZ, deletion protection, Performance Insights, CloudWatch alarms e política de snapshots finais.
