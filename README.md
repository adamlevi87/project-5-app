# App Repository

This repository contains the full application code for the DevOps project:
- Frontend (React)
- Backend (Node.js with DB + SQS)
- Helm charts for Kubernetes deployment
- Local development environment using Docker Compose and Skaffold



## 🧪 `local-testbed/`: Prototype & Validation Environment

Before transitioning to a clean local developer setup, we used `local-testbed/` as a sandbox to validate all key components of the system:

* ✅ **Frontend & Backend containers** communicating correctly
* ✅ Backend storing data in **PostgreSQL** and pushing to **SQS**
* ✅ **Lambda mock** consuming from SQS and writing to **S3**
* ✅ Everything orchestrated using `docker-compose`
* ✅ Verified networking, AWS service mocking (via LocalStack), and end-to-end flow

This testbed served as a scratchpad for experimentation, learning, and proving the design. As the project matured, we finalized the architecture and moved to a more structured dev environment under `local/`.

> *The `local-testbed/` folder is preserved as a reference and documentation of how this system was gradually built and refined.*

---

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
