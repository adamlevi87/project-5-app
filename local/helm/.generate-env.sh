#!/bin/bash

# Load the base .env file
set -a
source ../.env.base
set +a

# Compose derived values
REACT_APP_BACKEND_URL="http://${BACKEND_HOST}:${BACKEND_PORT}"
SQS_QUEUE_URL="http://${LOCALSTACK_HOST}:${LOCALSTACK_PORT}/000000000000/${QUEUE_NAME}"
AWS_ENDPOINT="http://${LOCALSTACK_HOST}:${LOCALSTACK_PORT}"
BACKEND_REPOSITORY_URL="${REPOSITORY_ADDRESS}:${REPOSITORY_PORT}/${BACKEND_REPOSITORY_NAME}"

# Argument validation
if [ -z "$1" ]; then
  echo "❌ Missing argument: please specify 'backend' or 'frontend'"
  exit 1
fi


# === Backend values ===
if [ "$1" == "backend" ]; then
  echo "🔧 Generating values.local.yaml for backend..."

  cat <<EOF > ./backend/values.local.yaml
image:
  repository: "${BACKEND_REPOSITORY_URL}"
  tag: "${BACKEND_REPOSITORY_TAG}"
  pullPolicy: IfNotPresent

service:
  type: "$BACKEND_SERVICE_TYPE"
  port: "$BACKEND_PORT"

containerPort: "$BACKEND_PORT"

ingress:
  enabled: "${BACKEND_INGRESS_ENABLED}"
  host: "$BACKEND_HOST.local"
  annotations:
    "$BACKEND_REWRITE_TARGET": "$BACKEND_REWRITE_VALUE"

envSecrets:
    AWS_REGION: "$AWS_REGION"
    AWS_ACCESS_KEY_ID: "$AWS_ACCESS_KEY_ID"
    AWS_SECRET_ACCESS_KEY: "$AWS_SECRET_ACCESS_KEY"

    POSTGRES_USER: "$POSTGRES_USER"
    POSTGRES_PASSWORD: "$POSTGRES_PASSWORD"
    POSTGRES_DB: "$POSTGRES_DB"
    POSTGRES_PORT: "$POSTGRES_PORT"
  POSTGRES_TABLE: "$POSTGRES_TABLE"

    DB_HOST: "$DB_HOST"
    BACKEND_HOST: "$BACKEND_HOST"
    BACKEND_PORT: "$BACKEND_PORT"

    SQS_QUEUE_URL: "$SQS_QUEUE_URL"
  
  
    BACKEND_REPLICA_COUNT: "$BACKEND_REPLICA_COUNT"
EOF

  echo "✅ Backend values.local.yaml generated."


# === Frontend values ===
elif [ "$1" == "frontend" ]; then
  echo "🔧 Generating values.local.yaml for frontend..."

  cat <<EOF > ./frontend/values.local.yaml
image:
  repository: "192.168.241.128:5000/frontend"
  tag: "latest"
  pullPolicy: IfNotPresent

service:
  port: "$FRONTEND_PORT"

containerPort: "$FRONTEND_PORT"

ingress:
  enabled: true
  host: "frontend.local"

envSecrets:
  REACT_APP_BACKEND_URL: "$REACT_APP_BACKEND_URL"
EOF

  echo "✅ Frontend values.local.yaml generated."

else
  echo "❌ Unknown target: $1 (expected 'backend' or 'frontend')"
  exit 1
fi