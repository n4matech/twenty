#!/bin/bash
set -e

# AWS Infrastructure Validation Script for N4 Montessori CRM
# This script validates that all provisioned AWS resources are accessible and configured correctly

echo "================================================"
echo "AWS Infrastructure Validation"
echo "N4 Montessori CRM - Twenty Platform"
echo "================================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="n4-crm"
ERRORS=0
WARNINGS=0

echo -e "${BLUE}Using AWS Region: ${AWS_REGION}${NC}"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI is installed${NC}"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS credentials not configured${NC}"
    exit 1
fi
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✓ AWS credentials configured (Account: ${ACCOUNT_ID})${NC}"
echo ""

echo "================================================"
echo "Validating Aurora Clusters"
echo "================================================"

# Function to check Aurora cluster
check_aurora_cluster() {
    local ENV=$1
    local CLUSTER_NAME="${PROJECT_NAME}-${ENV}-db"
    
    echo -e "${YELLOW}Checking ${ENV} Aurora cluster...${NC}"
    
    if aws rds describe-db-clusters \
        --db-cluster-identifier "$CLUSTER_NAME" \
        --region "$AWS_REGION" &> /dev/null; then
        
        STATUS=$(aws rds describe-db-clusters \
            --db-cluster-identifier "$CLUSTER_NAME" \
            --region "$AWS_REGION" \
            --query 'DBClusters[0].Status' \
            --output text)
        
        ENDPOINT=$(aws rds describe-db-clusters \
            --db-cluster-identifier "$CLUSTER_NAME" \
            --region "$AWS_REGION" \
            --query 'DBClusters[0].Endpoint' \
            --output text)
        
        if [ "$STATUS" = "available" ]; then
            echo -e "${GREEN}  ✓ Cluster exists and is available${NC}"
            echo -e "    Endpoint: ${ENDPOINT}"
        else
            echo -e "${YELLOW}  ⚠ Cluster exists but status is: ${STATUS}${NC}"
            ((WARNINGS++))
        fi
        
        # Check instance
        INSTANCE_STATUS=$(aws rds describe-db-instances \
            --db-instance-identifier "${CLUSTER_NAME}-instance-1" \
            --region "$AWS_REGION" \
            --query 'DBInstances[0].DBInstanceStatus' \
            --output text 2>/dev/null || echo "not-found")
        
        if [ "$INSTANCE_STATUS" = "available" ]; then
            echo -e "${GREEN}  ✓ Instance is available${NC}"
        else
            echo -e "${YELLOW}  ⚠ Instance status: ${INSTANCE_STATUS}${NC}"
            ((WARNINGS++))
        fi
    else
        echo -e "${RED}  ✗ Cluster not found${NC}"
        ((ERRORS++))
    fi
    echo ""
}

check_aurora_cluster "staging"
check_aurora_cluster "production"

echo "================================================"
echo "Validating S3 Buckets"
echo "================================================"

