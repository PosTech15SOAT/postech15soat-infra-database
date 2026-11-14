# Persistência · Arquitetura da Fase 4

Database define a infraestrutura PostgreSQL compartilhada. A segmentação por banco lógico e credencial mantém propriedade por serviço, inclusive quando os bancos usam a mesma instância física do RDS.

| Dono | Banco lógico de entrega | Conteúdo |
| --- | --- | --- |
| OS | `numberone_os` | Cadastros, componentes da OS, Saga, inbox e outbox do histórico. |
| Billing | `numberone_billing` | Orçamento, checkout, cobrança, eventos e fechamento comercial. |
| Inventory | `numberone_inventory` | Catálogo, saldo, movimentos, tentativas e compensações. |
| OS | Tabela DynamoDB a provisionar | Projeção de manutenção veicular com `vehicleId` e `historyKey`. |

## Fonte de infraestrutura e migrations

Em `develop` (`2de2cef`), a raiz Terraform é a usada pelos workflows. Ela lê os outputs de VPC, subnets privadas e security group de Cloud via state remoto e instancia RDS privado. O módulo controla rede, armazenamento, credencial master e configuração de banco. O código publicado dessa raiz ainda não comprova a criação e os grants dos três bancos lógicos na conta da Fase 4.

As branches `feature/billing-secrets` e `feature/inventory-db-isolation` têm alterações específicas fora de `develop`. Conferir com Marcelo quais serão incorporadas e qual procedimento cria banco, usuário, privilégios e versões no Secrets Manager. O DER existente serve de referência da Fase 3.

Flyway roda na aplicação proprietária. O pipeline de deploy do app deve receber usuário exclusivo com acesso ao próprio banco. O master fica reservado à administração. Auth na revisão publicada ainda consulta `cliente` e tabelas RBAC no PostgreSQL configurado. O desenho da Fase 4 precisa definir a fonte de identidade e o acesso ao cadastro sem dar a Auth leitura cruzada do banco exclusivo da OS.

## Aceite

Comprovar bancos/usuários e rede real, execução independente das migrations, falha ao autenticar com a credencial de outro serviço e recuperação conforme a política de backup. Confirmar com Cloud o responsável pelo provisionamento da tabela DynamoDB. Publicar resultados sem nomes de credenciais, senhas ou valores de secrets.

[Raiz Terraform](../main.tf) · [Outputs](../outputs.tf) · [DER existente](architecture/database-der.md) · [Plan](../.github/workflows/terraform-plan.yml) · [Apply](../.github/workflows/terraform-apply.yml)
