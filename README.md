# 🚀 Project 5 – Full-Stack App with Local Dev Environment

This project provides a full-stack web application with a structured local development environment. It supports two deployment modes:
**Docker Compose only** and a **hybrid Docker + Kubernetes setup** using Minikube:

* Frontend (React)
* Backend (Node.js with DB + SQS)
* Helm charts for Kubernetes deployment
* Local development environment using Docker Compose and Skaffold

## 📁 Repository Structure

```
app/
├── frontend/     # React frontend + Dockerfile
├── backend/      # Node.js backend + Dockerfile

local/
├── docker/       # Infrastructure containers (Postgres, LocalStack, etc.)
├── helm/
│   ├── base-app/         # Shared Helm chart for frontend/backend apps
│   └── infra/
│       └── ingress-nginx/  # Helm chart for deploying the ingress controller
├── initialize.sh  # Unified setup script
├── skaffold/      # Skaffold CI-like rebuild flow
├── .env.base      # Shared variable definitions
```

## 🛠️ Deployment Modes

### 1. Docker Only (Monolithic Local Setup)

Runs everything (infra + apps) using Docker Compose.

```bash
./initialize.sh docker_only
```

### 2. Hybrid (Kubernetes + Docker Compose)

- Infra (Postgres, LocalStack, lambda) via Docker Compose
- Apps (frontend, backend) deployed via Kubernetes (Minikube)
- Skaffold watches app folders and redeploys on changes

```bash
./initialize.sh hybrid
```

💡 Uninstall with:

```bash
./initialize.sh docker_only uninstall
./initialize.sh hybrid uninstall
```

## 🌐 Host Configuration

Ensure your **Windows 11 host** maps service hostnames to the correct VMs:

```
# Docker Compose services
192.168.241.128 backend
192.168.241.128 frontend

# Kubernetes ingress services
192.168.59.105 backend.local
192.168.59.105 frontend.local
```

These values are configurable via `.env.base`.

## 🧰 Tooling Overview

- **Skaffold** (used only in hybrid mode):
  - Watches for changes in `app/frontend` and `app/backend`
  - Builds & pushes images to the internal Docker registry (`192.168.241.128:5000`)
  - Triggers Helm `upgrade --install` for live redeployment

- **Helm**:
  - `helm/base-app/`: Shared chart used by both frontend and backend (injected with per-app values files)
  - `helm/infra/ingress-nginx/`: Installs the ingress controller to expose services

- **Ingress (NGINX)**:
  - Deployed by `initialize.sh` using Helm
  - Handles `frontend.local` and `backend.local` routing via Minikube's IP

## 📦 Services Overview

| Component     | Stack                     | Purpose                            |
|---------------|---------------------------|------------------------------------|
| Frontend      | React + NGINX (K8s)       | UI interface                       |
| Backend       | Node.js + Express (K8s)   | Accepts input, writes to DB & SQS  |
| Postgres      | Docker Compose            | Stores submitted messages          |
| LocalStack    | Docker Compose            | Mocks AWS S3 + SQS                 |
| Lambda-Mock   | Docker Compose            | Simulates Lambda reading from SQS  |
| S3 Init       | Docker Compose            | Bootstrap S3 bucket on startup     |

## 🔁 Skaffold CI-Like Flow

Only applies in `hybrid` mode:

1. Developer edits frontend/backend code
2. Skaffold:
   - Rebuilds the image
   - Pushes to local registry
   - Triggers `helm upgrade`
3. Kubernetes picks up the new version (using image digest or `latest` tag)

## ✨ Advanced Notes

- All shared variables are managed in `.env.base`
- Helm values files are auto-generated via `generate-env.sh`
- Helm chart uses `image.repository`, `image.tag`, `image.pullPolicy`
- Skaffold `imageStrategy` is configured to use `helm.explicitRegistry`
- Pushes to insecure registry: `192.168.241.128:5000`

## ✅ Setup Prerequisites

- Docker + Docker Compose (on CentOS VM)
- Minikube (VirtualBox-based VM)
- Helm, kubectl, Skaffold installed on CentOS VM
- Windows host with `/etc/hosts` or `C:\Windows\System32\drivers\etc\hosts` entries pointing to Minikube and Docker IPs
