#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_TAG="project-5"
ENVIRONMENT="dev"
CLUSTER_NAME="${PROJECT_TAG}-${ENVIRONMENT}-cluster"
AWS_REGION="us-east-1"

echo -e "${GREEN}🧹 Cleaning up AWS resources before Terraform destroy${NC}"
echo -e "${YELLOW}Cluster: ${CLUSTER_NAME}${NC}"
echo -e "${YELLOW}Region: ${AWS_REGION}${NC}"

# Function to verify and show what resources will be targeted
verify_target_resources() {
    echo -e "${YELLOW}🔍 Verifying target resources for cleanup...${NC}"
    echo -e "${YELLOW}This script will ONLY target resources for:${NC}"
    echo -e "   • Project: ${PROJECT_TAG}"
    echo -e "   • Environment: ${ENVIRONMENT}"
    echo -e "   • EKS Cluster: ${CLUSTER_NAME}"
    echo -e "   • Domain: project-5.projects-devops.cfd"
    echo -e "   • Region: ${AWS_REGION}"
    echo ""
    
    # Check if EKS cluster exists
    if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" &> /dev/null; then
        echo -e "${GREEN}✅ EKS cluster found: ${CLUSTER_NAME}${NC}"
        
        # Show what Kubernetes resources exist
        if aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" &> /dev/null; then
            echo -e "${YELLOW}📋 Kubernetes resources that will be deleted:${NC}"
            
            # Show ingress resources
            INGRESS_COUNT=$(kubectl get ingress --all-namespaces --no-headers 2>/dev/null | wc -l)
            echo -e "   • Ingress resources: ${INGRESS_COUNT}"
            
            # Show LoadBalancer services
            LB_COUNT=$(kubectl get svc --all-namespaces -o wide 2>/dev/null | grep LoadBalancer | wc -l)
            echo -e "   • LoadBalancer services: ${LB_COUNT}"
        fi
    else
        echo -e "${YELLOW}⚠️  EKS cluster not found: ${CLUSTER_NAME}${NC}"
    fi
    
    # Check for ALBs with our cluster tags
    echo -e "${YELLOW}📋 Checking for ALBs tagged with cluster: ${CLUSTER_NAME}${NC}"
    ALB_COUNT=0
    ALBS=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query "LoadBalancers[*].LoadBalancerArn" --output text 2>/dev/null)
    
    if [ -n "$ALBS" ]; then
        for alb_arn in $ALBS; do
            CLUSTER_TAG=$(aws elbv2 describe-tags --resource-arns "$alb_arn" --region "$AWS_REGION" \
                --query "TagDescriptions[0].Tags[?Key=='elbv2.k8s.aws/cluster' && Value=='${CLUSTER_NAME}'].Value" \
                --output text 2>/dev/null)
            
            if [ -n "$CLUSTER_TAG" ]; then
                ALB_COUNT=$((ALB_COUNT + 1))
                ALB_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arns "$alb_arn" --region "$AWS_REGION" --query "LoadBalancers[0].LoadBalancerName" --output text)
                echo -e "   • ALB: ${ALB_NAME}"
            fi
        done
    fi
    
    if [ "$ALB_COUNT" -eq 0 ]; then
        echo -e "${GREEN}✅ No ALBs found with cluster tag${NC}"
    fi
    
    # Check for RDS instance
    DB_IDENTIFIER="${PROJECT_TAG}-${ENVIRONMENT}-db"
    if aws rds describe-db-instances --db-instance-identifier "$DB_IDENTIFIER" --region "$AWS_REGION" &> /dev/null; then
        echo -e "${YELLOW}📋 RDS instance found: ${DB_IDENTIFIER}${NC}"
        
        DELETION_PROTECTION=$(aws rds describe-db-instances \
            --db-instance-identifier "$DB_IDENTIFIER" \
            --region "$AWS_REGION" \
            --query "DBInstances[0].DeletionProtection" \
            --output text)
        
        echo -e "   • Deletion protection: ${DELETION_PROTECTION}"
    else
        echo -e "${GREEN}✅ No RDS instance found${NC}"
    fi
    
    # Check for DNS records
    DOMAIN_NAME="projects-devops.cfd"
    SUBDOMAIN_NAME="project-5"
    FULL_DOMAIN="${SUBDOMAIN_NAME}.${DOMAIN_NAME}"
    
    ZONE_ID=$(aws route53 list-hosted-zones-by-name \
        --dns-name "$DOMAIN_NAME" \
        --region "$AWS_REGION" \
        --query "HostedZones[?Name=='${DOMAIN_NAME}.'].Id" \
        --output text 2>/dev/null | sed 's|/hostedzone/||')
    
    if [ -n "$ZONE_ID" ] && [ "$ZONE_ID" != "None" ]; then
        echo -e "${YELLOW}📋 DNS records that will be checked for: ${FULL_DOMAIN}${NC}"
        
        # Count A records
        A_COUNT=$(aws route53 list-resource-record-sets \
            --hosted-zone-id "$ZONE_ID" \
            --region "$AWS_REGION" \
            --query "ResourceRecordSets[?Name=='${FULL_DOMAIN}.' && Type=='A']" \
            --output json | jq length)
        
        echo -e "   • A records: ${A_COUNT}"
        
        # Count TXT records with ExternalDNS heritage
        TXT_RECORDS=$(aws route53 list-resource-record-sets \
            --hosted-zone-id "$ZONE_ID" \
            --region "$AWS_REGION" \
            --query "ResourceRecordSets[?Name=='${FULL_DOMAIN}.' && Type=='TXT']" \
            --output json)
        
        EXTERNAL_DNS_TXT_COUNT=0
        if [ "$TXT_RECORDS" != "[]" ]; then
            EXTERNAL_DNS_TXT_COUNT=$(echo "$TXT_RECORDS" | jq -r '.[] | .ResourceRecords[0].Value' | grep -c "heritage=external-dns" || echo "0")
        fi
        
        echo -e "   • ExternalDNS TXT records: ${EXTERNAL_DNS_TXT_COUNT}"
    else
        echo -e "${GREEN}✅ No hosted zone found for ${DOMAIN_NAME}${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}⚠️  This script will NOT affect any other AWS resources!${NC}"
    echo ""
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    if ! aws sts get-caller-identity &> /dev/null; then
        echo -e "${RED}❌ Error: AWS CLI is not configured or credentials are invalid${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ AWS CLI is configured${NC}"
}

