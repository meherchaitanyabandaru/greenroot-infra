# GreenRoot Infrastructure

GreenRoot Infrastructure manages cloud resources, deployments, monitoring, security, networking, and environment configuration required to operate the GreenRoot platform.

---

## Overview

This repository contains infrastructure as code and deployment automation for:

* GreenRoot API
* GreenRoot Admin
* PostgreSQL
* Redis
* AWS Services
* Monitoring
* CI/CD
* Project documentation and diagrams

---

## Goals

* Reproducible Infrastructure
* Automated Deployments
* Environment Consistency
* Security Compliance
* Disaster Recovery

---

## Technology Stack

### Cloud Provider

AWS

---

### Infrastructure as Code

Terraform

---

### Containerization

Docker

---

### CI/CD

GitHub Actions

---

### Monitoring

CloudWatch

---

### Secrets Management

AWS Secrets Manager

---

## AWS Services

### Compute

* EC2
* Auto Scaling (Future)

---

### Database

* Amazon RDS PostgreSQL

---

### Storage

* Amazon S3

Buckets:

* greenroot-dev-files
* greenroot-prod-files

---

### Networking

* VPC
* Security Groups
* NAT Gateway
* Route Tables

---

### Monitoring

* CloudWatch Logs
* CloudWatch Metrics
* CloudWatch Alarms

---

## Environments

### Development

Purpose:

* Testing
* Development
* QA

Resources:

* Small EC2
* Small PostgreSQL
* Dev S3 Bucket

---

### Production

Purpose:

* Real Customers

Resources:

* Production EC2
* Production PostgreSQL
* Production S3 Bucket

---

## Repository Structure

```text
greenroot-infra/
├── db/
│   ├── postgresql/
│   │   ├── README.md
│   │   └── greenroot-seed.sql
│   └── redis/
│       └── README.md
├── docs/
│   ├── README.md
│   ├── diagrams/
│   │   ├── architecture/
│   │   ├── er/
│   │   └── uml/
│   ├── operations/
│   └── repositories/
└── README.md
```

Planned infrastructure folders:

```text
terraform/
├── modules/
├── environments/
│   ├── dev/
│   └── prod/
├── vpc/
├── ec2/
├── rds/
├── s3/
└── monitoring/

docker/
├── api/
└── admin/

.github/
└── workflows/

scripts/
```

Folder ownership:

* `db/postgresql/` - PostgreSQL schema, seed data, migrations, indexes, and DB runbooks
* `db/redis/` - Redis keyspace design, cache strategy, queues, locks, and local setup notes
* `docs/diagrams/architecture/` - cloud, system, deployment, and integration diagrams
* `docs/diagrams/er/` - entity relationship diagrams
* `docs/diagrams/uml/` - sequence, class, component, and activity diagrams
* `docs/repositories/` - documentation that explains how other GreenRoot repos fit together
* `docs/operations/` - deployment, backup, monitoring, and incident runbooks

---

## Database Seed

The reusable PostgreSQL seed file is:

```bash
db/postgresql/greenroot-seed.sql
```

Use it to create a local development database:

```bash
createdb greenroot_dev
psql -v ON_ERROR_STOP=1 -d greenroot_dev -f db/postgresql/greenroot-seed.sql
```

The seed file includes:

* Hardened PostgreSQL schema
* Enum types for finite business states
* Primary keys, foreign keys, unique constraints, and validation checks
* Query indexes for orders, inventory, payments, sessions, notifications, and vehicle tracking
* Demo data for users, roles, nurseries, inventory, orders, payments, dispatches, requests, notifications, subscriptions, sessions, and audit logs

Notes:

* The seed file is intended for development and QA.
* It includes demo-only data and should not be used as production customer data.
* If restoring under a different PostgreSQL role, adjust or remove the `OWNER TO meharbandaru` statements.

---

## CI/CD Pipeline

### API Deployment

1. Push to main
2. Run Tests
3. Build Docker Image
4. Deploy to AWS
5. Health Check

---

### Admin Deployment

1. Build Next.js
2. Deploy
3. Validate Deployment

---

## Monitoring

Track:

* API Errors
* CPU Usage
* Memory Usage
* Database Health
* Storage Usage

---

## Security

### Network Security

* Private Subnets
* Security Groups
* Restricted Database Access

### Application Security

* HTTPS
* TLS Certificates
* Secrets Manager

---

## Backup Strategy

### Database

Daily Backups

Retention:

30 Days

---

### Files

S3 Versioning Enabled

---

## Disaster Recovery

* Database Recovery
* Infrastructure Recreation
* Backup Restoration

---

## Future Roadmap

### V1

* Single Region AWS Deployment

### V2

* Auto Scaling
* Read Replicas

### V3

* Multi Region Deployment
* Global Failover

---

## Product Vision

GreenRoot Infrastructure provides secure, scalable, and reliable cloud infrastructure capable of supporting nursery businesses across India.