# Function to check S3 bucket
check_s3_bucket() {
    local ENV=$1
    local BUCKET_NAME="${PROJECT_NAME}-${ENV}-storage"
    
    echo -e "${YELLOW}Checking ${ENV} S3 bucket...${NC}"
    
    if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$AWS_REGION" 2>/dev/null; then
        echo -e "${GREEN}  ✓ Bucket exists and is accessible${NC}"
        
        # Check versioning
        VERSIONING=$(aws s3api get-bucket-versioning \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION" \
            --query 'Status' \
            --output text 2>/dev/null || echo "None")
        
        if [ "$VERSIONING" = "Enabled" ]; then
            echo -e "${GREEN}  ✓ Versioning is enabled${NC}"
        else
            echo -e "${YELLOW}  ⚠ Versioning is not enabled${NC}"
            ((WARNINGS++))
        fi
        
        # Check encryption
        if aws s3api get-bucket-encryption \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION" &> /dev/null; then
            echo -e "${GREEN}  ✓ Encryption is enabled${NC}"
        else
            echo -e "${YELLOW}  ⚠ Encryption is not enabled${NC}"
            ((WARNINGS++))
        fi
        
        # Check public access block
        if aws s3api get-public-access-block \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION" \
            --query 'PublicAccessBlockConfiguration.BlockPublicAcls' \
            --output text 2>/dev/null | grep -q "True"; then
            echo -e "${GREEN}  ✓ Public access is blocked${NC}"
        else
            echo -e "${RED}  ✗ Public access is not properly blocked${NC}"
            ((ERRORS++))
        fi
    else
        echo -e "${RED}  ✗ Bucket not found or not accessible${NC}"
        ((ERRORS++))
    fi
    echo ""
}

check_s3_bucket "staging"
check_s3_bucket "production"

echo "================================================"
echo "Validating Secrets Manager"
echo "================================================"

# Function to check secrets
check_secret() {
    local ENV=$1
    local SECRET_NAME="${PROJECT_NAME}/${ENV}/database-credentials"
    
    echo -e "${YELLOW}Checking ${ENV} secrets...${NC}"
    
    if aws secretsmanager describe-secret \
        --secret-id "$SECRET_NAME" \
        --region "$AWS_REGION" &> /dev/null; then
        echo -e "${GREEN}  ✓ Secret exists${NC}"
        
        # Try to retrieve secret value (will fail if no permissions)
        if aws secretsmanager get-secret-value \
            --secret-id "$SECRET_NAME" \
            --region "$AWS_REGION" &> /dev/null; then
            echo -e "${GREEN}  ✓ Secret is readable${NC}"
            
            # Validate secret structure
            SECRET_JSON=$(aws secretsmanager get-secret-value \
                --secret-id "$SECRET_NAME" \
                --region "$AWS_REGION" \
                --query 'SecretString' \
                --output text)
            
            if echo "$SECRET_JSON" | jq -e '.username' &> /dev/null && \
               echo "$SECRET_JSON" | jq -e '.password' &> /dev/null && \
               echo "$SECRET_JSON" | jq -e '.host' &> /dev/null; then
                echo -e "${GREEN}  ✓ Secret has required fields${NC}"
            else
                echo -e "${RED}  ✗ Secret is missing required fields${NC}"
                ((ERRORS++))
            fi
        else
            echo -e "${YELLOW}  ⚠ Cannot read secret (check permissions)${NC}"
            ((WARNINGS++))
        fi
    else
        echo -e "${RED}  ✗ Secret not found${NC}"
        ((ERRORS++))
    fi
    echo ""
}

check_secret "staging"
check_secret "production"

echo "================================================"
echo "Validating Elastic Beanstalk"
echo "================================================"

# Check if EB CLI is available
if command -v eb &> /dev/null; then
    echo -e "${GREEN}✓ EB CLI is installed${NC}"
    
    # Try to list EB environments
    if eb list &> /dev/null; then
        echo -e "${GREEN}✓ EB is initialized${NC}"
        
        # Check staging environment
        if eb list | grep -q "${PROJECT_NAME}-staging"; then
            echo -e "${GREEN}✓ Staging environment exists${NC}"
            STATUS=$(eb status ${PROJECT_NAME}-staging 2>/dev/null | grep "Status:" | awk '{print $2}')
            echo -e "  Status: ${STATUS}"
        else
            echo -e "${YELLOW}⚠ Staging environment not found${NC}"
            ((WARNINGS++))
        fi
        
        # Check production environment
        if eb list | grep -q "${PROJECT_NAME}-production"; then
            echo -e "${GREEN}✓ Production environment exists${NC}"
            STATUS=$(eb status ${PROJECT_NAME}-production 2>/dev/null | grep "Status:" | awk '{print $2}')
            echo -e "  Status: ${STATUS}"
        else
            echo -e "${YELLOW}⚠ Production environment not found${NC}"
            ((WARNINGS++))
        fi
    else
        echo -e "${YELLOW}⚠ EB not initialized in this directory${NC}"
        echo -e "  Run: eb init -p node.js-20 -r ${AWS_REGION} ${PROJECT_NAME}"
        ((WARNINGS++))
    fi
else
    echo -e "${YELLOW}⚠ EB CLI is not installed${NC}"
    echo -e "  Install from: https://docs.aws.amazon.com/elasticbeanstalk/latest/dg/eb-cli3-install.html"
    ((WARNINGS++))
fi
echo ""

# Check IAM roles (basic check)
echo "================================================"
echo "Checking IAM Roles"
echo "================================================"

if aws iam get-role --role-name "aws-elasticbeanstalk-service-role" &> /dev/null; then
    echo -e "${GREEN}✓ Elastic Beanstalk service role exists${NC}"
else
    echo -e "${YELLOW}⚠ Elastic Beanstalk service role not found${NC}"
    echo -e "  Create at: https://console.aws.amazon.com/iam/"
    ((WARNINGS++))
fi
echo ""

# Summary
echo "================================================"
echo "VALIDATION SUMMARY"
echo "================================================"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed! Infrastructure is properly configured.${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Validation completed with ${WARNINGS} warning(s).${NC}"
    echo -e "  Review warnings above. Infrastructure is mostly configured."
    exit 0
else
    echo -e "${RED}✗ Validation failed with ${ERRORS} error(s) and ${WARNINGS} warning(s).${NC}"
    echo -e "  Please review and fix the errors above."
    exit 1
fi