# Function to check and clean up Kubernetes ingress resources
cleanup_kubernetes_ingress() {
    echo -e "${YELLOW}📋 Checking for Kubernetes ingress resources...${NC}"
    
    # Check if EKS cluster exists
    if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" &> /dev/null; then
        echo -e "${YELLOW}⚠️  EKS cluster not found, skipping Kubernetes cleanup${NC}"
        return
    fi
    
    # Update kubeconfig
    echo -e "${YELLOW}🔧 Updating kubeconfig...${NC}"
    if ! aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" &> /dev/null; then
        echo -e "${YELLOW}⚠️  Could not update kubeconfig, cluster might be in bad state${NC}"
        return
    fi
    
    # Check for ingress resources
    echo -e "${YELLOW}🔍 Checking for ingress resources...${NC}"
    if kubectl get ingress --all-namespaces --no-headers 2>/dev/null | grep -q .; then
        echo -e "${YELLOW}🗑️  Found ingress resources, deleting...${NC}"
        kubectl get ingress --all-namespaces
        kubectl delete ingress --all --all-namespaces --ignore-not-found=true
        echo -e "${GREEN}✅ Ingress resources deleted${NC}"
    else
        echo -e "${GREEN}✅ No ingress resources found${NC}"
    fi
    
    # Check for LoadBalancer services (just in case)
    echo -e "${YELLOW}🔍 Checking for LoadBalancer services...${NC}"
    if kubectl get svc --all-namespaces -o wide 2>/dev/null | grep LoadBalancer | grep -q .; then
        echo -e "${YELLOW}🗑️  Found LoadBalancer services, deleting...${NC}"
        kubectl get svc --all-namespaces -o wide | grep LoadBalancer
        kubectl delete svc --all --all-namespaces --field-selector spec.type=LoadBalancer --ignore-not-found=true
        echo -e "${GREEN}✅ LoadBalancer services deleted${NC}"
    else
        echo -e "${GREEN}✅ No LoadBalancer services found${NC}"
    fi
}

