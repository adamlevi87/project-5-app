#!/bin/bash

set -e

MODE=$1
ACTION=$2  # deploy (default) or uninstall

if [[ -z "$MODE" ]]; then
  echo "Usage: $0 <docker_only | hybrid> [uninstall]"
  exit 1
fi

# Default action is deploy
ACTION=${ACTION:-deploy}

cd "$(dirname "$0")"

deploy_docker_only() {
  echo "[+] Generating .env for Docker Compose (full stack)..."
  ./.generate-env.sh docker-compose

  echo "[+] Starting all services using Docker Compose with profile 'docker_only'..."
  docker compose --profile docker_only up --build --detach
}

uninstall_docker_only() {
  echo "[!] Stopping and removing all Docker Compose services (docker_only)..."
  docker compose --profile docker_only down -v --remove-orphans
}

deploy_hybrid() {
  echo "[+] Generating .env for Docker Compose (infra only)..."
  ./.generate-env.sh docker-compose

  echo "[+] Starting infra using Docker Compose with profile 'docker_and_kubernetes'..."
  docker compose --profile docker_and_kubernetes up --build --detach

  echo "[+] Generating and applying ingress controller config..."
  ./.generate-env.sh nginx
  helm upgrade --install ingress-controller ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    -f ./helm/infra/ingress-nginx/values.local.yaml

  echo "[+] Generating and applying backend config..."
  ./.generate-env.sh backend
  helm upgrade --install backend ./helm/base-app/ -f ./helm/base-app/values.local.yaml

  echo "[+] Generating and applying frontend config..."
  ./.generate-env.sh frontend
  helm upgrade --install frontend ./helm/base-app/ -f ./helm/base-app/values.local.yaml
}

uninstall_hybrid() {
  echo "[!] Uninstalling Helm releases..."
  helm uninstall frontend || true
  helm uninstall backend || true
  helm uninstall ingress-controller -n ingress-nginx || true

  echo "[!] Stopping Docker Compose infra (docker_and_kubernetes)..."
  docker compose --profile docker_and_kubernetes down -v --remove-orphans
}

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
