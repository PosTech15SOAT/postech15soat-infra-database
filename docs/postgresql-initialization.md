# Inicialização do PostgreSQL dos serviços

O workflow manual `Initialize PostgreSQL` prepara `numberone_os`, `numberone_billing` e `numberone_inventory`, cada um com role e database de mesmo nome. Ele não executa migrations. Os serviços executam seu próprio Flyway; a migration do Inventory requer `pgcrypto`. As migrations legadas do monólito usam `uuid-ossp` e não fazem parte deste procedimento.

O runner consulta a AWS, lê em memória o secret master gerenciado pelo RDS e os três secrets de aplicação e cria no namespace existente `default` um ConfigMap com o script, um Secret Kubernetes temporário e um Job PostgreSQL 17. O Pod não recebe token de service account; conecta ao endpoint privado por TLS (`sslmode=require`). O Job cria os objetos quando todos estão ausentes, ou somente valida quando todos estão presentes. Objetos parcialmente criados causam falha e exigem análise humana. O runner coleta os logs e remove o Job, o Secret e o ConfigMap identificados pelo ID e tentativa da execução; o Job também tem TTL de uma hora após terminar. Não há exclusão automática de databases ou roles nem redefinição de senhas existentes.

`sslmode=require` cifra o tráfego, mas não valida a identidade do servidor. Uma implantação de produção deve distribuir a CA oficial do RDS e usar `verify-full`, identidade de curta duração, acesso privado ao endpoint Kubernetes, isolamento de namespace, criptografia de secrets, auditoria, gestão e rotação de credenciais, imagem fixada por digest e governança de mudanças. Este procedimento é destinado ao laboratório acadêmico.

## Pré-requisitos e ordem de provisionamento

1. Inicie o laboratório AWS Academy e configure a variável GitHub `AWS_ACCOUNT_ID` com os 12 dígitos da conta de destino em `us-east-1`. O workflow passa esse valor ao script e ambos recusam uma sessão de outra conta. Os nomes de cluster, RDS e secrets devem corresponder ao ambiente de destino.
2. Aplique a infraestrutura Cloud e depois Database, pelo fluxo normal, incluindo a inicialização dos três secrets de aplicação com `AWSCURRENT`, conforme [Fase 4](phase4.md). O RDS deve estar `available`, PostgreSQL 17, privado, na mesma VPC do EKS, e ter secret master gerenciado pelo RDS. Não modifique o Terraform Apply para executar este procedimento.
3. Confirme `numberone-eks` ativo e acesso do runner à API do EKS. A API pública pode restringir CIDRs; endpoints exclusivamente privados exigem runner com conectividade privada. O cluster atual possui namespace `default`; o namespace `numberone-production` mencionado no procedimento de túnel não existia na inspeção. Confirme o namespace e as políticas de acesso antes de rodar. O workflow usa `default` explicitamente.
4. Confirme que os nodes que podem receber o Job alcançam o RDS TCP 5432, incluindo security groups, rotas, NACLs, DNS e eventuais NetworkPolicies. O Terraform libera o security group do cluster EKS, mas isso não comprova o security group efetivamente usado pelo tráfego dos Pods ou a conectividade. O node precisa baixar `postgres:17` do registry.
5. Restrinja o acesso ao namespace `default` antes de executar: quem pode ler Secrets, criar Pods ou usar exec nesse namespace pode obter a credencial master durante a execução. Se isso não for aceitável, providencie um namespace administrativo isolado e autorizado e altere `NAMESPACE` no script; não execute até ele ter acesso de rede e RBAC necessários. O ServiceAccount do Pod não tem token montado. Restrições de admissão devem permitir o Job com a imagem e o UID configurados.

## GitHub e permissões

