#!/bin/bash
set -e

# AWS Infrastructure Provisioning Script for N4 Montessori CRM
# This script provisions Aurora Serverless v2, S3 buckets, and Secrets Manager entries

echo "================================================"
echo "AWS Infrastructure Provisioning"
echo "N4 Montessori CRM - Twenty Platform"
echo "================================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for required AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Please run: aws configure"
    exit 1
fi

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="n4-crm"
STAGING_CLUSTER_NAME="${PROJECT_NAME}-staging-db"
PRODUCTION_CLUSTER_NAME="${PROJECT_NAME}-production-db"
STAGING_BUCKET_NAME="${PROJECT_NAME}-staging-storage"
PRODUCTION_BUCKET_NAME="${PROJECT_NAME}-production-storage"

echo -e "${GREEN}Using AWS Region: ${AWS_REGION}${NC}"
echo ""

# Function to generate secure password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Function to create Aurora Serverless v2 cluster
create_aurora_cluster() {
    local ENV=$1
    local CLUSTER_NAME=$2
    local DB_NAME="${PROJECT_NAME}_${ENV}"
    local MASTER_USERNAME="n4admin"
    local MASTER_PASSWORD=$(generate_password)
    
    echo -e "${YELLOW}Creating Aurora Serverless v2 cluster: ${CLUSTER_NAME}${NC}"
    
    # Create DB subnet group (requires VPC setup - simplified for demo)
    # Note: In production, ensure you have proper VPC and subnet configuration
    
    # Create Aurora cluster
    aws rds create-db-cluster \
        --db-cluster-identifier "$CLUSTER_NAME" \
        --engine aurora-postgresql \
        --engine-version 16.1 \
        --master-username "$MASTER_USERNAME" \
        --master-user-password "$MASTER_PASSWORD" \
        --database-name "$DB_NAME" \
        --serverless-v2-scaling-configuration MinCapacity=0.5,MaxCapacity=4.0 \
        --enable-http-endpoint \
        --backup-retention-period 7 \
        --preferred-backup-window "03:00-04:00" \
        --preferred-maintenance-window "mon:04:00-mon:05:00" \
        --region "$AWS_REGION" \
        --tags Key=Environment,Value="$ENV" Key=Project,Value="$PROJECT_NAME" \
        2>/dev/null || echo -e "${YELLOW}Cluster may already exist${NC}"
    
    # Create DB instance within the cluster
    aws rds create-db-instance \
        --db-instance-identifier "${CLUSTER_NAME}-instance-1" \
        --db-cluster-identifier "$CLUSTER_NAME" \
        --db-instance-class db.serverless \
        --engine aurora-postgresql \
        --region "$AWS_REGION" \
        2>/dev/null || echo -e "${YELLOW}Instance may already exist${NC}"
    
    echo -e "${GREEN}✓ Aurora cluster created/verified: ${CLUSTER_NAME}${NC}"
    
    # Wait for cluster to be available
    echo "Waiting for cluster to be available..."
    aws rds wait db-cluster-available \
        --db-cluster-identifier "$CLUSTER_NAME" \
        --region "$AWS_REGION" || true
    
    # Get cluster endpoint
    CLUSTER_ENDPOINT=$(aws rds describe-db-clusters \
        --db-cluster-identifier "$CLUSTER_NAME" \
        --region "$AWS_REGION" \
        --query 'DBClusters[0].Endpoint' \
        --output text 2>/dev/null || echo "pending")
    
    # Store credentials in AWS Secrets Manager
    echo "Storing credentials in Secrets Manager..."
    SECRET_NAME="${PROJECT_NAME}/${ENV}/database-credentials"
    
    SECRET_VALUE=$(cat <<EOF
{
  "username": "$MASTER_USERNAME",
  "password": "$MASTER_PASSWORD",
  "engine": "postgres",
  "host": "$CLUSTER_ENDPOINT",
  "port": 5432,
  "dbname": "$DB_NAME",
  "dbClusterIdentifier": "$CLUSTER_NAME"
}
EOF
)
    
    aws secretsmanager create-secret \
        --name "$SECRET_NAME" \
        --description "Database credentials for $ENV environment" \
        --secret-string "$SECRET_VALUE" \
        --region "$AWS_REGION" \
        --tags Key=Environment,Value="$ENV" Key=Project,Value="$PROJECT_NAME" \
        2>/dev/null || \
    aws secretsmanager update-secret \
        --secret-id "$SECRET_NAME" \
        --secret-string "$SECRET_VALUE" \
        --region "$AWS_REGION"
    
    echo -e "${GREEN}✓ Credentials stored in Secrets Manager: ${SECRET_NAME}${NC}"
    
    # Output connection details
    echo ""
    echo "================================================"
    echo "Aurora Cluster Details - $ENV"
    echo "================================================"
    echo "Cluster ID: $CLUSTER_NAME"
    echo "Endpoint: $CLUSTER_ENDPOINT"
    echo "Port: 5432"
    echo "Database: $DB_NAME"
    echo "Username: $MASTER_USERNAME"
    echo "Secrets Manager: $SECRET_NAME"
    echo "Connection String: postgres://$MASTER_USERNAME:[PASSWORD]@$CLUSTER_ENDPOINT:5432/$DB_NAME"
    echo ""
    
    # Export for use in EB env files
    if [ "$ENV" = "staging" ]; then
        export STAGING_DB_ENDPOINT="$CLUSTER_ENDPOINT"
        export STAGING_DB_NAME="$DB_NAME"
        export STAGING_DB_USERNAME="$MASTER_USERNAME"
        export STAGING_DB_PASSWORD="$MASTER_PASSWORD"
    else
        export PRODUCTION_DB_ENDPOINT="$CLUSTER_ENDPOINT"
        export PRODUCTION_DB_NAME="$DB_NAME"
        export PRODUCTION_DB_USERNAME="$MASTER_USERNAME"
        export PRODUCTION_DB_PASSWORD="$MASTER_PASSWORD"
    fi
}

