#!/bin/bash

set -e
# Load the base .env file
set -a
source ./env.base.generate/.env.base
set +a


# Argument validation
if [ -z "$1" ]; then
  echo "❌ Missing argument: please specify '$BACKEND_OPTION' or '$FRONTEND_OPTION' or '$NGINX_OPTION' or 'docker-compose'"
  exit 1
fi


case "$1" in
  "$BACKEND_OPTION")
    # === Backend values ===
    echo "🔧 Generating ${BACKEND_RELEASE_NAME}.local.yaml for $BACKEND_OPTION..."
    BACKEND_HOST_ADDRESS_EXTERNAL="${DOCKER_COMPOSE_BACKEND_APP_SERVICE_NAME}.local"
    FRONTEND_HOST_ADDRESS_EXTERNAL="${DOCKER_COMPOSE_FRONTEND_APP_SERVICE_NAME}.local"
    SQS_QUEUE_URL="http://${LOCALSTACK_HOST_EXTERNAL}:${LOCALSTACK_PORT}/000000000000/${QUEUE_NAME}"
    BACKEND_REPOSITORY_URL="${REPOSITORY_ADDRESS}:${REPOSITORY_PORT}/${BACKEND_REPOSITORY_NAME}"
    cat <<EOF > "$BACKEND_HELM_FOLDER_PATH/${BACKEND_RELEASE_NAME}.local.yaml"
image:
  repository: "${BACKEND_REPOSITORY_URL}"
  tag: "${BACKEND_REPOSITORY_TAG}"
  digest: ""
  pullPolicy: IfNotPresent

service:
  type: "${BACKEND_SERVICE_TYPE}"
  port: "${INGRESS_CONTROLLER_TARGET_PORT_AND_SERVICES_PORT}"

containerPort: "${BACKEND_PORT}"

ingress:
  enabled: "${BACKEND_INGRESS_ENABLED}"
  host: "${BACKEND_HOST_ADDRESS_EXTERNAL}"
  ingressControllerClassResourceName: "${INGRESS_CONTROLLER_CLASS_RESOURCE_NAME}"
  ingressPath: "${BACKEND_INGRESS_PATH}"
  annotations:
    "${BACKEND_REWRITE_TARGET}": "${BACKEND_REWRITE_VALUE}"

replicaCount: "${BACKEND_REPLICA_COUNT_MIN}"

autoscaling:
  enabled: "${BACKEND_HPA_ENABLED}"
  minReplicas: "${BACKEND_REPLICA_COUNT_MIN}"
  maxReplicas: "${BACKEND_REPLICA_COUNT_MAX}"
  targetCPUUtilizationPercentage: "${BACKEND_HPA_CPU_SCALE}"

resources:
  requests:
    cpu: "${BACKEND_REQUEST_CPU}"
    memory: "${BACKEND_REQUEST_MEMORY}"
  limits:
    cpu: "${BACKEND_LIMIT_CPU}"
    memory: "${BACKEND_LIMIT_MEMORY}"

envSecrets:
  AWS_REGION: "${AWS_REGION}"
  AWS_ACCESS_KEY_ID: "${AWS_ACCESS_KEY_ID}"
  AWS_SECRET_ACCESS_KEY: "${AWS_SECRET_ACCESS_KEY}"
  DB_USER: "${POSTGRES_USER}"
  DB_PASSWORD: "${POSTGRES_PASSWORD}"
  DB_NAME: "${POSTGRES_DB}"
  DB_PORT: "${POSTGRES_PORT}"
  DB_HOST: "${DB_HOST_EXTERNAL}"
  POSTGRES_TABLE: "${POSTGRES_TABLE}"
  BACKEND_HOST_ADDRESS: "${BACKEND_HOST_ADDRESS_EXTERNAL}:${INGRESS_CONTROLLER_EXTERNAL_PORT_HTTP}"
  FRONTEND_HOST_ADDRESS: "${FRONTEND_HOST_ADDRESS_EXTERNAL}:${INGRESS_CONTROLLER_EXTERNAL_PORT_HTTP}"
  SQS_QUEUE_URL: "${SQS_QUEUE_URL}"
  
