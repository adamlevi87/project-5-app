#!/bin/bash
set -euo pipefail

NS="frontend"

echo "🔍 Getting TargetGroupBinding name in namespace $NS..."
TGB_NAME=$(kubectl get targetgroupbindings.elbv2.k8s.aws -n "$NS" -o jsonpath='{.items[0].metadata.name}')
echo "➡️ Found TargetGroupBinding: $TGB_NAME"

echo "🔍 Getting TargetGroup ARN..."
TGB_ARN=$(kubectl get targetgroupbinding "$TGB_NAME" -n "$NS" -o jsonpath='{.spec.targetGroupARN}')
echo "➡️ TargetGroup ARN: $TGB_ARN"

echo "🔍 Getting Load Balancer ARN from Target Group..."
LB_ARN=$(aws elbv2 describe-target-groups \
  --target-group-arns "$TGB_ARN" \
  --query 'TargetGroups[0].LoadBalancerArns[0]' \
  --output text)
echo "➡️ Load Balancer ARN: $LB_ARN"

echo "🔍 Getting Listener ARNs from Load Balancer..."
LISTENER_ARNS=$(aws elbv2 describe-listeners \
  --load-balancer-arn "$LB_ARN" \
  --query 'Listeners[*].ListenerArn' \
  --output text)

for LISTENER_ARN in $LISTENER_ARNS; do
  echo "🔍 Checking rules for listener: $LISTENER_ARN"

  RULES=$(aws elbv2 describe-rules --listener-arn "$LISTENER_ARN" --query 'Rules[*]' --output json)

  MATCHED_RULE_ARN=$(echo "$RULES" | jq -r \
    --arg TGB_ARN "$TGB_ARN" \
    '.[] | select(.Actions[].TargetGroupArn == $TGB_ARN) | .RuleArn')

  if [[ -n "$MATCHED_RULE_ARN" ]]; then
    echo "✅ Found rule using target group: $MATCHED_RULE_ARN"
    echo "🗑 Deleting listener rule..."
    aws elbv2 delete-rule --rule-arn "$MATCHED_RULE_ARN"
    echo "✅ Rule deleted."
  fi
done

echo "🗑 Deleting TargetGroupBinding from Kubernetes..."
kubectl delete targetgroupbinding "$TGB_NAME" -n "$NS"
echo "✅ TargetGroupBinding deleted."