# Function to clean up Route53 DNS records created by ExternalDNS
cleanup_external_dns_records() {
    echo -e "${YELLOW}🌐 Cleaning up Route53 DNS records created by ExternalDNS...${NC}"
    
    # Domain from your terraform config - BE VERY SPECIFIC HERE
    DOMAIN_NAME="projects-devops.cfd"
    SUBDOMAIN_NAME="project-5"
    FULL_DOMAIN="${SUBDOMAIN_NAME}.${DOMAIN_NAME}"
    
    # Get the hosted zone ID - only for our specific domain
    ZONE_ID=$(aws route53 list-hosted-zones-by-name \
        --dns-name "$DOMAIN_NAME" \
        --region "$AWS_REGION" \
        --query "HostedZones[?Name=='${DOMAIN_NAME}.'].Id" \
        --output text 2>/dev/null | sed 's|/hostedzone/||')
    
    if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "None" ]; then
        echo -e "${YELLOW}⚠️  No hosted zone found for domain: $DOMAIN_NAME${NC}"
        return
    fi
    
    echo -e "${YELLOW}📋 Found hosted zone: $ZONE_ID for domain: $DOMAIN_NAME${NC}"
    echo -e "${YELLOW}🎯 Only targeting DNS records for: $FULL_DOMAIN${NC}"
    
    # Get A records ONLY for our specific subdomain
    echo -e "${YELLOW}🔍 Looking for A records for: $FULL_DOMAIN${NC}"
    
    RECORDS=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$ZONE_ID" \
        --region "$AWS_REGION" \
        --query "ResourceRecordSets[?Name=='${FULL_DOMAIN}.' && Type=='A']" \
        --output json)
    
    if [ "$RECORDS" = "[]" ]; then
        echo -e "${GREEN}✅ No A records found for $FULL_DOMAIN${NC}"
    else
        echo -e "${YELLOW}🗑️  Found A records for $FULL_DOMAIN, deleting...${NC}"
        
        # Parse the records and delete them
        echo "$RECORDS" | jq -r '.[] | @base64' | while read -r record; do
            RECORD_JSON=$(echo "$record" | base64 -d)
            RECORD_TYPE=$(echo "$RECORD_JSON" | jq -r '.Type')
            RECORD_NAME=$(echo "$RECORD_JSON" | jq -r '.Name')
            
            # Double-check we're only deleting our specific subdomain
            if [ "$RECORD_NAME" = "${FULL_DOMAIN}." ]; then
                # Create change batch for deletion
                CHANGE_BATCH=$(cat <<EOF
{
    "Changes": [
        {
            "Action": "DELETE",
            "ResourceRecordSet": $RECORD_JSON
        }
    ]
}
EOF
)
                
                echo -e "${YELLOW}🗑️  Deleting $RECORD_TYPE record: $RECORD_NAME${NC}"
                aws route53 change-resource-record-sets \
                    --hosted-zone-id "$ZONE_ID" \
                    --change-batch "$CHANGE_BATCH" \
                    --region "$AWS_REGION" > /dev/null || true
            else
                echo -e "${RED}⚠️  Skipping record with unexpected name: $RECORD_NAME${NC}"
            fi
        done
    fi
    
    # Also clean up TXT records ONLY for our specific subdomain and only if they contain ExternalDNS heritage
    echo -e "${YELLOW}🔍 Looking for ExternalDNS TXT records for: $FULL_DOMAIN${NC}"
    
    TXT_RECORDS=$(aws route53 list-resource-record-sets \
        --hosted-zone-id "$ZONE_ID" \
        --region "$AWS_REGION" \
        --query "ResourceRecordSets[?Name=='${FULL_DOMAIN}.' && Type=='TXT']" \
        --output json)
    
    if [ "$TXT_RECORDS" != "[]" ]; then
        echo -e "${YELLOW}🔍 Found TXT records for $FULL_DOMAIN, checking for ExternalDNS records...${NC}"
        
        echo "$TXT_RECORDS" | jq -r '.[] | @base64' | while read -r record; do
            RECORD_JSON=$(echo "$record" | base64 -d)
            RECORD_NAME=$(echo "$RECORD_JSON" | jq -r '.Name')
            RECORD_VALUE=$(echo "$RECORD_JSON" | jq -r '.ResourceRecords[0].Value')
            
            # Triple-check: correct subdomain AND ExternalDNS heritage
            if [ "$RECORD_NAME" = "${FULL_DOMAIN}." ] && echo "$RECORD_VALUE" | grep -q "heritage=external-dns"; then
                echo -e "${YELLOW}🗑️  Deleting ExternalDNS TXT record for $RECORD_NAME${NC}"
                
                CHANGE_BATCH=$(cat <<EOF
{
    "Changes": [
        {
            "Action": "DELETE",
            "ResourceRecordSet": $RECORD_JSON
        }
    ]
}
EOF
)
                
                aws route53 change-resource-record-sets \
                    --hosted-zone-id "$ZONE_ID" \
                    --change-batch "$CHANGE_BATCH" \
                    --region "$AWS_REGION" > /dev/null || true
            else
                echo -e "${GREEN}✅ Skipping TXT record (not ExternalDNS or wrong domain): $RECORD_NAME${NC}"
            fi
        done
    fi
    
    echo -e "${GREEN}✅ Route53 DNS records cleanup completed${NC}"
}
wait_for_aws_cleanup() {
    echo -e "${YELLOW}⏳ Waiting for AWS Load Balancer Controller to clean up AWS resources...${NC}"
    
    # Wait for ALBs to be cleaned up
    local wait_time=0
    local max_wait=120 # 2 minutes
    
    while [ $wait_time -lt $max_wait ]; do
        # Check if any ALBs still exist with k8s tags
        ALBS=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query 'LoadBalancers[*].LoadBalancerName' --output text 2>/dev/null | grep -c "k8s-" || echo "0")
        
        if [ "$ALBS" -eq 0 ]; then
            echo -e "${GREEN}✅ AWS Load Balancer Controller cleanup completed${NC}"
            return
        fi
        
        echo -e "${YELLOW}⏳ Still waiting for ALBs to be deleted... (${wait_time}s/${max_wait}s)${NC}"
        sleep 10
        wait_time=$((wait_time + 10))
    done
    
    echo -e "${YELLOW}⚠️  Timeout waiting for automatic cleanup, proceeding anyway${NC}"
}

