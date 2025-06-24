# App Repository

This repository contains the full application code for the DevOps project:

* Frontend (React)
* Backend (Node.js with DB + SQS)
* Helm charts for Kubernetes deployment
* Local development environment using Docker Compose and Skaffold

## 🥪 `local-testbed/`: Prototype & Validation Environment

Before transitioning to a clean local developer setup, we used `local-testbed/` as a sandbox to validate all key components of the system:

* ✅ **Frontend & Backend containers** communicating correctly
* ✅ Backend storing data in **PostgreSQL** and pushing to **SQS**
* ✅ **Lambda mock** consuming from SQS and writing to **S3**
* ✅ Everything orchestrated using `docker-compose`
* ✅ Verified networking, AWS service mocking (via LocalStack), and end-to-end flow

This testbed served as a scratchpad for experimentation, learning, and proving the design. As the project matured, we finalized the architecture and moved to a more structured dev environment under `local/`.

> *The `local-testbed/` folder is preserved as a reference and documentation of how this system was gradually built and refined.*

### ▶️ Usage Instructions for `local-testbed/`

#### ✅ Prerequisites

* Docker and Docker Compose installed (tested on CentOS 9 VM)
* Node.js and npm for frontend/backend dev (optional)
* No `.env` file is committed — it must be generated
* ✨ **Recommended**: Install [`awslocal`](https://github.com/localstack/awscli-local) to simplify AWS commands with LocalStack

#### 🔧 1. Generate `.env`

```bash
cd local-testbed
./generate-env.sh
```

This script:

* Loads base variables from `.env.base`
* Dynamically composes:

  * `REACT_APP_BACKEND_URL`
  * `SQS_QUEUE_URL`
  * `AWS_ENDPOINT`
* Appends all values into `.env`, used by Docker Compose

#### 🚀 2. Start the stack

```bash
docker compose up --build
```

For a clean rebuild:

```bash
docker compose down -v --remove-orphans
docker compose build --no-cache
docker compose up
```

#### 🌐 3. Access Points

| Service     | URL                                                      |
| ----------- | -------------------------------------------------------- |
| Frontend    | [http://localhost](http://localhost)                     |
| Backend API | [http://backend:3000](http://backend:3000)               |
| Healthcheck | [http://backend:3000/health](http://backend:3000/health) |
| LocalStack  | [http://localhost:4566](http://localhost:4566)           |

#### 📀 Architecture Overview

1. **Frontend** sends text input to the backend
2. **Backend**:

   * Saves it to PostgreSQL
   * Publishes it to an SQS queue (via LocalStack)
3. **Lambda-mock**:

   * Listens on SQS
   * Writes messages to an S3 bucket (mocked)
4. **S3-init**: creates the bucket at startup using AWS CLI

#### 💠 Notes

* **Backend** uses `express.json()` and dynamic CORS config from `BACKEND_HOST`
* **AWS SDK** credentials are passed in `.env` (`test` keys for LocalStack)
* **Postgres** is initialized via `.sql` template + `init-db.sh` (uses `envsubst`)
* The backend container must explicitly call `/usr/local/bin/docker-entrypoint.sh` due to a custom `entrypoint:` override

#### ⚖️ Useful Commands

**Show container logs:**

```bash
docker compose logs
```

**Query messages in the database:**

```bash
docker compose exec postgres psql -U myapp -d myapp_db -c "SELECT * FROM messages;"
```

**Verify SQS queue created:**

```bash
aws --endpoint-url=http://localhost:4566 sqs list-queues
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
awslocal s3 cp s3://myapp-bucket/messages/$(awslocal s3 ls s3://myapp-bucket/messages/ | awk '{print $4}' | head -n1) -
```

#### 🪑 Cleanup

To reset all services and data:

```bash
docker compose down -v
```

## 📦 Next Steps: `local/` Becomes the Developer Environment

We're now evolving the local setup into a clean, reproducible dev environment that:

* Builds images for frontend/backend
* Pushes them to a local Docker registry hosted on the CentOS VM
* Supports Minikube Kubernetes deployments
* Reflects the production-like build/deploy flow

---

## 📁 Folder Summary

| Folder           | Purpose                                            |
| ---------------- | -------------------------------------------------- |
| `local-testbed/` | Historical prototype & validation environment      |
| `local/`         | Structured local dev setup w/ registry integration |
