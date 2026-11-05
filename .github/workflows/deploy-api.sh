#!/usr/bin/env bash
#
# Build and push the cias-api image, run database migrations as a one-off ECS
# task, and only if every container in that task exits 0, roll the api and
# worker services onto the new image.
#
# Usage: .github/workflows/deploy-api.sh [CIAS_API_DIR] [IMAGE_TAG]
#   CIAS_API_DIR  cias-api checkout to build (default: .)
#   IMAGE_TAG     tag to push and deploy
#                 (default: 8-char git SHA of CIAS_API_DIR)
#
# Every setting in the config block can be overridden by an environment
# variable of the same name. Run by .github/workflows/deploy-api.yml; can also
# be run by hand.
#
# Requires aws (v2), docker, jq and git. The AWS caller needs:
#   - ecr:GetAuthorizationToken, and push access to the ECR repository
#   - ecs:DescribeTaskDefinition, ecs:RegisterTaskDefinition, ecs:RunTask,
#     ecs:DescribeTasks, ecs:DescribeServices, ecs:UpdateService
#   - iam:PassRole on the execution and task roles of the migrate, api and
#     worker task definitions
#   - logs:FilterLogEvents on the migrate task's log group

set -euo pipefail

# --- Config -------------------------------------------------------------------

AWS_REGION="${AWS_REGION:-us-east-2}"
ECR_REPOSITORY_URI="${ECR_REPOSITORY_URI:-905418359193.dkr.ecr.us-east-2.amazonaws.com/cias-api}"
ECS_CLUSTER_ARN="${ECS_CLUSTER_ARN:-arn:aws:ecs:us-east-2:905418359193:cluster/cias-test}"
API_SERVICE_ARN="${API_SERVICE_ARN:-arn:aws:ecs:us-east-2:905418359193:service/cias-test/cias-test-api}"
WORKER_SERVICE_ARN="${WORKER_SERVICE_ARN:-arn:aws:ecs:us-east-2:905418359193:service/cias-test/cias-test-worker}"
MIGRATE_TASK_DEFINITION_ARN="${MIGRATE_TASK_DEFINITION_ARN:-arn:aws:ecs:us-east-2:905418359193:task-definition/cias-test-api-migrate}"
MIGRATE_SUBNET_IDS="${MIGRATE_SUBNET_IDS:-subnet-00c5413c5761a07a2,subnet-096c5f3aaa158d643}"
MIGRATE_SECURITY_GROUP_IDS="${MIGRATE_SECURITY_GROUP_IDS:-sg-05aa018b8b58ad2e1}"
# ENABLED for public subnets (the task needs a public IP to pull the image and
# read SSM); DISABLED for private subnets with a NAT gateway or VPC endpoints.
MIGRATE_ASSIGN_PUBLIC_IP="${MIGRATE_ASSIGN_PUBLIC_IP:-ENABLED}"
MIGRATE_TIMEOUT_SECONDS="${MIGRATE_TIMEOUT_SECONDS:-1800}"

# ------------------------------------------------------------------------------

