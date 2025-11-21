# Post-Provisioning Checklist

Use this checklist to track progress after running the AWS infrastructure provisioning scripts.

**Date**: _________________  
**Executed by**: _________________  
**AWS Account ID**: _________________  
**AWS Region**: _________________

---

## Phase 1: Infrastructure Provisioning

### Provisioning Script Execution

- [ ] Ran `./scripts/provision-aws-infrastructure.sh`
- [ ] Script completed without errors
- [ ] Captured script output (save to file or screenshot)
- [ ] Noted all resource IDs and endpoints

### Aurora Clusters

**Staging:**
- [ ] Cluster created: `n4-crm-staging-db`
- [ ] Instance created: `n4-crm-staging-db-instance-1`
- [ ] Cluster status: Available
- [ ] Endpoint captured: ___________________________________
- [ ] Secret created in Secrets Manager

**Production:**
- [ ] Cluster created: `n4-crm-production-db`
- [ ] Instance created: `n4-crm-production-db-instance-1`
- [ ] Cluster status: Available
- [ ] Endpoint captured: ___________________________________
- [ ] Secret created in Secrets Manager

### S3 Buckets

**Staging:**
- [ ] Bucket created: `n4-crm-staging-storage`
- [ ] Versioning enabled
- [ ] Encryption enabled (AES-256)
- [ ] Public access blocked
- [ ] Bucket accessible via AWS CLI

**Production:**
- [ ] Bucket created: `n4-crm-production-storage`
- [ ] Versioning enabled
- [ ] Encryption enabled (AES-256)
- [ ] Public access blocked
- [ ] Bucket accessible via AWS CLI

### Secrets Manager

- [ ] Staging secrets created: `n4-crm/staging/database-credentials`
- [ ] Production secrets created: `n4-crm/production/database-credentials`
- [ ] Secrets readable via AWS CLI
- [ ] Passwords documented securely (1Password/LastPass/etc)

---

## Phase 2: Infrastructure Validation

- [ ] Ran `./scripts/validate-aws-infrastructure.sh`
- [ ] All checks passed (green ✓)
- [ ] Resolved any warnings
- [ ] Resolved any errors
- [ ] Saved validation report

---

## Phase 3: Environment Configuration

### Staging Environment

- [ ] Created `.eb-env-staging.local` from template
- [ ] Retrieved database password from Secrets Manager
- [ ] Updated `PG_DATABASE_URL` with actual endpoint and password
- [ ] Updated `APP_SECRET` with generated random string
- [ ] Updated `FRONTEND_URL` with actual domain
- [ ] Updated `SERVER_URL` with actual domain
- [ ] Verified all `REPLACE_WITH_*` placeholders filled

### Production Environment

- [ ] Created `.eb-env-production.local` from template
- [ ] Retrieved database password from Secrets Manager
- [ ] Updated `PG_DATABASE_URL` with actual endpoint and password
- [ ] Updated `APP_SECRET` with generated random string (different from staging)
- [ ] Updated `FRONTEND_URL` with actual domain
- [ ] Updated `SERVER_URL` with actual domain
- [ ] Verified all `REPLACE_WITH_*` placeholders filled
- [ ] Configured SMTP settings for email
- [ ] Configured any optional features (Sentry, analytics, etc.)

---

## Phase 4: IAM Configuration

### IAM Roles

- [ ] Created Elastic Beanstalk service role (if not exists)
- [ ] Created EC2 instance profile role
- [ ] Attached S3 access policy to instance profile
  - [ ] `n4-crm-staging-storage` read/write
  - [ ] `n4-crm-production-storage` read/write
- [ ] Attached Secrets Manager read policy
- [ ] Attached CloudWatch Logs write policy
- [ ] Attached RDS connect policy

