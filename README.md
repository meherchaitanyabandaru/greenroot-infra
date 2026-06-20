# GreenRoot Infrastructure

GreenRoot Infrastructure manages cloud resources, deployments, monitoring, security, networking, and environment configuration required to operate the GreenRoot platform.

---

## Overview

This repository contains infrastructure as code and deployment automation for:

* GreenRoot API
* GreenRoot Admin
* PostgreSQL
* AWS Services
* Monitoring
* CI/CD

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

terraform/

├── modules/
│
├── vpc/
├── ec2/
├── rds/
├── s3/
├── monitoring/
│
├── environments/
│
├── dev/
└── prod/

docker/

├── api/
└── admin/

github/

├── workflows/

scripts/

docs/

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
