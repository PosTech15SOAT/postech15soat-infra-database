# Tunel local para o RDS PostgreSQL

O RDS PostgreSQL deste projeto nao possui acesso publico. Para conectar ferramentas locais como DBeaver, DataGrip ou similares, crie um tunel atraves do cluster EKS.

## Uso rapido

Execute:

```sh
./scripts/rds-port-forward.sh
```

Enquanto o script estiver aberto, configure a conexao no DBeaver:

| Campo | Valor |
|---|---|
| Host | `localhost` |
| Port | `5432` |
| Database | `numberone` |
| Username | `numberone_admin` |
| SSL | habilitado/preferido |

A senha master fica no AWS Secrets Manager, gerenciada pelo RDS. Para descobrir o ARN do secret:

```sh
terraform output rds_master_secret_arn
```

Se o Terraform ocultar o valor sensivel, use:

```sh
terraform output -raw rds_master_secret_arn
```

Depois consulte o secret na AWS:

```sh
aws secretsmanager get-secret-value \
  --region us-east-1 \
  --secret-id "$(terraform output -raw rds_master_secret_arn)" \
  --query SecretString \
  --output text
```

## Variaveis do script

O script ja vem com os valores do ambiente atual:

```text
AWS_REGION=us-east-1
EKS_CLUSTER_NAME=numberone-lab-eks
KUBE_NAMESPACE=numberone-production
RDS_ENDPOINT=numberone-lab-postgres.c5yky0sc2omt.us-east-1.rds.amazonaws.com
RDS_PORT=5432
LOCAL_PORT=5432
POD_NAME=postgres-tunnel
```

Para trocar a porta local, por exemplo quando a `5432` ja estiver em uso:

```sh
LOCAL_PORT=15432 ./scripts/rds-port-forward.sh
```

Nesse caso, use `localhost:15432` no DBeaver.

## Comandos manuais

Liste os clusters EKS:

```sh
aws eks list-clusters \
  --region us-east-1 \
  --output table
```

Atualize o kubeconfig:

```sh
aws eks update-kubeconfig \
  --region us-east-1 \
  --name numberone-lab-eks
```

Crie o pod que encaminha trafego para o RDS:

```sh
kubectl run postgres-tunnel \
  -n numberone-production \
  --image=alpine/socat \
  --restart=Never \
  -- \
  tcp-listen:5432,fork,reuseaddr \
  tcp-connect:numberone-lab-postgres.c5yky0sc2omt.us-east-1.rds.amazonaws.com:5432
```

Confira o pod:

```sh
kubectl get pods -n numberone-production
```

Abra o port-forward local:

```sh
kubectl port-forward \
  -n numberone-production \
  pod/postgres-tunnel \
  5432:5432
```

Quando terminar, remova o pod:

```sh
kubectl delete pod postgres-tunnel -n numberone-production
```
