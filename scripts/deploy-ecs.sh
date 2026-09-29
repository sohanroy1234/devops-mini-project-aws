#!/usr/bin/env bash
# Deploy a new image to ECS Fargate.
#   1. Copies the service's current task definition
#   2. Swaps in the new image + APP_VERSION
#   3. Registers it as a new revision and updates the service
#   4. Waits until the rollout is stable (ECS circuit breaker auto-rolls back on failure)
#
# Required env: AWS_REGION ECS_CLUSTER ECS_SERVICE TASK_FAMILY IMAGE_URI APP_VERSION
# Optional env: DESIRED_COUNT (default 2)
set -euo pipefail

: "${AWS_REGION:?}" "${ECS_CLUSTER:?}" "${ECS_SERVICE:?}" "${TASK_FAMILY:?}" "${IMAGE_URI:?}" "${APP_VERSION:?}"
DESIRED_COUNT="${DESIRED_COUNT:-2}"

echo ">> Fetching current task definition for family '${TASK_FAMILY}'"
aws ecs describe-task-definition \
  --region "$AWS_REGION" \
  --task-definition "$TASK_FAMILY" \
  --query taskDefinition > current-taskdef.json

echo ">> Building new task definition with image ${IMAGE_URI}"
jq --arg IMG "$IMAGE_URI" --arg VER "$APP_VERSION" '
  .containerDefinitions[0].image = $IMG
  | .containerDefinitions[0].environment =
      ( (.containerDefinitions[0].environment // [])
        | map(select(.name != "APP_VERSION"))
        + [{"name":"APP_VERSION","value":$VER}] )
  | del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
        .compatibilities, .registeredAt, .registeredBy)
' current-taskdef.json > new-taskdef.json

NEW_ARN=$(aws ecs register-task-definition \
  --region "$AWS_REGION" \
  --cli-input-json file://new-taskdef.json \
  --query 'taskDefinition.taskDefinitionArn' --output text)
echo ">> Registered ${NEW_ARN}"

echo ">> Updating service ${ECS_SERVICE} (desired count ${DESIRED_COUNT})"
aws ecs update-service \
  --region "$AWS_REGION" \
  --cluster "$ECS_CLUSTER" \
  --service "$ECS_SERVICE" \
  --task-definition "$NEW_ARN" \
  --desired-count "$DESIRED_COUNT" \
  --force-new-deployment > /dev/null

echo ">> Waiting for service to become stable (this can take 2-4 minutes)..."
if ! aws ecs wait services-stable \
      --region "$AWS_REGION" --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE"; then
  echo "!! Service did not stabilise. Recent events:"
  aws ecs describe-services --region "$AWS_REGION" --cluster "$ECS_CLUSTER" \
    --services "$ECS_SERVICE" --query 'services[0].events[:8].message' --output text || true
  exit 1
fi

echo ">> Deployment complete: ${NEW_ARN}"
