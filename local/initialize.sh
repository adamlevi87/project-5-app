#!/bin/bash

# Load the base .env file
set -a
source .env.base
set +a

MODE=$1
ACTION=$2  # deploy (default) or uninstall

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 <docker_only | hybrid> optional:[uninstall]"
  echo "Example: $0 docker_only "
  echo "Usage: $0 hybrid uninstall"
  exit 1
fi

# Default action is deploy
ACTION=${ACTION:-deploy}

deploy_docker_only() {
  echo "[+] Starting all services using Docker Compose with profile 'docker_only'..."
  docker compose --profile docker_only up --build --detach
}

uninstall_docker_only() {
  echo "[!] Stopping and removing all Docker Compose services (docker_only)..."
  docker compose --profile docker_only down -v --remove-orphans
}

deploy_hybrid() {
  echo "[+] Starting infra using Docker Compose with profile 'docker_and_kubernetes'..."
  docker compose --profile docker_and_kubernetes up --build --detach

  echo "[+] Generating and applying ingress controller config..."
  ./.generate-env.sh $NGINX_OPTION

  # changing kubectl context to local minikube
  kubectl config use-context dev-local

  # Add the ingress-nginx Helm repo if not already present
  if ! helm repo list | grep -q "^${INGRESS_REPO_NAME}"; then
    helm repo add "${INGRESS_REPO_NAME}" "${INGRESS_REPO_URL}"
    helm repo update
  fi

  helm upgrade --install $NGINX_RELEASE_NAME $NGINX_CHART_NAME/$INGRESS_REPO_NAME \
    --namespace $NGINX_NAMESPACE \
    --create-namespace \
    -f $NGINX_HELM_FOLDER_PATH/values.local.yaml

  echo "[+] Generating and applying backend config..."
  ./.generate-env.sh $BACKEND_OPTION

  echo "Calling build_and_push_image function for Backend..."
  read IMAGE_URI COMMIT_SHA DIGEST < <(build_and_push_image "$BACKEND_REPOSITORY_NAME" "$BACKEND_APP_FOLDER_PATH")

  # Debug
  echo "✅ Image Info:"
  echo "  URI:    $IMAGE_URI"
  echo "  SHA:    $COMMIT_SHA"
  echo "  Digest: $DIGEST"

  echo "[~] Waiting for ingress controller admission webhook service to become ready..."
  for i in {1..20}; do
    if helm upgrade --install $BACKEND_RELEASE_NAME $BACKEND_HELM_FOLDER_PATH -f $BACKEND_HELM_FOLDER_PATH/$BACKEND_RELEASE_NAME.local.yaml --set image.repository="${IMAGE_URI}" --set image.digest="${DIGEST}" --set image.tag="" 2> helm.$BACKEND_RELEASE_NAME.err.log; then
      echo "[✓] Backend installed successfully."
      break
    fi

    if grep -q "failed calling webhook.*connect: connection refused" helm.$BACKEND_RELEASE_NAME.err.log; then
      echo "[...] Admission webhook not ready yet, retrying... ($i/20)"
      sleep 2
    else
      echo "[✗] Helm failed with a different error:"
      cat helm.$BACKEND_RELEASE_NAME.err.log
      exit 1
    fi

    if [[ "$i" -eq 20 ]]; then
      echo "[✗] Timed out waiting for admission webhook readiness."
      exit 1
    fi
  done

  echo "[+] Generating and applying frontend config..."
  ./.generate-env.sh $FRONTEND_OPTION
  echo "Calling build_and_push_image function for Frontend..."
  
  read IMAGE_URI COMMIT_SHA DIGEST < <(build_and_push_image "$FRONTEND_REPOSITORY_NAME" "$FRONTEND_APP_FOLDER_PATH")

  # Debug
  echo "✅ Image Info:"
  echo "  URI:    $IMAGE_URI"
  echo "  SHA:    $COMMIT_SHA"
  echo "  Digest: $DIGEST"

  helm upgrade --install $FRONTEND_RELEASE_NAME $FRONTEND_HELM_FOLDER_PATH -f $FRONTEND_HELM_FOLDER_PATH/$FRONTEND_RELEASE_NAME.local.yaml --set image.repository="${IMAGE_URI}" --set image.digest="${DIGEST}" --set image.tag=""

  envsubst < skaffold.yaml.template > skaffold.yaml
}

uninstall_hybrid() {
  echo "[!] Uninstalling Helm releases..."
  helm uninstall $FRONTEND_RELEASE_NAME || true
  helm uninstall $BACKEND_RELEASE_NAME || true
  helm uninstall $NGINX_RELEASE_NAME -n $NGINX_NAMESPACE || true

  echo "[!] Stopping Docker Compose infra (docker_and_kubernetes)..."
  docker compose --profile docker_and_kubernetes down -v --remove-orphans
}

build_and_push_image() {
    local APP_NAME=$1
    local APP_PATH=$2

    local IMAGE_URI="${REPOSITORY_ADDRESS}:${REPOSITORY_PORT}/${APP_NAME}"
    local COMMIT_SHA
    COMMIT_SHA=$(git rev-parse --short HEAD)

    >&2 echo "🛠  Building image for ${APP_NAME}..."
    docker build -t "${IMAGE_URI}:${COMMIT_SHA}" "${APP_PATH}" || {
      echo "❌ Build failed for ${APP_NAME}"
      exit 1
    }

    >&2 echo "📤 Pushing image..."
    docker push "${IMAGE_URI}:${COMMIT_SHA}" || {
      echo "❌ Push failed for ${APP_NAME}"
      exit 1
    }

    >&2 echo "🔍 Getting image digest..."
    local DIGEST
    DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "${IMAGE_URI}:${COMMIT_SHA}" | cut -d@ -f2) || {
      echo "❌ Failed to get digest for ${APP_NAME}"
      exit 1
    }

    # Export so the caller can access $DIGEST and $IMAGE_URI if needed
    echo "${IMAGE_URI} ${COMMIT_SHA} ${DIGEST}"
  }

cd "$(dirname "$0")"

echo "[+] Generating docker-compose.yml"
  ./.generate-env.sh docker-compose

case "$MODE" in
  docker_only)
    if [[ "$ACTION" == "uninstall" ]]; then
      uninstall_docker_only
    else
      deploy_docker_only
    fi
    ;;
  hybrid)
    if [[ "$ACTION" == "uninstall" ]]; then
      uninstall_hybrid
    else
      deploy_hybrid
    fi
    ;;
  *)
    echo "Invalid mode: $MODE"
    echo "Valid modes: docker_only | hybrid"
    exit 1
    ;;
esac
