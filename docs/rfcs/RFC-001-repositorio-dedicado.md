# RFC-001 — Repositório dedicado para infraestrutura do banco

## Status
Aceito

## Contexto
A infraestrutura de aplicação, cluster e banco estava concentrada no mesmo projeto Terraform, aumentando o acoplamento entre ciclos de mudança distintos.

## Decisão

Manter a infraestrutura do banco em um repositório dedicado, com state Terraform independente.

A VPC não será duplicada. O identificador da VPC, as subnets privadas e o Security Group do EKS serão consumidos do remote state do repositório `postech15soat-infra-cloud`.

## Consequências

### Positivas
- ciclo de vida independente do RDS;
- menor blast radius nas mudanças;
- pipeline e permissões específicas para banco;
- documentação e ownership mais claros.

### Negativas

- necessidade de manter o contrato de outputs do remote state da infraestrutura cloud;
- necessidade de manter o contrato de conectividade entre aplicação e banco.

## Evolução
Avaliar futuramente políticas formais de versionamento de contrato entre os states de infraestrutura, caso mais repositórios passem a consumir outputs compartilhados.
