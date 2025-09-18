# CampusConnect DevOps Pipeline

This repository now contains a full CI/CD implementation for the CampusConnect 3-tier application. Commits pushed to GitHub trigger automated Jenkins tests, container builds, and a Kubernetes deployment on your managed cluster of choice (Amazon EKS, Azure AKS, or Google GKE).

## Architecture Overview

```
GitHub commit → Jenkins test pipeline → GitHub Actions build/deploy → Container Registry (ECR / Docker Hub / ACR / GCR) → Kubernetes cluster (EKS / AKS / GKE) → Load Balancer → Users
```

The stack is composed of:

- **Frontend:** React SPA served by an Nginx container (`cc/Dockerfile`).
- **Backend:** Node.js/Express API (`server/Dockerfile`).
- **Database:** MongoDB StatefulSet managed inside Kubernetes (`k8s/mongo-statefulset.yaml`).

## Repository Structure

| Path | Description |
|------|-------------|
| `Jenkinsfile` | Jenkins declarative pipeline that installs dependencies and runs automated tests for the frontend and backend. |
| `.github/workflows/cicd.yaml` | GitHub Actions workflow that orchestrates Jenkins, builds Docker images, pushes to your selected registry, and deploys to the chosen Kubernetes provider. |
| `cc/` | React application with Docker build assets and an Axios client that respects `REACT_APP_API_BASE_URL`. |
| `server/` | Express API server including a lightweight health endpoint for Kubernetes probes. |
| `k8s/` | Kubernetes manifests and kustomization for namespace, MongoDB, backend, and frontend services. |

## Local Development

1. Install dependencies:
   ```bash
   npm --prefix server install
   npm --prefix cc install
   ```
2. Provide a local MongoDB instance (e.g., Docker `mongo` container).
3. Run the API: `npm --prefix server start` (requires `MONGO_URI` environment variable).
4. Run the frontend: `npm --prefix cc start` and visit `http://localhost:3000`.

Set `REACT_APP_API_BASE_URL` when building or running the frontend to point at the backend origin (defaults to `http://localhost:5000`).

## Containerization

- **Backend Image:** `server/Dockerfile` installs production dependencies and exposes port 5000. A `/healthz` endpoint was added to support Kubernetes probes.
- **Frontend Image:** `cc/Dockerfile` produces an optimized React build and serves it via Nginx (`cc/nginx/default.conf`). `REACT_APP_API_BASE_URL` is injected at build time.
- `.dockerignore` files ensure transient artifacts are excluded from Docker contexts.

### Manual Build Examples
```bash
# Backend
docker build -t campusconnect-backend ./server

# Frontend (override API URL)
docker build -t campusconnect-frontend \ 
  --build-arg REACT_APP_API_BASE_URL="https://api.example.com" ./cc
```

## Jenkins Continuous Testing

The `Jenkinsfile` defines a Docker-based pipeline that:
1. Checks out the repository.
2. Installs Node.js dependencies for both services via `npm ci`.
3. Runs backend syntax tests (`npm --prefix server test`).
4. Runs the React test suite in CI mode (`npm --prefix cc test -- --watchAll=false`).

Configure a Jenkins pipeline job that points at this repository and uses the provided Jenkinsfile. Expose Jenkins API credentials and an optional job token for GitHub Actions (see below). The Jenkins agent uses the `node:18-bullseye` Docker image, so no global Node installation is required on the host.

## GitHub Actions CI/CD

Workflow file: `.github/workflows/cicd.yaml`

1. **Jenkins Gate:** The `jenkins-tests` job triggers the Jenkins pipeline via REST API and waits until it succeeds.
2. **Image Build & Push:** After Jenkins success, Docker Buildx builds the frontend and backend images, tagging them with the commit SHA and `latest`, then pushes to the registry identified by `REGISTRY_PROVIDER`.
3. **Deployment:** The workflow authenticates to the Kubernetes provider specified by `K8S_PROVIDER`, applies the manifests under `k8s/`, and performs rolling updates by setting the new image tags.

The image build/publish and deployment jobs execute only for direct `push` events. Pull requests still run the Jenkins gate but skip publishing artifacts or mutating the cluster.

### Provider and secret configuration

Set the following GitHub secrets so the workflow knows which registry and Kubernetes cluster to target.

#### Common values

