#!/usr/bin/env bash
# Usage: deploy.sh <container-name> <host-port> <image-tag>
# Needs env vars: REGION, IID
set -euo pipefail
NAME="$1"; PORT="$2"; TAG="$3"

ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
IMAGE="$REGISTRY/cicd-practice:$TAG"
echo "Deploying $IMAGE as '$NAME' on port $PORT"

jq -n --arg reg "$REGISTRY" --arg img "$IMAGE" --arg region "$REGION" \
      --arg name "$NAME" --arg port "$PORT" '{commands: [
  "set -e",
  "aws ecr get-login-password --region \($region) | docker login --username AWS --password-stdin \($reg)",
  "docker pull \($img)",
  "docker rm -f \($name) || true",
  "docker run -d --restart unless-stopped -p \($port):8000 --name \($name) \($img)",
  "sleep 3",
  "curl -fsS localhost:\($port)/add/2/3"
]}' > params.json

CMD_ID=$(aws ssm send-command --instance-ids "$IID" \
  --document-name AWS-RunShellScript --comment "deploy $NAME $TAG" \
  --parameters file://params.json --query Command.CommandId --output text)
echo "SSM command: $CMD_ID"

sleep 5
aws ssm wait command-executed --command-id "$CMD_ID" --instance-id "$IID" || true
aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$IID" \
  --query '[Status, StandardOutputContent, StandardErrorContent]' --output text
STATUS=$(aws ssm get-command-invocation --command-id "$CMD_ID" --instance-id "$IID" \
  --query Status --output text)
test "$STATUS" = "Success"