# Function to check RDS deletion protection
check_rds_deletion_protection() {
    echo -e "${YELLOW}🔍 Checking RDS deletion protection...${NC}"
    
    DB_IDENTIFIER="${PROJECT_TAG}-${ENVIRONMENT}-db"
    
    # Check if RDS instance exists
    if aws rds describe-db-instances --db-instance-identifier "$DB_IDENTIFIER" --region "$AWS_REGION" &> /dev/null; then
        echo -e "${YELLOW}📊 Found RDS instance: $DB_IDENTIFIER${NC}"
        
        # Check if deletion protection is enabled
        DELETION_PROTECTION=$(aws rds describe-db-instances \
            --db-instance-identifier "$DB_IDENTIFIER" \
            --region "$AWS_REGION" \
            --query "DBInstances[0].DeletionProtection" \
            --output text)
        
        if [ "$DELETION_PROTECTION" = "true" ]; then
            echo -e "${YELLOW}🔧 Disabling deletion protection for RDS instance...${NC}"
            aws rds modify-db-instance \
                --db-instance-identifier "$DB_IDENTIFIER" \
                --region "$AWS_REGION" \
                --no-deletion-protection \
                --apply-immediately
            
            echo -e "${YELLOW}⏳ Waiting for RDS modification to complete...${NC}"
            aws rds wait db-instance-available --db-instance-identifier "$DB_IDENTIFIER" --region "$AWS_REGION"
            echo -e "${GREEN}✅ RDS deletion protection disabled${NC}"
        else
            echo -e "${GREEN}✅ RDS deletion protection is already disabled${NC}"
        fi
    else
        echo -e "${GREEN}✅ No RDS instance found${NC}"
    fi
}

