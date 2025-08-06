#!/bin/bash
set -euo pipefail

NS="argocd"

echo "🔍 Getting TargetGroupBinding name in namespace $NS..."
TGB_NAME=$(kubectl get targetgroupbindings.elbv2.k8s.aws -n "$NS" -o jsonpath='{.items[0].metadata.name}')
echo "➡️ Found TargetGroupBinding: $TGB_NAME"

echo "🔍 Getting TargetGroup ARN..."
TGB_ARN=$(kubectl get targetgroupbinding "$TGB_NAME" -n "$NS" -o jsonpath='{.spec.targetGroupARN}')
echo "➡️ TargetGroup ARN: $TGB_ARN"

echo "🔍 Finding ALB Listener using this TargetGroup..."
LISTENER_ARN=$(aws elbv2 describe-listeners \
  --query "Listeners[?DefaultActions[?TargetGroupArn=='$TGB_ARN']].ListenerArn" \
  --output text)
echo "➡️ Listener ARN: $LISTENER_ARN"

if [[ -z "$LISTENER_ARN" ]]; then
  echo "❌ No listener found using Target Group: $TGB_ARN"
  exit 1
fi

echo "🗑 Deleting ALB Listener..."
aws elbv2 delete-listener --listener-arn "$LISTENER_ARN"
echo "✅ Listener deleted."

echo "🗑 Deleting TargetGroupBinding from Kubernetes..."
kubectl delete targetgroupbinding "$TGB_NAME" -n "$NS"
echo "✅ TargetGroupBinding deleted."