| Secret | Purpose |
|--------|---------|
| `REGISTRY_PROVIDER` | Choose the container registry (`ecr`, `dockerhub`, `acr`, or `gcr`). Defaults to `ecr` when unset. |
| `K8S_PROVIDER` | Choose the Kubernetes provider (`eks`, `aks`, or `gke`). Defaults to `eks` when unset. |
| `BACKEND_IMAGE_NAME`, `FRONTEND_IMAGE_NAME` | Repository names used when tagging the backend and frontend images (for example `campusconnect-backend`). |
| `CONTAINER_REGISTRY` | Base registry hostname/namespace (e.g., `docker.io/example`, `myregistry.azurecr.io`). Required for Docker Hub, ACR, and GCR, optional for ECR where it falls back to the login output. |
| `REACT_APP_API_BASE_URL` | Base URL for the backend API baked into the frontend build. |
| `K8S_MONGO_URI` | MongoDB connection string published into the cluster secret (`mongo-credentials`). Example: `mongodb://mongo:27017/campusconnect`. |

#### Jenkins API access

- `JENKINS_URL`
- `JENKINS_USER`
- `JENKINS_API_TOKEN`
- `JENKINS_JOB_URL`
- `JENKINS_BUILD_TOKEN` (optional if the job requires one)

The workflow gracefully handles Jenkins instances without the crumb issuer plugin.

#### Registry-specific credentials

- **Amazon ECR (`REGISTRY_PROVIDER=ecr`):** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` (shared with EKS). Optionally override the registry host with `CONTAINER_REGISTRY`.
- **Docker Hub (`REGISTRY_PROVIDER=dockerhub`):** `DOCKERHUB_USERNAME`, `DOCKERHUB_TOKEN`, and `CONTAINER_REGISTRY` set to `docker.io/<username>`.
- **Azure Container Registry (`REGISTRY_PROVIDER=acr`):** `AZURE_ACR_LOGIN_SERVER`, `AZURE_ACR_USERNAME`, `AZURE_ACR_PASSWORD`, plus `CONTAINER_REGISTRY` (typically the same as the login server).
- **Google Artifact/Container Registry (`REGISTRY_PROVIDER=gcr`):** `GCP_SERVICE_ACCOUNT_KEY` (JSON), `GCP_PROJECT_ID`, `GCP_REGISTRY_HOST`, and `CONTAINER_REGISTRY` (for example `us-central1-docker.pkg.dev/<project>/<repository>`).

#### Kubernetes provider credentials

- **Amazon EKS (`K8S_PROVIDER=eks`):** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, and `EKS_CLUSTER_NAME`.
- **Azure AKS (`K8S_PROVIDER=aks`):** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `AZURE_RESOURCE_GROUP`, and `AZURE_AKS_CLUSTER`.
- **Google GKE (`K8S_PROVIDER=gke`):** `GCP_SERVICE_ACCOUNT_KEY`, `GCP_PROJECT_ID`, `GKE_CLUSTER_NAME`, and `GKE_LOCATION`.

The workflow requires `jq` (preinstalled on `ubuntu-latest`) to parse Jenkins API responses.

## Kubernetes Deployment

The `k8s/` directory contains manifests managed by kustomize:

- `namespace.yaml` provisions the `campusconnect` namespace.
- `mongo-statefulset.yaml` provisions MongoDB with persistent storage and readiness probes.
- `backend-deployment.yaml` and `backend-service.yaml` deploy the API with `/healthz` probes and a ClusterIP service. The deployment expects a secret named `mongo-credentials` containing a `mongo-uri` key.
- `frontend-deployment.yaml` and `frontend-service.yaml` deploy the React app behind a `LoadBalancer` service.

Update the placeholder container images in the deployment manifests or rely on the GitHub Actions workflow, which overrides them with freshly built tags each run.

Apply the stack manually with:
```bash
kubectl apply -k k8s
```

Before deploying, create the database secret once (the GitHub Actions workflow does this automatically when `K8S_MONGO_URI` is set):

```bash
kubectl -n campusconnect create secret generic mongo-credentials \
  --from-literal=mongo-uri="mongodb://mongo:27017/campusconnect"
```

## End-to-End Flow

1. **Developer pushes code to GitHub.**
2. **Jenkins** runs automated tests using the repo's Jenkinsfile.
3. **GitHub Actions** builds Docker images on success and pushes them to the configured container registry.
4. **GitHub Actions** deploys the updated manifests to the selected Kubernetes cluster (EKS, AKS, or GKE).
5. The **LoadBalancer service** exposes the React frontend publicly; the frontend communicates with the backend service inside the cluster, which in turn connects to MongoDB.

This setup delivers a reproducible, automated pipeline from commit to production for the CampusConnect application.