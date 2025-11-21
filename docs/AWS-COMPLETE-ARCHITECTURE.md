# AWS Complete Architecture - N4 Montessori CRM

## Overview

This document describes the complete AWS architecture for the N4 Montessori CRM platform, built on the Twenty open-source CRM foundation.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Route 53 (DNS)                          │
│           staging.n4montessori.com / app.n4montessori.com       │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                    CloudFront CDN (Optional)                    │
│                     Static Assets & Caching                     │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Application Load Balancer                      │
│                        SSL/TLS Termination                      │
└──────────────┬──────────────────────────┬──────────────────────┘
               │                          │
               ▼                          ▼
    ┌──────────────────┐      ┌──────────────────┐
    │   EB Environment │      │   EB Environment │
    │     STAGING      │      │    PRODUCTION    │
    └────────┬─────────┘      └────────┬─────────┘
             │                         │
             ▼                         ▼
    ┌─────────────────┐       ┌─────────────────┐
    │  Auto Scaling   │       │  Auto Scaling   │
    │   EC2 Instances │       │   EC2 Instances │
    │   (t3.small)    │       │   (t3.medium)   │
    └────────┬────────┘       └────────┬────────┘
             │                         │
             └────────┬────────────────┘
                      │
        ┌─────────────┼─────────────┐
        │             │             │
        ▼             ▼             ▼
