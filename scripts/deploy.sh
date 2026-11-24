#!/usr/bin/env bash
# Deploy da API na EC2: troca o container pela imagem pedida (via AWS SSM, sem SSH) e confere o /health.
#
# Uso:       scripts/deploy.sh [imagem]   (padrão: ghcr.io/by-wagner/devops-na-pratica:latest)
# Rollback:  scripts/deploy.sh ghcr.io/by-wagner/devops-na-pratica:<sha-de-um-commit-anterior>
# Requer:    AWS CLI com credenciais do laboratório e a EC2 criada pelo Terraform (tag Name=devops-na-pratica-app).
set -euo pipefail

IMAGE="${1:-ghcr.io/by-wagner/devops-na-pratica:latest}"
PORT="${APP_PORT:-3000}"

read -r INSTANCE_ID PUBLIC_IP < <(aws ec2 describe-instances \
  --filters Name=tag:Name,Values=devops-na-pratica-app Name=instance-state-name,Values=running \
  --query 'Reservations[0].Instances[0].[InstanceId,PublicIpAddress]' --output text)
if [ "$INSTANCE_ID" = "None" ]; then
  echo "Nenhuma EC2 'devops-na-pratica-app' rodando. Crie com: cd infra && terraform apply" >&2
  exit 1
fi
echo "Deploy de $IMAGE em $INSTANCE_ID ($PUBLIC_IP)"

COMMAND_ID=$(aws ssm send-command --instance-ids "$INSTANCE_ID" \
  --document-name AWS-RunShellScript --comment "deploy da API" \
  --parameters "commands=[\"set -e\",\"docker pull $IMAGE\",\"docker rm -f api || true\",\"docker run -d --name api --restart unless-stopped -p $PORT:3000 $IMAGE\"]" \
  --query Command.CommandId --output text)

if ! aws ssm wait command-executed --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID"; then
  aws ssm get-command-invocation --command-id "$COMMAND_ID" --instance-id "$INSTANCE_ID" \
    --query StandardErrorContent --output text >&2
  exit 1
fi

# Smoke test: a nova versão precisa responder antes de o deploy ser considerado concluído.
for _ in $(seq 1 30); do
  if curl -fsS "http://$PUBLIC_IP:$PORT/health"; then
    echo && echo "Deploy concluído: http://$PUBLIC_IP:$PORT/health"
    exit 0
  fi
  sleep 2
done
echo "Smoke test falhou: /health não respondeu 200 em 60 s" >&2
exit 1
