# AWS Infrastructure Setup - Quick Reference

This guide provides quick instructions for setting up AWS infrastructure for N4 Montessori CRM.

## Prerequisites

- [ ] AWS CLI installed (`aws --version`)
- [ ] AWS credentials configured (`aws configure`)
- [ ] Elastic Beanstalk CLI installed (`eb --version`)
- [ ] Appropriate AWS permissions (RDS, S3, EB, Secrets Manager)

## Step-by-Step Setup

### Phase 1: Provision Infrastructure

```bash
# 1. Run the provisioning script
./scripts/provision-aws-infrastructure.sh

# 2. Note the output - you'll need:
#    - Aurora endpoints
#    - S3 bucket names
#    - Secrets Manager secret names
```

### Phase 2: Configure Environment Variables

```bash
# 1. Create local environment files (not committed to git)
cp .eb-env-staging .eb-env-staging.local
cp .eb-env-production .eb-env-production.local

# 2. Retrieve database passwords from Secrets Manager
aws secretsmanager get-secret-value \
  --secret-id n4-crm/staging/database-credentials \
  --region us-east-1 \
  --query SecretString \
  --output text | jq -r .password

# 3. Edit .eb-env-staging.local and replace all REPLACE_WITH_* values
# 4. Do the same for .eb-env-production.local
```

### Phase 3: Create Elastic Beanstalk Environments

```bash
# 1. Initialize EB in the project
cd /path/to/twenty
eb init -p "Node.js 20" -r us-east-1 n4-crm

# 2. Create staging environment
eb create n4-crm-staging \
  --instance-types t3.small \
  --single \
  --envvars $(cat .eb-env-staging.local | tr '\n' ',' | sed 's/,$//')

# 3. Create production environment
eb create n4-crm-production \
  --instance-types t3.medium \
  --envvars $(cat .eb-env-production.local | tr '\n' ',' | sed 's/,$//')
```

### Phase 4: Deploy Application

```bash
# 1. Deploy to staging
eb deploy n4-crm-staging

# 2. Test staging environment
eb open n4-crm-staging
eb logs n4-crm-staging --tail

# 3. Deploy to production (after staging validation)
eb deploy n4-crm-production

# 4. Monitor production
eb status n4-crm-production
eb health n4-crm-production
```

### Phase 5: Verify and Document

```bash
# 1. Test database connectivity
eb ssh n4-crm-staging
# Inside the instance:
psql $PG_DATABASE_URL

# 2. Test S3 access (upload a test file via the app)

# 3. Update docs/INFRASTRUCTURE-PROVISIONED.md with actual values
```

## Common Commands

### Check Status
```bash
eb list                           # List all environments
eb status n4-crm-staging          # Get environment status
eb health n4-crm-staging          # Check health
```

### View Logs
```bash
eb logs n4-crm-staging           # View logs
eb logs n4-crm-staging --tail    # Tail logs in real-time
```

### Manage Environment Variables
```bash
# View current variables
eb printenv n4-crm-staging

# Update a single variable
eb setenv VARIABLE_NAME=value

# Update multiple variables
eb setenv --envvars $(cat .eb-env-staging.local | tr '\n' ',' | sed 's/,$//')
```

### Database Access
```bash
# Get database credentials
aws secretsmanager get-secret-value \
  --secret-id n4-crm/staging/database-credentials \
  --region us-east-1

# Check Aurora status
aws rds describe-db-clusters \
  --db-cluster-identifier n4-crm-staging-db \
  --region us-east-1
```

### S3 Management
```bash
# List buckets
aws s3 ls | grep n4-crm

# View bucket contents
aws s3 ls s3://n4-crm-staging-storage/

# Check bucket configuration
aws s3api get-bucket-versioning --bucket n4-crm-staging-storage
aws s3api get-bucket-encryption --bucket n4-crm-staging-storage
```

## Troubleshooting

### EB deployment fails
```bash
# Check logs
eb logs n4-crm-staging --tail

# SSH into instance
eb ssh n4-crm-staging

# Check environment health
eb health n4-crm-staging
```

### Database connection errors
```bash
# Verify connection string
eb printenv n4-crm-staging | grep PG_DATABASE_URL

# Check Aurora status
aws rds describe-db-clusters \
  --db-cluster-identifier n4-crm-staging-db \
  --region us-east-1

# Verify security groups allow EB -> Aurora traffic
```

### S3 access denied
```bash
# Verify bucket exists
aws s3 ls s3://n4-crm-staging-storage/

# Check IAM role attached to EB instances
# Ensure it has S3 read/write permissions
```

## Cost Monitoring

```bash
# View cost by service (requires Cost Explorer access)
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-30 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE

# Check resource tagging
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=n4-crm
```

## Useful Documentation

- [AWS Complete Architecture](./docs/AWS-COMPLETE-ARCHITECTURE.md)
- [Infrastructure Provisioned](./docs/INFRASTRUCTURE-PROVISIONED.md)
- [Scripts README](./scripts/README.md)
- [AWS Elastic Beanstalk Docs](https://docs.aws.amazon.com/elasticbeanstalk/)
- [AWS Aurora Serverless Docs](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2.html)

## Emergency Contacts

- **AWS Support**: [Your support plan]
- **Development Team**: development@n4montessori.com
- **Infrastructure Team**: infrastructure@n4montessori.com

---

**Quick Tip**: Bookmark this file for quick reference during deployments!