┌──────────────┐ ┌──────────┐ ┌──────────────┐
│   Aurora     │ │   S3     │ │    Redis     │
│ Serverless   │ │ Storage  │ │ ElastiCache  │
│   v2 PG      │ │ Buckets  │ │  (Optional)  │
└──────────────┘ └──────────┘ └──────────────┘
```

## Components

### 1. Elastic Beanstalk (EB)

**Purpose**: Application hosting and orchestration

**Configuration**:
- **Staging Environment**: `n4-crm-staging`
  - Instance Type: `t3.small`
  - Deployment: Single instance (cost optimization)
  - Spot Instances: 100% (maximum cost savings)
  - Auto Scaling: Disabled for staging

- **Production Environment**: `n4-crm-production`
  - Instance Type: `t3.medium`
  - Deployment: Load balanced
  - Auto Scaling: 1-4 instances
  - Spot Instances: Hybrid (base on-demand + spot fleet)
  - Health Monitoring: Enhanced

**Features**:
- Automatic deployments from Git/CI
- Blue-green deployment support
- Managed platform updates
- Built-in monitoring and logging
- Environment cloning capabilities

### 2. Aurora Serverless v2 (PostgreSQL)

**Purpose**: Primary database with auto-scaling capabilities

**Configuration**:
- **Engine**: PostgreSQL 16.1
- **Scaling**: 
  - Staging: 0.5 ACU - 4 ACU (minimum capacity for development)
  - Production: 0.5 ACU - 4 ACU (scales based on demand)
- **Backup**: 
  - Retention: 7 days
  - Automated daily backups
  - Point-in-time recovery enabled
- **Maintenance Window**: Mondays 4:00-5:00 AM UTC
- **Backup Window**: Daily 3:00-4:00 AM UTC

**Benefits**:
- Pay per use (ACU-based billing)
- Automatic scaling based on load
- No capacity planning required
- High availability within region
- Enhanced security with encryption at rest

**Endpoints**:
- Staging: `n4-crm-staging-db.cluster-xxxxx.us-east-1.rds.amazonaws.com`
- Production: `n4-crm-production-db.cluster-xxxxx.us-east-1.rds.amazonaws.com`

### 3. S3 Storage Buckets

**Purpose**: File storage for uploads, attachments, and assets

**Configuration**:
- **Staging Bucket**: `n4-crm-staging-storage`
- **Production Bucket**: `n4-crm-production-storage`

**Security Features**:
- Versioning enabled
- Server-side encryption (AES-256)
- Public access blocked
- Bucket policies for EB access only

**Integration**:
- Direct integration via AWS SDK
- IAM role-based access (no access keys required)
- Pre-signed URLs for secure file access

### 4. AWS Secrets Manager

**Purpose**: Secure storage of database credentials and API keys

**Secrets**:
- `n4-crm/staging/database-credentials`: Staging DB credentials
- `n4-crm/production/database-credentials`: Production DB credentials

**Format**:
```json
{
  "username": "n4admin",
  "password": "generated-secure-password",
  "engine": "postgres",
  "host": "cluster-endpoint",
  "port": 5432,
  "dbname": "n4_crm_staging",
  "dbClusterIdentifier": "n4-crm-staging-db"
}
```

### 5. VPC and Networking

**Configuration**:
- **VPC**: Default VPC or custom VPC
- **Subnets**: Multi-AZ for high availability
- **Security Groups**: 
  - EB instances can access Aurora and Redis
  - Aurora only accessible from EB security group
  - S3 access via VPC endpoints (recommended)

### 6. IAM Roles and Policies

**EB Instance Role**: 
- S3 read/write access to designated buckets
- Secrets Manager read access
- CloudWatch Logs write access
- RDS connect permissions

**EB Service Role**:
- Standard Elastic Beanstalk service role
- Auto Scaling management
- Load balancer management

### 7. CloudWatch Monitoring

**Metrics Collected**:
- EB environment health
- Aurora CPU/Memory/Connections
- Application logs
- Custom application metrics

**Alarms** (Recommended):
- Aurora high CPU usage
- Aurora high connection count
- EB instance health degradation
- Application error rate spikes

## Deployment Architecture

### Staging Environment
- **Purpose**: Pre-production testing and validation
- **Cost Optimization**: Single instance, 100% spot instances
- **Database**: Shared Aurora cluster with production isolation
- **Storage**: Separate S3 bucket

### Production Environment
- **Purpose**: Live customer-facing application
- **High Availability**: Multi-AZ with auto-scaling
- **Database**: Dedicated Aurora cluster
- **Storage**: Separate S3 bucket with strict access controls

## Security Considerations

1. **Encryption**:
   - All data encrypted in transit (TLS/SSL)
   - All data encrypted at rest (Aurora, S3)
   - Secrets stored in AWS Secrets Manager

2. **Access Control**:
   - IAM roles for service-to-service authentication
   - No hardcoded credentials
   - Principle of least privilege

3. **Network Security**:
   - Private subnets for database
   - Security groups with minimal required access
   - VPC endpoints for AWS services

4. **Compliance**:
   - Data residency in single AWS region
   - Audit logging enabled
   - Backup and disaster recovery procedures

## Scaling Strategy

### Horizontal Scaling (Production)
- Auto-scaling based on CPU utilization
- Min: 1 instance, Max: 4 instances
- Scale up at 70% CPU
- Scale down at 20% CPU

### Vertical Scaling
- Aurora auto-scales capacity based on workload
- EB instances can be resized via configuration

### Database Scaling
- Aurora Serverless v2 scales automatically
- Read replicas can be added if needed
- Connection pooling implemented in application

## Cost Optimization

1. **Staging Environment**:
   - 100% spot instances (up to 90% savings)
   - Single instance deployment
   - Lower Aurora capacity limits

2. **Production Environment**:
   - Hybrid spot/on-demand for availability
   - Auto-scaling to match demand
   - Reserved instances for baseline capacity (optional)

3. **Storage**:
   - S3 Intelligent-Tiering for automatic cost optimization
   - Lifecycle policies for old file cleanup

4. **Monitoring**:
   - CloudWatch logs retention policies
   - Metrics filtering to reduce costs

## Disaster Recovery

### Backup Strategy
- **Aurora**: Automated daily backups, 7-day retention
- **Application**: Code in Git repository
- **Configuration**: Infrastructure as Code (this documentation)

### Recovery Procedures
1. Database restore from backup (Point-in-time recovery)
2. EB environment recreation from saved configuration
3. S3 versioning for file recovery

### RTO/RPO Targets
- **Staging**: RTO: 4 hours, RPO: 24 hours
- **Production**: RTO: 1 hour, RPO: 1 hour

## Monitoring and Alerting

### Key Metrics
- Application response time
- Error rate
- Database connection pool
- Memory/CPU usage
- Disk I/O

### Recommended Alarms
- Aurora CPU > 80% for 5 minutes
- EB environment degraded health
- Application error rate > 1%
- Database connection pool exhaustion

## Future Enhancements

1. **CDN Integration**: CloudFront for static asset delivery
2. **Redis/ElastiCache**: For session storage and caching
3. **Multi-Region**: DR setup in secondary region
4. **WAF**: Web Application Firewall for security
5. **CI/CD Pipeline**: Automated deployments via CodePipeline
6. **Container Migration**: ECS/Fargate for more control
7. **API Gateway**: Rate limiting and API management

## Environment URLs

- **Staging Frontend**: https://staging.n4montessori.com
- **Staging API**: https://api-staging.n4montessori.com
- **Production Frontend**: https://app.n4montessori.com
- **Production API**: https://api.n4montessori.com

## Support and Maintenance

### Update Schedule
- **Platform Updates**: Managed by AWS (Elastic Beanstalk)
- **Database Updates**: Automated during maintenance window
- **Application Updates**: Via CI/CD pipeline

### Monitoring
- CloudWatch Dashboards for key metrics
- SNS notifications for critical alerts
- Weekly health check reviews

## Related Documentation

- [Infrastructure Provisioned](./INFRASTRUCTURE-PROVISIONED.md) - Current provisioned resources
- [Provisioning Script](../scripts/provision-aws-infrastructure.sh) - Automated setup
- [Environment Configuration](../.eb-env-staging) - Staging environment variables
- [Environment Configuration](../.eb-env-production) - Production environment variables

---

**Last Updated**: November 2025
**Version**: 1.0
**Maintained By**: N4 Montessori Development Team
