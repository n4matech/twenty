# AWS Infrastructure Provisioning Scripts

This directory contains scripts for provisioning and managing AWS infrastructure for the N4 Montessori CRM.

## Available Scripts

### 1. provision-aws-infrastructure.sh

**Purpose**: Provisions all necessary AWS infrastructure for the N4 CRM platform.

**What it provisions**:
- Aurora Serverless v2 PostgreSQL clusters (staging + production)
- S3 storage buckets with versioning and encryption
- AWS Secrets Manager entries for database credentials

**Prerequisites**:
1. AWS CLI installed and configured
   ```bash
   aws --version
   aws configure
   ```

2. Appropriate AWS permissions:
   - RDS: CreateDBCluster, CreateDBInstance, DescribeDBClusters
   - S3: CreateBucket, PutBucketVersioning, PutBucketEncryption
   - Secrets Manager: CreateSecret, UpdateSecret
   - IAM: PassRole (for service roles)

3. OpenSSL for password generation

**Usage**:

```bash
# Run with default region (us-east-1)
./scripts/provision-aws-infrastructure.sh

# Or specify a different region
AWS_REGION=us-west-2 ./scripts/provision-aws-infrastructure.sh
```

**Output**:
The script will output:
- Aurora cluster endpoints
- S3 bucket names
- Secrets Manager secret names
- Connection strings for databases
- Instructions for next steps

**Important Notes**:
- The script is idempotent - it can be run multiple times safely
- Database passwords are automatically generated and stored in Secrets Manager
- All resources are tagged with Environment and Project tags
- The script includes retry logic and error handling

**After Running**:

1. **Retrieve database passwords**:
   ```bash
   # Staging
   aws secretsmanager get-secret-value \
     --secret-id n4-crm/staging/database-credentials \
     --region us-east-1 \
     --query SecretString \
     --output text | jq -r .password

   # Production
   aws secretsmanager get-secret-value \
     --secret-id n4-crm/production/database-credentials \
     --region us-east-1 \
     --query SecretString \
     --output text | jq -r .password
   ```

2. **Update environment files**:
   - Copy `.eb-env-staging` to `.eb-env-staging.local`
   - Copy `.eb-env-production` to `.eb-env-production.local`
   - Replace `REPLACE_WITH_*` placeholders with actual values
   - Never commit `.local` files

3. **Create Elastic Beanstalk environments**:
   ```bash
   # Staging
   cd /path/to/twenty
   eb init -p node.js-20 -r us-east-1 n4-crm
   eb create n4-crm-staging \
     --instance-types t3.small \
     --single \
     --envvars $(cat .eb-env-staging.local | tr '\n' ',' | sed 's/,$//')

   # Production
   eb create n4-crm-production \
     --instance-types t3.medium \
     --envvars $(cat .eb-env-production.local | tr '\n' ',' | sed 's/,$//')
   ```

4. **Verify resources**:
   ```bash
   # Check Aurora clusters
   aws rds describe-db-clusters \
     --db-cluster-identifier n4-crm-staging-db \
     --region us-east-1

   # Check S3 buckets
   aws s3 ls | grep n4-crm

   # Check EB environments
   eb list
   eb status n4-crm-staging
   ```

### 2. validate-aws-infrastructure.sh

**Purpose**: Validates that all provisioned AWS infrastructure is accessible and properly configured.

**What it checks**:
- Aurora Serverless v2 clusters (status, endpoint, instance)
- S3 buckets (existence, versioning, encryption, public access)
- AWS Secrets Manager entries (existence, readability, structure)
- Elastic Beanstalk environments (if EB CLI is installed)
- IAM roles (basic check for EB service role)

**Usage**:

```bash
# Run validation
./scripts/validate-aws-infrastructure.sh

# Or specify a different region
AWS_REGION=us-west-2 ./scripts/validate-aws-infrastructure.sh
```

**Exit Codes**:
- `0`: All checks passed or only warnings
- `1`: One or more errors found

**Output**:
- Green ✓: Check passed
- Yellow ⚠: Warning (non-critical issue)
- Red ✗: Error (requires attention)

**When to run**:
- After running `provision-aws-infrastructure.sh`
- Before deploying to Elastic Beanstalk
- During troubleshooting
- As part of CI/CD health checks

**Example Output**:
```
================================================
AWS Infrastructure Validation
N4 Montessori CRM - Twenty Platform
================================================

✓ AWS CLI is installed
✓ AWS credentials configured (Account: 123456789012)

================================================
Validating Aurora Clusters
================================================
Checking staging Aurora cluster...
  ✓ Cluster exists and is available
    Endpoint: n4-crm-staging-db.cluster-xxxxx.us-east-1.rds.amazonaws.com
  ✓ Instance is available
...
```

## Cost Estimates

Running the provisioning script creates resources with the following estimated costs:

| Resource | Staging | Production |
|----------|---------|------------|
| Aurora Serverless v2 | ~$20-40/mo | ~$40-80/mo |
| S3 Storage | ~$5-10/mo | ~$10-20/mo |
| **Subtotal** | **~$25-50/mo** | **~$50-100/mo** |

Plus Elastic Beanstalk:
- Staging (t3.small, single, spot): ~$10-15/month
- Production (t3.medium, 1-4 instances): ~$50-150/month

**Total Estimated Monthly Cost**: ~$135-315/month

*Note: Actual costs depend on usage patterns.*

## Troubleshooting

### "Cluster already exists" error
This is normal if re-running the script. The script handles existing resources gracefully.

### "Invalid credentials" error
Ensure AWS CLI is configured:
```bash
aws configure list
aws sts get-caller-identity
```

### "Insufficient permissions" error
Your IAM user/role needs permissions for RDS, S3, Secrets Manager. Contact your AWS administrator.

### Database not accessible from EB
Check security groups - ensure EB security group can access Aurora security group on port 5432.

### S3 bucket name already taken
S3 bucket names are globally unique. Modify bucket names in the script if needed.

## Security Best Practices

1. **Never commit credentials**: Use `.eb-env-*.local` files for actual values
2. **Use IAM roles**: Attach IAM roles to EB instances instead of using access keys
3. **Rotate passwords**: Regularly update passwords in Secrets Manager
4. **Enable MFA**: Use MFA for AWS console access
5. **Audit logs**: Review CloudTrail logs regularly
6. **Least privilege**: Grant minimal required permissions

## Related Documentation

- [AWS Complete Architecture](../docs/AWS-COMPLETE-ARCHITECTURE.md)
- [Infrastructure Provisioned](../docs/INFRASTRUCTURE-PROVISIONED.md)
- [Post-Provisioning Checklist](../docs/POST-PROVISIONING-CHECKLIST.md)
- [Scripts README](./README.md)
- [EB Configuration](../.ebextensions/)

## Support

For issues or questions:
- Create an issue in the repository
- Contact the infrastructure team
- Review AWS documentation: https://docs.aws.amazon.com/

---

**Last Updated**: November 2025
