#!/bin/bash

set -euo pipefail

APP_NAME="$1"  # backend or frontend
COMMIT_SHA=$(git rev-parse --short HEAD)
AWS_REGION="us-east-1"
ENV="dev"
PROJECT_TAG="project-5"

# Construct ECR repo name
ECR_REPO="${PROJECT_TAG}-${ENV}-${APP_NAME}"
ECR_URI="593793036161.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

echo "🛠  Building image for $APP_NAME..."
docker build -t "${ECR_URI}:${COMMIT_SHA}" "./app/${APP_NAME}"

echo "🔐 Logging into ECR..."
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_URI"

echo "📤 Pushing image..."
docker push "${ECR_URI}:${COMMIT_SHA}"

echo "🔍 Getting image digest from ECR..."
DIGEST=$(aws ecr describe-images \
  --repository-name "$ECR_REPO" \
  --region "$AWS_REGION" \
  --image-ids imageTag="${COMMIT_SHA}" \
  --query 'imageDetails[0].imageDigest' \
  --output text)

echo "📦 Image pushed:"
echo "  URI:    ${ECR_URI}:${COMMIT_SHA}"
echo "  Digest: ${DIGEST}"

# Optional: deploy via Helm using digest
echo "🚀 Deploying $APP_NAME via Helm..."
helm upgrade "$APP_NAME" ./helm/base-app \
  --install \
  --namespace default \
  --set image.repository="${ECR_URI}" \
  --set image.digest="${DIGEST}" \
  --set image.tag=""

# Optional: save metadata to file
echo "image=${ECR_URI}" > "./${APP_NAME}-deploy-info.env"
echo "tag=${COMMIT_SHA}" >> "./${APP_NAME}-deploy-info.env"
echo "digest=${DIGEST}" >> "./${APP_NAME}-deploy-info.env"

echo "✅ Done."