# # Function to run terraform destroy
# run_terraform_destroy() {
#     echo -e "${YELLOW}🚀 Running Terraform destroy...${NC}"
#     
#     # Check if we're in the right directory
#     if [ ! -f "environments/dev/terraform.tfvars" ]; then
#         echo -e "${RED}❌ Error: Please run this script from the project root directory${NC}"
#         exit 1
#     fi
#     
#     cd main/
#     
#     # Run terraform destroy
#     echo -e "${YELLOW}💥 Running: terraform destroy -var-file=\"../environments/dev/terraform.tfvars\"${NC}"
#     terraform destroy -var-file="../environments/dev/terraform.tfvars" -auto-approve
#     
#     echo -e "${GREEN}✅ Terraform destroy completed successfully!${NC}"
# }

# Main execution
main() {
    echo -e "${GREEN}🔍 Starting pre-destroy cleanup verification...${NC}"
    
    check_aws_cli
    verify_target_resources
    
    # Ask for confirmation before proceeding
    echo -e "${YELLOW}⚠️  Are you sure you want to proceed with cleanup? This will delete the resources shown above.${NC}"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}❌ Cleanup cancelled by user${NC}"
        exit 0
    fi
    
    echo -e "${GREEN}🧹 Starting cleanup process...${NC}"
    
    cleanup_kubernetes_ingress
    wait_for_aws_cleanup
    cleanup_external_dns_records
    check_rds_deletion_protection
    
    echo -e "${GREEN}🎉 Pre-destroy cleanup completed successfully!${NC}"
    echo -e "${YELLOW}📋 Summary of actions taken:${NC}"
    echo -e "   • Deleted Kubernetes ingress resources for cluster: ${CLUSTER_NAME}"
    echo -e "   • Deleted LoadBalancer services for cluster: ${CLUSTER_NAME}"
    echo -e "   • Waited for AWS Load Balancer Controller to clean up ALBs/TGs/SGs"
    echo -e "   • Cleaned up Route53 DNS records for: project-5.projects-devops.cfd"
    echo -e "   • Checked/disabled RDS deletion protection for: ${PROJECT_TAG}-${ENVIRONMENT}-db"
    echo ""
    echo -e "${GREEN}✅ Ready for Terraform destroy!${NC}"
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo -e "   1. Go to your Terraform repo"
    echo -e "   2. Run: cd main/"
    echo -e "   3. Run: terraform destroy -var-file=\"../environments/dev/terraform.tfvars\""
    echo -e "   OR use your existing script:"
    echo -e "   4. Run: ./scripts/plan_and_destroy.sh dev destroy filter single normal"
}

# # Check if we're running from the correct directory
# if [ ! -f "environments/dev/terraform.tfvars" ]; then
#     echo -e "${RED}❌ Error: Please run this script from the project root directory${NC}"
#     echo -e "${YELLOW}Expected to find: environments/dev/terraform.tfvars${NC}"
#     exit 1
# fi

# Run main function
main "$@"