#!/bin/bash

set -e

# AWS deployment script
EKS_CLUSTER="project-5-dev-cluster"
AWS_REGION="us-east-1"

echo "🚀 Deploying to AWS EKS cluster: $EKS_CLUSTER"

# Update kubectl context to AWS EKS
echo "📡 Updating kubectl context..."
aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER

# Verify connection
echo "🔍 Verifying EKS connection..."
kubectl get nodes

# Deploy frontend
echo "🎨 Deploying frontend..."
helm upgrade --install frontend-aws ./base-app \
  -f ./values/frontend.aws.yaml \
  --namespace default \
  --create-namespace

# Deploy backend
echo "⚙️ Deploying backend..."
helm upgrade --install backend-aws ./base-app \
  -f ./values/backend.aws.yaml \
  --namespace default \
  --create-namespace

# Check deployment status
echo "✅ Checking deployment status..."
kubectl get pods -l app=frontend-aws
kubectl get pods -l app=backend-aws
kubectl get ingress
kubectl get services

echo "🎉 Deployment complete!"
echo "📱 Application should be available at: https://project-5.projects-devops.cfd"
echo ""
echo "🔧 Useful commands:"
echo "  kubectl get pods"
echo "  kubectl logs -f deployment/frontend-aws"
echo "  kubectl logs -f deployment/backend-aws"
echo "  kubectl describe ingress"