# 🚀 Project 5 – Full-Stack App with Local Dev Environment

This project provides a full-stack web application with a structured local development environment. It supports two deployment modes:
**Docker Compose only** and a **hybrid Docker + Kubernetes setup** using Minikube:

* Frontend (React)
* Backend (Node.js with DB + SQS)
* Helm charts for Kubernetes deployment
* Local development environment using Docker Compose and Skaffold

#### 📀 Architecture Overview

1. **Frontend** sends text input to the backend
2. **Backend**:
   * Saves text to PostgreSQL
   * Publishes it to an SQS queue (via LocalStack)
3. **Lambda-mock**:
   * Listens on SQS
   * Writes messages to an S3 bucket (mocked)
4. **S3-init**: creates the bucket at startup using AWS CLI

## 📁 Repository Structure

```
.
├── app/                      # Application source code (Dockerized)
│   ├── backend/              # Node.js backend
│   └── frontend/             # React frontend
│
├── local/                    # Local environment configuration and tooling
│   ├── docker/               # Docker Compose infrastructure
│   │   ├── postgres/
│   │   ├── localstack/
│   │   └── lambda-mock/
│   ├── helm/                 # Helm charts for Kubernetes deployment
│   │   ├── base-app/         # Shared Helm chart used for both frontend & backend
│   │   └── infra/
│   │       └── ingress-nginx/  # Helm release for ingress controller
│   ├── .generate-env.sh      # Creates all env/values YAMLs needed for local runs
│   ├── initialize.sh         # Handles full deploy/uninstall logic for both modes
│   ├── skaffold.yaml.template # Skaffold config template
│   └── .env.base             # Shared variable definitions for all environments
```

This structure helps clearly define what’s managed where:
- `app/` is for dev-facing code
- `local/` is for infra, runtime logic, and developer tooling

### 🔧 Script Relationships

- `initialize.sh` is the main script to deploy or uninstall either `docker_only` or `hybrid` environments.
- It first calls `.generate-env.sh` to create all required configuration files based on `.env.base`.
- Then it proceeds to deploy the relevant services:
  - via Docker Compose for `docker_only`
  - via Helm (plus Ingress) for `hybrid`

This structure ensures a clear separation between app code, infra, config generation, and deployment automation.

This layout is designed to be clean, composable, and portable.

## 🛠️ Deployment Modes in Detail

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

## 🌐 Host Configuration & Browsing

To enable proper service resolution during local development, this project uses custom hostnames mapped to the IPs of your local virtual machines.

You must add the following entries to your local hosts file:

```
# Docker Compose services
192.168.241.128 backend
192.168.241.128 frontend

# Kubernetes ingress services
192.168.59.105 backend.local
192.168.59.105 frontend.local
```

- The **base hostnames** (`backend`, `frontend`) are configurable via the `.env.base` file in the `local/` folder.
- The **ingress hostnames** (`backend.local`, `frontend.local`) are automatically derived by appending `.local` to the base hostnames.
- The **IP addresses** must reflect the actual IPs of your infrastructure VMs and should be manually assigned and updated in `.env.base`.
- Accessing & browsing to the frontend is done using those host file entries:
  - docker_only mode:
        http://frontend/
      backend is accessible on:
        backend:3000
  - hybrid mode:
        http://frontend.local:30080/
        https://frontend.local:30443/
      backend is accessible on:
        backend.local:30080/submit

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
- Helm chart uses `image.repository`, `image.tag`, `image.pullPolicy` (generated by generate-env.sh)
- Skaffold `imageStrategy` is configured to use `helm.explicitRegistry`
- Pushes to insecure registry: `192.168.241.128:5000` (host:port are varaibles in .env.base)

## ✅ Setup Prerequisites

This project was developed and tested in the following local setup:

### 🧪 Development Setup Example

- **Host OS**: Windows 11
    - **CentOS VM (via VMware Workstation)**:
        - Runs all local Docker containers (e.g., backend, frontend, Postgres, LocalStack)
        - Hosts a local Docker registry
        - Has Docker, Docker Compose, Helm, `kubectl`, and Skaffold installed
    - **Minikube VM (via VirtualBox)**:
        - Runs Kubernetes cluster for the hybrid deployment mode
        - Connected via bridged networking to the CentOS VM

All required scripts (`initialize.sh`, `generate-env.sh`, etc.) and Skaffold commands are executed **from inside the CentOS VM**.

---

### ⚙️ General Requirements

If you are adapting this project to your own environment, ensure the following are available:

- **A Linux-based VM or machine** with:
  - Docker + Docker Compose
  - Helm, `kubectl`, Skaffold
  - Access to your local Kubernetes cluster (e.g., Minikube) (I used vmware network edit to bridge the adapters of the two VMs)
- **A Kubernetes cluster** (Minikube recommended for local development)
- **Local Docker registry** accessible from your Kubernetes cluster (e.g., hosted on your Docker VM)
-  **Ability to edit the local hosts file** on your machine to map service hostnames to the appropriate IPs
    - **Local networking setup** that allows the host machine to route `.local` hostnames to Kubernetes ingress and base hostnames to Docker services

#### ⚖️ Useful Commands

**Show container logs:**

```bash
docker compose logs
```

**Query messages in the database:(After running the initialize.sh & from the local/ folder**

```bash
docker compose -f ./docker-compose/docker-compose.yml exec postgres psql -U myapp \
  -d myapp_db -c "SELECT * FROM messages;"
```

**Read messages in the queue (if Lambda hasn’t processed them):**

```bash
aws --endpoint-url=http://localhost:4566 sqs receive-message \
  --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/my-queue \
  --max-number-of-messages 10
```

**List files written by lambda to S3:**

```bash
awslocal s3 ls s3://myapp-bucket/messages/
```

**Print a specific file from S3 (by name):**

```bash
awslocal s3 cp s3://myapp-bucket/messages/<filename>.json -
```

**Print the first message in S3 bucket:**

```bash
awslocal s3 cp s3://myapp-bucket/messages/$(\
  awslocal s3 ls s3://myapp-bucket/messages/ | awk '{print $4}' | head -n1) -
```


