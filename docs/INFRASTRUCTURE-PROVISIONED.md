# Infrastructure Provisioned - N4 Montessori CRM

## Overview

This document tracks all AWS infrastructure resources provisioned for the N4 Montessori CRM platform.

**Last Updated**: [To be filled after provisioning]  
**AWS Region**: us-east-1  
**Project**: N4 Montessori CRM

## Provisioned Resources

### 1. Aurora Serverless v2 - Staging

**Status**: ⏳ Pending / ✅ Provisioned  
**Cluster Identifier**: `n4-crm-staging-db`  
**Instance Identifier**: `n4-crm-staging-db-instance-1`  
**Database Name**: `n4_crm_staging`  
**Engine**: PostgreSQL 16.1  
**Endpoint**: [To be filled after provisioning]  
**Port**: 5432  
**Scaling Configuration**:
- Min Capacity: 0.5 ACU
- Max Capacity: 4.0 ACU

**Backup Configuration**:
- Retention Period: 7 days
- Backup Window: 03:00-04:00 UTC
- Maintenance Window: Monday 04:00-05:00 UTC

**Tags**:
- Environment: staging
- Project: n4-crm

**Secrets Manager**:
- Secret Name: `n4-crm/staging/database-credentials`
- Contains: username, password, host, port, dbname

**Connection String**:
```
postgres://n4admin:[PASSWORD]@[ENDPOINT]:5432/n4_crm_staging
```

**Cost Estimate**: ~$20-40/month (depending on usage)

---

### 2. Aurora Serverless v2 - Production

**Status**: ⏳ Pending / ✅ Provisioned  
**Cluster Identifier**: `n4-crm-production-db`  
**Instance Identifier**: `n4-crm-production-db-instance-1`  
**Database Name**: `n4_crm_production`  
**Engine**: PostgreSQL 16.1  
**Endpoint**: [To be filled after provisioning]  
**Port**: 5432  
**Scaling Configuration**:
- Min Capacity: 0.5 ACU
- Max Capacity: 4.0 ACU

**Backup Configuration**:
- Retention Period: 7 days
- Backup Window: 03:00-04:00 UTC
- Maintenance Window: Monday 04:00-05:00 UTC

**Tags**:
- Environment: production
- Project: n4-crm

**Secrets Manager**:
- Secret Name: `n4-crm/production/database-credentials`
- Contains: username, password, host, port, dbname

**Connection String**:
```
postgres://n4admin:[PASSWORD]@[ENDPOINT]:5432/n4_crm_production
```

**Cost Estimate**: ~$40-80/month (depending on usage)

---

### 3. S3 Bucket - Staging

**Status**: ⏳ Pending / ✅ Provisioned  
**Bucket Name**: `n4-crm-staging-storage`  
**Region**: us-east-1  

**Configuration**:
- ✅ Versioning: Enabled
- ✅ Encryption: AES-256 (Server-Side)
- ✅ Public Access: Blocked
- ✅ Bucket Key: Enabled

**Tags**:
- Environment: staging
- Project: n4-crm

**Access**: 
- Via IAM role attached to Elastic Beanstalk instances
- No public access

**Cost Estimate**: ~$5-10/month (depending on storage and requests)

---

### 4. S3 Bucket - Production

**Status**: ⏳ Pending / ✅ Provisioned  
**Bucket Name**: `n4-crm-production-storage`  
**Region**: us-east-1  

**Configuration**:
- ✅ Versioning: Enabled
- ✅ Encryption: AES-256 (Server-Side)
- ✅ Public Access: Blocked
- ✅ Bucket Key: Enabled

**Tags**:
- Environment: production
- Project: n4-crm

**Access**: 
- Via IAM role attached to Elastic Beanstalk instances
- No public access

**Cost Estimate**: ~$10-20/month (depending on storage and requests)

---

### 5. Elastic Beanstalk - Staging

**Status**: ⏳ Pending / ✅ Provisioned  
**Environment Name**: `n4-crm-staging`  
**Platform**: Node.js 20 running on 64bit Amazon Linux 2023  
**Instance Type**: t3.small  
**Deployment**: Single instance  

**Configuration**:
- Spot Instances: 100% (cost optimization)
- Auto Scaling: Disabled
- Load Balancer: Application Load Balancer

**Configured Environment Variables**:
- ✅ NODE_ENV
- ✅ PG_DATABASE_URL
- ✅ STORAGE_TYPE
- ✅ STORAGE_S3_NAME
- ✅ STORAGE_S3_REGION
- ✅ APP_SECRET
- ✅ FRONTEND_URL
- ✅ SERVER_URL

**URL**: [To be filled after provisioning]

**Cost Estimate**: ~$10-15/month (with spot instances)

---

### 6. Elastic Beanstalk - Production

**Status**: ⏳ Pending / ✅ Provisioned  
**Environment Name**: `n4-crm-production`  
**Platform**: Node.js 20 running on 64bit Amazon Linux 2023  
**Instance Type**: t3.medium  
**Deployment**: Load balanced  