EOF

    echo "✅ ${BACKEND_RELEASE_NAME}.local.yaml generated."
    ;;
  "$FRONTEND_OPTION")
    # === Frontend values ===
    echo "🔧 Generating ${FRONTEND_RELEASE_NAME}.local.yaml for $FRONTEND_OPTION..."
    BACKEND_HOST_ADDRESS_EXTERNAL="${DOCKER_COMPOSE_BACKEND_APP_SERVICE_NAME}.local"
    FRONTEND_HOST_ADDRESS_EXTERNAL="${DOCKER_COMPOSE_FRONTEND_APP_SERVICE_NAME}.local"
    FRONTEND_REPOSITORY_URL="${REPOSITORY_ADDRESS}:${REPOSITORY_PORT}/${FRONTEND_REPOSITORY_NAME}"
    REACT_APP_BACKEND_URL="http://${BACKEND_HOST_ADDRESS_EXTERNAL}:${INGRESS_CONTROLLER_EXTERNAL_PORT_HTTP}"
    cat <<EOF > "$FRONTEND_HELM_FOLDER_PATH/${FRONTEND_RELEASE_NAME}.local.yaml"
image:
  repository: "${FRONTEND_REPOSITORY_URL}"
  tag: "${FRONTEND_REPOSITORY_TAG}"
  digest: ""
  pullPolicy: IfNotPresent

service:
  type: "${FRONTEND_SERVICE_TYPE}"
  port: "${INGRESS_CONTROLLER_TARGET_PORT_AND_SERVICES_PORT}"

containerPort: "${FRONTEND_PORT}"

ingress:
  enabled: "${FRONTEND_INGRESS_ENABLED}"
  host: "${FRONTEND_HOST_ADDRESS_EXTERNAL}"
  ingressControllerClassResourceName: "${INGRESS_CONTROLLER_CLASS_RESOURCE_NAME}"
  ingressPath: "${FRONTEND_INGRESS_PATH}"
  annotations:
    "${FRONTEND_REWRITE_TARGET}": "${FRONTEND_REWRITE_VALUE}"

replicaCount: "${FRONTEND_REPLICA_COUNT_MIN}"

autoscaling:
  enabled: "${FRONTEND_HPA_ENABLED}"
  minReplicas: "${FRONTEND_REPLICA_COUNT_MIN}"
  maxReplicas: "${FRONTEND_REPLICA_COUNT_MAX}"
  targetCPUUtilizationPercentage: "${FRONTEND_HPA_CPU_SCALE}"

resources:
  requests:
    cpu: "${FRONTEND_REQUEST_CPU}"
    memory: "${FRONTEND_REQUEST_MEMORY}"
  limits:
    cpu: "${FRONTEND_LIMIT_CPU}"
    memory: "${FRONTEND_LIMIT_MEMORY}"

envSecrets:
  REACT_APP_BACKEND_URL: "$REACT_APP_BACKEND_URL"
EOF

    echo "✅ $FRONTEND_OPTION values.local.yaml generated."
    ;;
  "$NGINX_OPTION")
    # === nginx values ===
    echo "🔧 Generating values.local.yaml for $NGINX_OPTION..."
    cat <<EOF > "$NGINX_HELM_FOLDER_PATH/values.local.yaml"
controller:
  service:
    type: "${INGRESS_CONTROLLER_SERVICE_TYPE}"
    nodePorts:
      http: "${INGRESS_CONTROLLER_EXTERNAL_PORT_HTTP}"      
      https: "${INGRESS_CONTROLLER_EXTERNAL_PORT_HTTPS}"

  ingressClassResource:
    name: "${INGRESS_CONTROLLER_CLASS_RESOURCE_NAME}"
    enabled: true
    default: true
EOF
    echo "✅ $NGINX_OPTION-Infrastructure values.local.yaml generated."
    ;;
  "docker-compose")
    # === docker-compose values === (Creating Dynamic Variables)
    export REACT_APP_BACKEND_URL="http://${DOCKER_COMPOSE_BACKEND_APP_SERVICE_NAME}:${BACKEND_PORT}"
    export SQS_QUEUE_URL="http://${DOCKER_COMPOSE_LOCALSTACK_SERVICE_NAME}:${LOCALSTACK_PORT}/000000000000/${QUEUE_NAME}"
    export AWS_ENDPOINT="http://${DOCKER_COMPOSE_LOCALSTACK_SERVICE_NAME}:${LOCALSTACK_PORT}"

    echo "🔧 Injecting variables into docker-compose.yml"
    envsubst < ./docker-compose/docker-compose.yml.template > ./docker-compose/docker-compose.yml
    echo "✅ docker-compose created using all the required variables."
    
    # the creation of this table also happens on the application start up
    # (application code in javascript)
    echo "🔧 Injecting variables into init-db.sql"
    envsubst < "./docker-compose/${POSTGRES_FOLDER_PATH}/init-db.template.sql" > "./docker-compose/${POSTGRES_FOLDER_PATH}/init-db.sql"
    echo "✅ Postgres-init-db.sql generated."

    ;;
  *)
    echo "❌ Unknown target: $1 (expected '$BACKEND_OPTION' or '$FRONTEND_OPTION' or '$NGINX_OPTION' or 'docker-compose')"
    exit 1
esac