Disponibilize a este repositório os Organization Secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` e `AWS_SESSION_TOKEN` temporários da sessão Academy; o workflow os acessa diretamente via `secrets`. Não copie credenciais de banco para GitHub Secrets. Restrinja quem pode executar workflows e alterar `main` e atualize os três valores AWS quando a sessão expirar. O workflow só executa em `refs/heads/main` e serializa suas próprias execuções; isso não impede alterações concorrentes por outros administradores.

A identidade AWS precisa de `sts:GetCallerIdentity`, `eks:DescribeCluster`, `rds:DescribeDBInstances`, `secretsmanager:DescribeSecret` e `secretsmanager:GetSecretValue` nos três secrets e no ARN master retornado pelo RDS, além de `kms:Decrypt` quando necessário. O acesso ao Kubernetes exige mapeamento EKS e autorização efetiva: no namespace, `create/get/watch/delete` para Jobs, `create/delete` para Secrets e ConfigMaps, `get/list` de Pods e `get` em `pods/log`, além de leitura do namespace e das APIs de descoberta e autorização. `kubectl auth can-i` é verificado antes de buscar valores; concessões efetivas dependem do access entry/RBAC do cluster. Não conceda permissões amplas somente para executar o Job.

O script usa a credencial master para criar roles e databases. No PostgreSQL 17, concede temporariamente `SET` da role ao criador para atribuir ownership e revoga essa concessão depois de restringir o acesso público. A associação administrativa automática do criador, quando criada pelo PostgreSQL sem `SET` nem `INHERIT`, é aceita; nenhuma associação entre roles dos serviços é aceita. O master precisa conseguir criar roles, criar databases e executar essas concessões. As roles são donas de seus bancos e precisam de `CREATE` e `USAGE` no schema `public` para o Flyway.

## Executar e verificar

Publique as mudanças seguindo o fluxo de PR do repositório. Em **Actions → Initialize PostgreSQL → Run workflow**, selecione `main` e execute. Verifique o resultado e os logs do step `Initialize databases`: cada serviço deve aparecer como `Validado`, seguido de `Inicialização e validação concluídas`. Falhas de autenticação, ownership, ACL, membership, ausência de extensão ou conexão encerram o workflow com erro. Os logs não devem conter senhas ou connection strings. Não habilite `set -x` nem debug que exponha dados.

A validação confirma os nomes e owners, atributos e associações das roles, ACL das databases, conexão com as credenciais atuais dos secrets, ausência de `CONNECT` entre os três bancos, permissão no schema `public` e `pgcrypto` no Inventory. Ela não audita todos os bancos administrativos, configurações de default privileges ou objetos já criados por aplicações. Para uma inspeção independente sem consultar senhas, use uma sessão administrativa segura via [túnel](rds-port-forward.md) ou rede privada e execute:

```sql
SELECT datname, pg_get_userbyid(datdba) AS owner, datacl
FROM pg_database WHERE datname IN ('numberone_os','numberone_billing','numberone_inventory');
SELECT rolname, rolcanlogin, rolsuper, rolcreatedb, rolcreaterole
FROM pg_roles WHERE rolname IN ('numberone_os','numberone_billing','numberone_inventory');
-- Conectado a numberone_inventory:
SELECT extname FROM pg_extension WHERE extname = 'pgcrypto';
```

Repita o workflow para validar os recursos existentes: não atualiza senhas ou privilégios. Proteja o período da execução contra outros escritores; a verificação e a criação não são atômicas e `CREATE DATABASE` não pode participar da mesma transação. Uma falha durante a primeira execução pode deixar objetos parciais. Se todos os objetos existirem mas alguma validação falhar, a execução também para sem corrigi-los.

## Falhas e recuperação

Não execute comandos destrutivos nem redefina senha automaticamente. Examine o log e, com um administrador autorizado, inspecione `pg_roles`, `pg_database`, ownership, ACLs, memberships e `pg_extension`, sem expor secrets. Compare credenciais por teste de conexão seguro, sem imprimi-las. Decida e aplique manualmente a correção apropriada após análise; uma execução parcial com menos de seis objetos continuará falhando até o estado ser reconciliado. Preserve dados e coordene qualquer alteração de senha entre o banco e o secret. Uma vez que os seis objetos estejam completos e coerentes, repita o workflow para validação.

O Job tem prazo de dez minutos e não tenta novamente automaticamente. O runner remove somente recursos criados por aquela execução; falhas de limpeza são registradas. Em cancelamento abrupto ou perda do runner, o TTL remove apenas o Job concluído, não o Secret nem o ConfigMap. Um administrador deve localizar os nomes `pg-init-<run_id>-<run_attempt>` no namespace, verificar que pertencem à execução encerrada e excluir manualmente Job, Secret e ConfigMap. Não imprima o conteúdo do Secret. Nunca exclua recursos de outra execução.

- **Credenciais expiradas/conta errada:** renove os três Organization Secrets AWS e confira `sts get-caller-identity` na região correta.
- **IAM ou Secrets Manager:** confira as ações e escopos acima, `AWSCURRENT`, política do secret e KMS. O JSON deve conter `username` esperado e `password` não vazia, sem quebras de linha.
- **RBAC/API EKS:** verifique endpoint e allowlist do runner, access entry e `kubectl auth can-i` para cada ação. O acesso AWS não implica acesso Kubernetes.
- **Pod Pending ou imagem:** confira nodes, capacidade, admissão, DNS, registry e eventos do namespace. O Job e seus Pods podem ser removidos ao terminar; consulte eventos e logs da execução.
- **Conexão RDS:** confira estado, endpoint, TLS, regras de rede e security group efetivo dos nodes/Pods. O RDS não é público.
- **Permissões PostgreSQL:** confira capacidade do master, atributos, ownership, ACLs e memberships; uma divergência não é corrigida pelo workflow. Para outras falhas de execução, investigue o estado antes de repetir.
