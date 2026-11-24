#!/usr/bin/env bash
# Deploy da API num cluster Kubernetes e demonstração da orquestração:
#   1. aplica os manifests de k8s/ (2 réplicas + Service);
#   2. troca para a imagem pedida com rolling update e espera o rollout;
#   3. apaga um pod de propósito e confere que o Kubernetes recria (autocura);
#   4. smoke test do /health através do Service.
#
# Uso:      scripts/k8s-deploy.sh <imagem>
# Requer:   kubectl apontando para um cluster (no CI: kind) com acesso à imagem.
set -euo pipefail

IMAGE="${1:?Informe a imagem, ex.: scripts/k8s-deploy.sh ghcr.io/by-wagner/devops-na-pratica:<sha>}"

echo "== 1. Aplicando os manifests"
kubectl apply -f k8s/
kubectl rollout status deployment/api --timeout=120s

echo "== 2. Rolling update para $IMAGE"
kubectl set image deployment/api api="$IMAGE"
kubectl rollout status deployment/api --timeout=120s
kubectl get pods -l app=api -o wide

echo "== 3. Autocura: apagando um pod"
victim=$(kubectl get pods -l app=api -o jsonpath='{.items[0].metadata.name}')
kubectl delete pod "$victim" --wait=false
for _ in $(seq 1 60); do
  ready=$(kubectl get deployment api -o jsonpath='{.status.readyReplicas}')
  if [ "${ready:-0}" = "2" ] && ! kubectl get pod "$victim" >/dev/null 2>&1; then
    echo "Pod $victim removido e substituído; 2/2 réplicas prontas"
    break
  fi
  sleep 2
done
[ "${ready:-0}" = "2" ] || { echo "Kubernetes não recriou o pod em 120 s" >&2; exit 1; }
kubectl get pods -l app=api

echo "== 4. Smoke test pelo Service"
kubectl port-forward service/api 8080:80 >/dev/null &
trap 'kill $! 2>/dev/null || true' EXIT
for _ in $(seq 1 15); do
  if curl -fsS localhost:8080/health; then
    echo && echo "Orquestração OK: $IMAGE rodando com 2 réplicas"
    exit 0
  fi
  sleep 1
done
echo "Smoke test falhou: /health não respondeu pelo Service" >&2
exit 1