**Configuration**:
- Min Instances: 1
- Max Instances: 4
- Auto Scaling Trigger: CPU > 70%
- Load Balancer: Application Load Balancer
- Health Monitoring: Enhanced

**Configured Environment Variables**:
- ✅ NODE_ENV
- ✅ PG_DATABASE_URL
- ✅ STORAGE_TYPE
- ✅ STORAGE_S3_NAME
- ✅ STORAGE_S3_REGION
- ✅ APP_SECRET
- ✅ FRONTEND_URL
- ✅ SERVER_URL

**URL**: [To be filled after provisioning]

**Cost Estimate**: ~$50-150/month (depending on scaling)

---

## Total Estimated Monthly Cost

- **Staging Environment**: ~$35-65/month
- **Production Environment**: ~$100-250/month
- **Total**: ~$135-315/month

*Note: These are estimates. Actual costs depend on usage patterns, data transfer, and scaling behavior.*

## Security Configuration

### IAM Roles Created
- ✅ Elastic Beanstalk Service Role
- ✅ EC2 Instance Profile Role with:
  - S3 access to designated buckets
  - Secrets Manager read access
  - CloudWatch Logs write access
  - RDS connect permissions

### Secrets Manager Entries
- ✅ `n4-crm/staging/database-credentials`
- ✅ `n4-crm/production/database-credentials`

### Security Groups
- [To be documented after provisioning]
- Application security group
- Database security group
- Load balancer security group

## Network Configuration

**VPC**: [To be filled]  
**Subnets**: [To be filled]  
**Availability Zones**: Multi-AZ for production  

## Monitoring and Alerting

### CloudWatch Alarms (Recommended)
- [ ] Aurora CPU > 80%
- [ ] Aurora connections > 80%
- [ ] EB environment health degraded
- [ ] Application error rate > 1%

### CloudWatch Dashboards
- [ ] Application performance dashboard
- [ ] Database metrics dashboard
- [ ] Cost tracking dashboard

## Backup and Recovery

### Aurora Backups
- Automated daily backups: ✅ Enabled
- Retention period: 7 days
- Point-in-time recovery: ✅ Enabled

### S3 Versioning
- Staging bucket: ✅ Enabled
- Production bucket: ✅ Enabled

## Deployment History

| Date | Environment | Action | Status | Notes |
|------|-------------|--------|--------|-------|
| [Date] | Staging | Initial Provisioning | ⏳ Pending | Aurora + S3 + EB |
| [Date] | Production | Initial Provisioning | ⏳ Pending | Aurora + S3 + EB |

## Access Information

### AWS Console Access
- Region: us-east-1
- Services:
  - RDS (Aurora Clusters)
  - S3 (Storage Buckets)
  - Elastic Beanstalk (Application Environments)
  - Secrets Manager (Credentials)
  - CloudWatch (Monitoring)

### Command Line Access

**Retrieve Database Credentials**:
```bash
# Staging
aws secretsmanager get-secret-value \
  --secret-id n4-crm/staging/database-credentials \
  --region us-east-1

# Production
aws secretsmanager get-secret-value \
  --secret-id n4-crm/production/database-credentials \
  --region us-east-1
```

**Access EB Environments**:
```bash
# Initialize EB CLI
eb init

# List environments
eb list

# Connect to environment
eb ssh n4-crm-staging
eb ssh n4-crm-production

# View logs
eb logs n4-crm-staging
eb logs n4-crm-production
```

**Check Aurora Status**:
```bash
# Staging
aws rds describe-db-clusters \
  --db-cluster-identifier n4-crm-staging-db \
  --region us-east-1

# Production
aws rds describe-db-clusters \
  --db-cluster-identifier n4-crm-production-db \
  --region us-east-1
```

## Next Steps

After provisioning is complete:

1. [ ] Update this document with actual resource identifiers and endpoints
2. [ ] Test database connectivity from EB instances
3. [ ] Verify S3 bucket access and file upload/download
4. [ ] Configure CloudWatch alarms
5. [ ] Set up CloudWatch dashboards
6. [ ] Configure custom domain names in Route 53
7. [ ] Set up SSL certificates in ACM
8. [ ] Configure SMTP for email delivery
9. [ ] Run database migrations
10. [ ] Deploy application to EB environments
11. [ ] Perform end-to-end testing
12. [ ] Document operational procedures

## Support Contacts

- **AWS Support**: [Support plan level]
- **Development Team**: development@n4montessori.com
- **Infrastructure Team**: infrastructure@n4montessori.com

## Related Documentation

- [AWS Complete Architecture](./AWS-COMPLETE-ARCHITECTURE.md)
- [Provisioning Script](../scripts/provision-aws-infrastructure.sh)
- [EB Configuration Files](../.ebextensions/)

---

**Document Maintenance**:
- Update this document after any infrastructure changes
- Review quarterly for accuracy
- Archive old versions in Git history
