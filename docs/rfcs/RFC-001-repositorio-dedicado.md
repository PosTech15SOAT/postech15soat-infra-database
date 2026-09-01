# RFC-001 — Repositório dedicado para infraestrutura do banco

## Status
Aceito

## Contexto
A infraestrutura de aplicação, cluster e banco estava concentrada no mesmo projeto Terraform, aumentando o acoplamento entre ciclos de mudança distintos.

## Decisão

Manter a infraestrutura do banco em um repositório dedicado, com state Terraform independente.

A VPC não será duplicada. O identificador da VPC e das subnets existentes serão fornecidos à infraestrutura do banco através de variáveis Terraform.

## Consequências

### Positivas
- ciclo de vida independente do RDS;
- menor blast radius nas mudanças;
- pipeline e permissões específicas para banco;
- documentação e ownership mais claros.

### Negativas

- necessidade de fornecer corretamente os identificadores da infraestrutura de rede existente;
- necessidade de manter o contrato de conectividade entre aplicação e banco.

## Evolução
Recomenda-se futuramente separar a rede compartilhada em state/repositório próprio, consumido tanto pela aplicação quanto pelo banco.