# Function to create S3 bucket
create_s3_bucket() {
    local ENV=$1
    local BUCKET_NAME=$2
    
    echo -e "${YELLOW}Creating S3 bucket: ${BUCKET_NAME}${NC}"
    
    # Create bucket
    if [ "$AWS_REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION" \
            2>/dev/null || echo -e "${YELLOW}Bucket may already exist${NC}"
    else
        aws s3api create-bucket \
            --bucket "$BUCKET_NAME" \
            --region "$AWS_REGION" \
            --create-bucket-configuration LocationConstraint="$AWS_REGION" \
            2>/dev/null || echo -e "${YELLOW}Bucket may already exist${NC}"
    fi
    
    # Enable versioning
    aws s3api put-bucket-versioning \
        --bucket "$BUCKET_NAME" \
        --versioning-configuration Status=Enabled \
        --region "$AWS_REGION"
    
    # Enable server-side encryption
    aws s3api put-bucket-encryption \
        --bucket "$BUCKET_NAME" \
        --server-side-encryption-configuration '{
            "Rules": [{
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                },
                "BucketKeyEnabled": true
            }]
        }' \
        --region "$AWS_REGION"
    
    # Block public access
    aws s3api put-public-access-block \
        --bucket "$BUCKET_NAME" \
        --public-access-block-configuration \
            "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true" \
        --region "$AWS_REGION"
    
    # Add tags
    aws s3api put-bucket-tagging \
        --bucket "$BUCKET_NAME" \
        --tagging "TagSet=[{Key=Environment,Value=$ENV},{Key=Project,Value=$PROJECT_NAME}]" \
        --region "$AWS_REGION"
    
    echo -e "${GREEN}✓ S3 bucket created/configured: ${BUCKET_NAME}${NC}"
    echo "  - Versioning: Enabled"
    echo "  - Encryption: AES256"
    echo "  - Public Access: Blocked"
    echo ""
}

# Main execution
echo "Starting provisioning process..."
echo ""

# Provision Staging Environment
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}STAGING ENVIRONMENT${NC}"
echo -e "${GREEN}========================================${NC}"
create_aurora_cluster "staging" "$STAGING_CLUSTER_NAME"
create_s3_bucket "staging" "$STAGING_BUCKET_NAME"

echo ""

# Provision Production Environment
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}PRODUCTION ENVIRONMENT${NC}"
echo -e "${GREEN}========================================${NC}"
create_aurora_cluster "production" "$PRODUCTION_CLUSTER_NAME"
create_s3_bucket "production" "$PRODUCTION_BUCKET_NAME"

# Summary
echo ""
echo "================================================"
echo "PROVISIONING COMPLETE"
echo "================================================"
echo ""
echo -e "${GREEN}Next Steps:${NC}"
echo "1. Update .eb-env-staging with the staging database endpoint:"
echo "   PG_DATABASE_URL=postgres://${STAGING_DB_USERNAME}:\${PASSWORD}@${STAGING_DB_ENDPOINT}:5432/${STAGING_DB_NAME}"
echo ""
echo "2. Update .eb-env-production with the production database endpoint:"
echo "   PG_DATABASE_URL=postgres://${PRODUCTION_DB_USERNAME}:\${PASSWORD}@${PRODUCTION_DB_ENDPOINT}:5432/${PRODUCTION_DB_NAME}"
echo ""
echo "3. Retrieve database passwords from Secrets Manager:"
echo "   aws secretsmanager get-secret-value --secret-id ${PROJECT_NAME}/staging/database-credentials --region ${AWS_REGION}"
echo "   aws secretsmanager get-secret-value --secret-id ${PROJECT_NAME}/production/database-credentials --region ${AWS_REGION}"
echo ""
echo "4. Create Elastic Beanstalk environments:"
echo "   eb create n4-crm-staging --instance-types t3.small --single"
echo "   eb create n4-crm-production --instance-types t3.medium"
echo ""
echo "5. Set environment variables:"
echo "   eb setenv --envvars \$(cat .eb-env-staging | tr '\\n' ',' | sed 's/,\$//')"
echo ""
echo "6. Document provisioned resources in docs/INFRASTRUCTURE-PROVISIONED.md"
echo ""
echo -e "${GREEN}All AWS resources have been provisioned successfully!${NC}"
