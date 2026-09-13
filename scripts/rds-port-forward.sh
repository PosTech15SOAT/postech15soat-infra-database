#!/usr/bin/env sh
set -eu

AWS_REGION="${AWS_REGION:-us-east-1}"
EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-numberone-lab-eks}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-numberone-production}"
RDS_ENDPOINT="${RDS_ENDPOINT:-numberone-lab-postgres.c5yky0sc2omt.us-east-1.rds.amazonaws.com}"
RDS_PORT="${RDS_PORT:-5432}"
LOCAL_PORT="${LOCAL_PORT:-5432}"
POD_NAME="${POD_NAME:-postgres-tunnel}"

cleanup() {
  kubectl delete pod "${POD_NAME}" -n "${KUBE_NAMESPACE}" --ignore-not-found=true >/dev/null 2>&1 || true
}

trap cleanup INT TERM EXIT

echo "Atualizando kubeconfig do cluster ${EKS_CLUSTER_NAME} (${AWS_REGION})..."
aws eks update-kubeconfig \
  --region "${AWS_REGION}" \
  --name "${EKS_CLUSTER_NAME}"

echo "Recriando pod de tunel ${POD_NAME} no namespace ${KUBE_NAMESPACE}..."
kubectl delete pod "${POD_NAME}" -n "${KUBE_NAMESPACE}" --ignore-not-found=true >/dev/null

kubectl run "${POD_NAME}" \
  -n "${KUBE_NAMESPACE}" \
  --image=alpine/socat \
  --restart=Never \
  -- \
  "tcp-listen:${RDS_PORT},fork,reuseaddr" \
  "tcp-connect:${RDS_ENDPOINT}:${RDS_PORT}"

echo "Aguardando o pod ficar pronto..."
kubectl wait \
  --for=condition=Ready \
  "pod/${POD_NAME}" \
  -n "${KUBE_NAMESPACE}" \
  --timeout=90s

echo "Tunel ativo: localhost:${LOCAL_PORT} -> ${RDS_ENDPOINT}:${RDS_PORT}"
echo "Configure o DBeaver com host localhost, porta ${LOCAL_PORT}, database numberone e usuario numberone_admin."
echo "Mantenha este processo aberto enquanto usa o banco. Ctrl+C encerra o tunel e remove o pod."

kubectl port-forward \
  -n "${KUBE_NAMESPACE}" \
  "pod/${POD_NAME}" \
  "${LOCAL_PORT}:${RDS_PORT}"
