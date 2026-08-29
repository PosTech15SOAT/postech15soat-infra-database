# RFC-001 — Repositório dedicado para infraestrutura do banco

## Status
Aceito

## Contexto
A infraestrutura de aplicação, cluster e banco estava concentrada no mesmo projeto Terraform, aumentando o acoplamento entre ciclos de mudança distintos.

## Decisão
Manter a infraestrutura do banco em `PosTech15SOAT-Infra-Banco`, com state Terraform independente. A VPC não será duplicada; seus identificadores serão consumidos do state da infraestrutura existente.

## Consequências

### Positivas
- ciclo de vida independente do RDS;
- menor blast radius nas mudanças;
- pipeline e permissões específicas para banco;
- documentação e ownership mais claros.

### Negativas
- dependência temporária do state monolítico da infraestrutura principal;
- necessidade de governar contratos entre outputs Terraform.

## Evolução
Recomenda-se futuramente separar a rede compartilhada em state/repositório próprio, consumido tanto pela aplicação quanto pelo banco.