log() { echo "==> $*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }

missing=()
for var in AWS_REGION ECR_REPOSITORY_URI ECS_CLUSTER_ARN API_SERVICE_ARN \
  WORKER_SERVICE_ARN MIGRATE_TASK_DEFINITION_ARN MIGRATE_SUBNET_IDS \
  MIGRATE_SECURITY_GROUP_IDS MIGRATE_ASSIGN_PUBLIC_IP MIGRATE_TIMEOUT_SECONDS; do
  if [[ -z "${!var}" || "${!var}" == REPLACE_ME ]]; then
    missing+=("$var")
  fi
done
if (( ${#missing[@]} > 0 )); then
  die "set these in the config block or the environment: ${missing[*]}"
fi
[[ "$MIGRATE_ASSIGN_PUBLIC_IP" == ENABLED || "$MIGRATE_ASSIGN_PUBLIC_IP" == DISABLED ]] ||
  die "MIGRATE_ASSIGN_PUBLIC_IP must be ENABLED or DISABLED"

for cmd in aws docker jq git; do
  command -v "$cmd" >/dev/null || die "$cmd not found"
done

CIAS_API_DIR="${1:-.}"
IMAGE_TAG="${2:-}"
# The build bakes the working tree, so uncommitted changes would ship under a
# commit tag that doesn't contain them.
if [[ -n "$(git -C "$CIAS_API_DIR" status --porcelain)" ]]; then
  die "$CIAS_API_DIR has uncommitted changes; commit or stash them first"
fi
if [[ -z "$IMAGE_TAG" ]]; then
  IMAGE_TAG="$(git -C "$CIAS_API_DIR" rev-parse --short=8 HEAD)"
fi
IMAGE="$ECR_REPOSITORY_URI:$IMAGE_TAG"

# Applies to every aws call below, regardless of the caller's CLI config.
export AWS_REGION AWS_DEFAULT_REGION="$AWS_REGION" AWS_DEFAULT_OUTPUT=json AWS_PAGER=""

# Registers a copy of a task definition with every container that runs an image
# from ECR_REPOSITORY_URI switched to IMAGE, and prints the new revision's ARN.
# Other containers (e.g. the nginx sidecar) are left as they are.
register_revision() {
  local task_definition="$1" definition
  log "Registering a new revision of $task_definition with $IMAGE"
  definition="$(
    aws ecs describe-task-definition --task-definition "$task_definition" \
      --query taskDefinition |
      jq --arg repo "$ECR_REPOSITORY_URI:" --arg image "$IMAGE" '
        .containerDefinitions |= map(
          if (.image | startswith($repo)) then .image = $image else . end
        )
        | del(.taskDefinitionArn, .revision, .status, .requiresAttributes,
              .compatibilities, .registeredAt, .registeredBy, .deregisteredAt)'
  )"
  aws ecs register-task-definition --cli-input-json "$definition" \
    --query taskDefinition.taskDefinitionArn --output text
}

# --- Build and push -----------------------------------------------------------

log "Building $IMAGE from $CIAS_API_DIR"
# SOURCE_VERSION is baked into /release-version for traceability.
docker build --platform linux/amd64 --build-arg SOURCE_VERSION="$IMAGE_TAG" \
  -t "$IMAGE" "$CIAS_API_DIR"

# Only the release tag: environments share this repository, so a moving tag
# like :latest would point at whichever of them deployed last.
log "Pushing $IMAGE"
aws ecr get-login-password |
  docker login --username AWS --password-stdin "${ECR_REPOSITORY_URI%%/*}"
docker push "$IMAGE"

# --- Migrate ------------------------------------------------------------------

migrate_family="${MIGRATE_TASK_DEFINITION_ARN##*/}"
migrate_family="${migrate_family%%:*}"
migrate_task_definition="$(register_revision "$migrate_family")"

log "Running migrations with $migrate_task_definition"
run_output="$(
  aws ecs run-task \
    --cluster "$ECS_CLUSTER_ARN" \
    --launch-type FARGATE \
    --task-definition "$migrate_task_definition" \
    --count 1 \
    --started-by "deploy-$IMAGE_TAG" \
    --network-configuration "awsvpcConfiguration={subnets=[${MIGRATE_SUBNET_IDS// /}],securityGroups=[${MIGRATE_SECURITY_GROUP_IDS// /}],assignPublicIp=$MIGRATE_ASSIGN_PUBLIC_IP}"
)"
task_arn="$(jq -r '.tasks[0].taskArn // empty' <<<"$run_output")"
if [[ -z "$task_arn" ]]; then
  jq '.failures' <<<"$run_output" >&2
  die "run-task did not start the migrate task"
fi

log "Waiting for $task_arn to stop (timeout ${MIGRATE_TIMEOUT_SECONDS}s)"
deadline=$((SECONDS + MIGRATE_TIMEOUT_SECONDS))
last_status=""
while :; do
  task="$(aws ecs describe-tasks --cluster "$ECS_CLUSTER_ARN" --tasks "$task_arn" --query 'tasks[0]')"
  status="$(jq -r '.lastStatus // "UNKNOWN"' <<<"$task")"
  if [[ "$status" != "$last_status" ]]; then
    log "Migrate task is $status"
    last_status="$status"
  fi
  [[ "$status" == STOPPED ]] && break
  # Don't stop the task on timeout: killing a migration partway is worse.
  if (( SECONDS >= deadline )); then
    die "migrate task still $status after ${MIGRATE_TIMEOUT_SECONDS}s and was left running: $task_arn"
  fi
  sleep 10
done

log "Migrate task output"
task_id="${task_arn##*/}"
aws ecs describe-task-definition --task-definition "$migrate_task_definition" \
  --query 'taskDefinition.containerDefinitions' |
  jq -r --arg id "$task_id" '
    .[] | select(.logConfiguration.logDriver == "awslogs")
    | [.logConfiguration.options["awslogs-group"],
       "\(.logConfiguration.options["awslogs-stream-prefix"])/\(.name)/\($id)"]
    | @tsv' |
  while IFS=$'\t' read -r log_group log_stream; do
    aws logs tail "$log_group" --log-stream-names "$log_stream" --since 3h </dev/null ||
      log "Could not read $log_group $log_stream"
  done

# A null exitCode means the container never ran (e.g. image pull or secrets
# fetch failed), so anything but 0 fails the deploy.
failed="$(jq -r '.containers[] | select(.exitCode != 0)
  | "\(.name): exitCode=\(.exitCode // "none") \(.reason // "")"' <<<"$task")"
if [[ -n "$failed" ]]; then
  echo "$failed" >&2
  jq -r '"stopCode=\(.stopCode // "") stoppedReason=\(.stoppedReason // "")"' <<<"$task" >&2
  die "migrations failed; api and worker were not updated"
fi
log "Migrations succeeded"

# --- Update services ----------------------------------------------------------

# Register both revisions before updating either service, so a failure here
# can't leave only one of them rolled forward.
services=("$API_SERVICE_ARN" "$WORKER_SERVICE_ARN")
previous=()
revisions=()
for service in "${services[@]}"; do
  current="$(aws ecs describe-services --cluster "$ECS_CLUSTER_ARN" --services "$service" \
    --query 'services[0].taskDefinition' --output text)"
  [[ "$current" == arn:* ]] || die "could not find the task definition for $service"
  previous+=("$current")
  revisions+=("$(register_revision "$current")")
done

for i in "${!services[@]}"; do
  log "Updating ${services[$i]} from ${previous[$i]} to ${revisions[$i]}"
  aws ecs update-service --cluster "$ECS_CLUSTER_ARN" --service "${services[$i]}" \
    --task-definition "${revisions[$i]}" >/dev/null
done

# Logged before waiting, so they're in the output even if the wait times out.
log "To roll back (the database stays migrated):"
for i in "${!services[@]}"; do
  log "  aws ecs update-service --cluster $ECS_CLUSTER_ARN --service ${services[$i]} --task-definition ${previous[$i]}"
done

log "Waiting for services to stabilize"
aws ecs wait services-stable --cluster "$ECS_CLUSTER_ARN" --services "${services[@]}"

# services-stable also returns after the deployment circuit breaker has rolled
# a service back, so check each one really settled on its new revision.
rolled_back=()
for i in "${!services[@]}"; do
  running="$(aws ecs describe-services --cluster "$ECS_CLUSTER_ARN" --services "${services[$i]}" \
    --query 'services[0].taskDefinition' --output text)"
  [[ "$running" == "${revisions[$i]}" ]] ||
    rolled_back+=("${services[$i]} is on $running instead of ${revisions[$i]}")
done
if (( ${#rolled_back[@]} > 0 )); then
  printf '%s\n' "${rolled_back[@]}" >&2
  die "not every service settled on its new revision (rolled back?)"
fi

log "Deployed $IMAGE"
for revision in "$migrate_task_definition" "${revisions[@]}"; do
  log "  $revision"
done