### Sample IAM Policy for Instance Profile

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::n4-crm-staging-storage/*",
        "arn:aws:s3:::n4-crm-staging-storage",
        "arn:aws:s3:::n4-crm-production-storage/*",
        "arn:aws:s3:::n4-crm-production-storage"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
        "arn:aws:secretsmanager:*:*:secret:n4-crm/*"
      ]
    }
  ]
}
```

---

## Phase 5: Elastic Beanstalk Setup

### EB CLI Initialization

- [ ] Installed EB CLI (`eb --version`)
- [ ] Ran `eb init -p "Node.js 20" -r us-east-1 n4-crm`
- [ ] Selected SSH keypair for instance access

### Staging Environment Creation

- [ ] Ran `eb create n4-crm-staging --instance-types t3.small --single`
- [ ] Selected VPC and subnets
- [ ] Assigned IAM instance profile
- [ ] Environment created successfully
- [ ] Environment health: Green
- [ ] Captured environment URL: ___________________________________

### Production Environment Creation

- [ ] Ran `eb create n4-crm-production --instance-types t3.medium`
- [ ] Selected VPC and subnets
- [ ] Assigned IAM instance profile
- [ ] Configured load balancer
- [ ] Configured auto-scaling (min: 1, max: 4)
- [ ] Environment created successfully
- [ ] Environment health: Green
- [ ] Captured environment URL: ___________________________________

### Environment Variables Configuration

**Staging:**
- [ ] Set environment variables: `eb setenv --envvars $(cat .eb-env-staging.local | tr '\n' ',' | sed 's/,$//')`
- [ ] Verified variables: `eb printenv n4-crm-staging`

**Production:**
- [ ] Set environment variables: `eb setenv --envvars $(cat .eb-env-production.local | tr '\n' ',' | sed 's/,$//')`
- [ ] Verified variables: `eb printenv n4-crm-production`

---

## Phase 6: Application Deployment

### Staging Deployment

- [ ] Built application: `yarn nx build twenty-server`
- [ ] Deployed to staging: `eb deploy n4-crm-staging`
- [ ] Deployment successful
- [ ] Application logs checked: `eb logs n4-crm-staging`
- [ ] Health check passed
- [ ] Tested application access

### Database Initialization (Staging)

- [ ] SSH key pair configured during EB environment creation
- [ ] SSH into instance: `eb ssh n4-crm-staging` (requires key pair)
  - Alternative: Use AWS Systems Manager Session Manager for keyless access
  - Or run migrations from local machine with port forwarding
- [ ] Ran database migrations
- [ ] Verified database connection
- [ ] Created test data (if needed)

### Production Deployment

- [ ] Validated staging environment thoroughly
- [ ] Backed up any existing data (if applicable)
- [ ] Deployed to production: `eb deploy n4-crm-production`
- [ ] Deployment successful
- [ ] Application logs checked: `eb logs n4-crm-production`
- [ ] Health check passed
- [ ] Tested application access

### Database Initialization (Production)

- [ ] SSH key pair configured during EB environment creation
- [ ] SSH into instance: `eb ssh n4-crm-production` (requires key pair)
  - Alternative: Use AWS Systems Manager Session Manager for keyless access
  - Or run migrations from local machine with secure tunnel
- [ ] Ran database migrations
- [ ] Verified database connection
- [ ] Imported production data (if applicable)

---

## Phase 7: DNS and SSL Configuration

### DNS Configuration

- [ ] Created Route 53 hosted zone (or used existing)
- [ ] Created A record for staging frontend: `staging.n4montessori.com`
- [ ] Created A record for staging API: `api-staging.n4montessori.com`
- [ ] Created A record for production frontend: `app.n4montessori.com`
- [ ] Created A record for production API: `api.n4montessori.com`
- [ ] DNS propagation verified

### SSL Certificates

- [ ] Requested SSL certificate in ACM for `*.n4montessori.com`
- [ ] Validated certificate (DNS or email)
- [ ] Certificate issued and active
- [ ] Attached certificate to staging load balancer
- [ ] Attached certificate to production load balancer
- [ ] HTTPS redirect enabled
- [ ] Tested HTTPS access

---

## Phase 8: Monitoring and Alerting

### CloudWatch Configuration

- [ ] Created custom dashboard for application metrics
- [ ] Created Aurora CPU alarm (threshold: 80%)
- [ ] Created Aurora connection alarm (threshold: 80%)
- [ ] Created EB health degraded alarm
- [ ] Created application error rate alarm
- [ ] Configured SNS topic for alerts
- [ ] Added email addresses to SNS subscription
- [ ] Tested alert delivery

### Logging

- [ ] Verified CloudWatch Logs group created
- [ ] Configured log retention (30 days recommended)
- [ ] Set up log insights queries (optional)
- [ ] Documented log access procedures

---

## Phase 9: Security Review

### Security Checklist

- [ ] All databases in private subnets
- [ ] Security groups configured with least privilege
- [ ] No hardcoded credentials in environment variables
- [ ] Secrets Manager used for all sensitive data
- [ ] S3 buckets have public access blocked
- [ ] SSL/TLS enabled for all traffic
- [ ] IAM roles use least privilege policies
- [ ] MFA enabled for AWS console access
- [ ] CloudTrail logging enabled
- [ ] Reviewed and documented all open security groups

### Compliance

- [ ] Data residency requirements met (single region)
- [ ] Backup procedures documented
- [ ] Disaster recovery plan documented
- [ ] Incident response plan documented

---

## Phase 10: Documentation

### Update Documentation

- [ ] Updated `docs/INFRASTRUCTURE-PROVISIONED.md` with actual resource IDs
- [ ] Documented all endpoints and URLs
- [ ] Captured all resource ARNs
- [ ] Updated cost estimates with actual values
- [ ] Documented any deviations from architecture plan

### Knowledge Transfer

- [ ] Created runbook for common operations
- [ ] Documented deployment procedures
- [ ] Documented rollback procedures
- [ ] Trained team members on infrastructure
- [ ] Created contact list for support escalation

---

## Phase 11: Testing and Validation

### Functional Testing

- [ ] User registration working
- [ ] User login working
- [ ] Database read/write operations working
- [ ] File upload to S3 working
- [ ] File download from S3 working
- [ ] Email sending working (if configured)
- [ ] All critical features tested

### Performance Testing

- [ ] Application response time acceptable
- [ ] Database query performance acceptable
- [ ] Auto-scaling tested (production)
- [ ] Load testing completed (optional)

### Disaster Recovery Testing

- [ ] Database backup/restore tested
- [ ] S3 versioning tested
- [ ] Environment cloning tested
- [ ] Recovery time objective (RTO) validated
- [ ] Recovery point objective (RPO) validated

---

## Phase 12: Go-Live Preparation

### Pre-Launch Checklist

- [ ] All infrastructure validated
- [ ] All tests passed
- [ ] Documentation complete
- [ ] Monitoring active
- [ ] Alerts configured
- [ ] Team trained
- [ ] Rollback plan ready
- [ ] Stakeholders notified of launch schedule

### Launch Day

- [ ] Final deployment to production
- [ ] Smoke tests passed
- [ ] Monitoring dashboards reviewed
- [ ] Support team on standby
- [ ] Communication channels open

### Post-Launch

- [ ] Monitored application for 24 hours
- [ ] Reviewed logs for errors
- [ ] Validated all metrics
- [ ] Addressed any issues
- [ ] Conducted post-launch retrospective

---

## Notes and Issues

_Use this section to document any issues encountered, workarounds applied, or deviations from the plan:_

---

## Sign-Off

**Infrastructure Team Lead**: _________________ Date: _________

**Development Team Lead**: _________________ Date: _________

**Project Manager**: _________________ Date: _________

---

**Archive this checklist in the project repository after completion.**
