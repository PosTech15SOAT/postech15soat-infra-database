# Túnel local para o RDS PostgreSQL

O RDS é privado. Para acesso administrativo local, abra um túnel pelo EKS, com permissões AWS e Kubernetes apropriadas. O script cria e remove o pod `postgres-tunnel`; confirme antes que esse nome não está em uso no namespace. Ele também atualiza o kubeconfig local.

O script contém valores padrão históricos. Informe explicitamente o cluster atual, o namespace existente autorizado a acessar o RDS e o endpoint atual:

```sh
RDS_ENDPOINT="$(aws rds describe-db-instances --region us-east-1 --db-instance-identifier numberone-postgres --query 'DBInstances[0].Endpoint.Address' --output text)" \
EKS_CLUSTER_NAME=numberone-eks KUBE_NAMESPACE=numberone-production LOCAL_PORT=15432 \
./scripts/rds-port-forward.sh
```

Confirme o namespace antes de executar; mantenha o processo aberto e encerre com Ctrl+C. Em outro terminal, configure o cliente para usar `127.0.0.1:15432`, database `postgres` e usuário master `numberone_admin`. A credencial master é gerenciada pelo RDS no Secrets Manager; obtenha-a de forma segura, sem imprimi-la em logs ou colocá-la em argumentos ou histórico.

Para autenticar a identidade do servidor através do túnel, configure a CA oficial do RDS e `sslmode=verify-full`, usando o endpoint real como `host` e `127.0.0.1` como `hostaddr` no libpq. Consulte o [procedimento da Fase 4](phase4.md) antes de criar os bancos e roles.
