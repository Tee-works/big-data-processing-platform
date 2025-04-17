# Big Data Processing Platform

## Background

BuildItAll, a European consulting firm specializing in scalable data platform solutions for small-size companies, recently secured €20M in Series A funding. This milestone strengthens their position in delivering enterprise-grade data platform services.

In early 2024, a Belgian client approached BuildItAll with a critical need: they needed a robust data platform to handle their massive daily data generation and enable data-driven decision-making through big data analytics.

Our team at BuildItAll took on this challenge as our first major project post-funding. The goal was to create a production-ready Big Data Processing Platform using Apache Spark, with a focus on cost optimization while maintaining enterprise-grade capabilities.

## Team

### Core Development Team
- **Ifeanyi** - Analytics Engineer ([GitHub](https://github.com/ioaviator))
- **Taiwo** - Data Engineer ([GitHub](https://github.com/Tee-works))
- **Chidera** - Data Engineer ([GitHub](https://github.com/Chideraozigbo))


## Table of Contents
1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Infrastructure as Code](#infrastructure-as-code)
4. [AWS Services Used](#aws-services-used)
5. [Security Implementation](#security-implementation)
6. [Network Architecture](#network-architecture)
7. [Data Processing Pipeline](#data-processing-pipeline)
8. [Setup and Installation](#setup-and-installation)
9. [Monitoring and Logging](#monitoring-and-logging)
10. [Cost Optimization](#cost-optimization)
11. [Best Practices](#best-practices)
12. [Troubleshooting](#troubleshooting)
13. [Contributing](#contributing)
14. [License](#license)

## Project Overview

This project implements a scalable Big Data Processing Platform for BuildItAll's Belgian client. The platform enables big data analytics through Apache Spark workloads, featuring automated cluster management, cost optimization, and robust CI/CD practices.

### Business Context
- **Client**: BuildItAll Consulting (European Consulting Firm)
- **Funding**: €20M Series A
- **Target**: Small-size companies requiring scalable data platforms
- **First Client**: Belgian company requiring big data analytics capabilities

### Key Features
- Fully versioned, controlled codebase
- Automated Apache Spark cluster management
- Cost-optimized infrastructure
- Comprehensive CI/CD pipeline
- Synthetic data generation for testing
- Production-grade security and monitoring

## Architecture

### Infrastructure Overview

The platform is built on AWS Cloud with a focus on security, scalability, and cost optimization. The architecture follows AWS best practices and implements a multi-AZ design for high availability.

![Architecture Diagram](images/big_data_architecture.gif)

### Architecture Flow

1. **Data Ingestion Layer**
   - Users connect through AWS Client VPN (10.0.0.0/16)
   - Data Engineers push code through GitHub Actions
   - Data flows through the VPN Gateway into the VPC

2. **Processing Layer**
   - EMR Cluster in private subnet (10.100.2.0/24)
   - MWAA (Managed Workflows for Apache Airflow) for orchestration
   - Auto-scaling based on workload

3. **Storage Layer**
   - S3 Data Lake with organized structure:
     - `etl/` - For ETL scripts and configurations
     - `dags/` - For Airflow DAG definitions
     - `logs/` - For application and system logs
   - RDS for metadata storage (10.100.3.0/24)

4. **Security Layer**
   - VPC endpoints for secure service access
   - IAM roles and policies
   - Security groups and NACLs
   - Certificate-based VPN authentication

### Why These Services?

1. **Amazon EMR**
   - Native Spark support
   - Cost-effective with spot instances
   - Automated cluster management
   - Integration with AWS services

2. **MWAA (Managed Workflows for Apache Airflow)**
   - Fully managed orchestration
   - Native AWS integration
   - Scalable and reliable
   - Reduced operational overhead

3. **AWS Client VPN**
   - Secure access to resources
   - Certificate-based authentication
   - Split-tunnel support
   - Detailed connection logging

## Infrastructure as Code

Our infrastructure is managed entirely through Terraform, with modular components for maintainability and reusability.

### Terraform Structure

```
terraform/
├── main.tf              # Main infrastructure definitions
├── variables.tf         # Variable declarations
├── outputs.tf          # Output definitions
├── providers.tf        # Provider configurations
├── backend.tf         # State management configuration
├── certificates/      # VPN certificates
├── policies/         # IAM policies
└── .terraform/       # Terraform plugins and modules
```

### Key Infrastructure Components

1. **Networking (VPC)**
   ```hcl
   module "vpc" {
     cidr_block           = "10.100.0.0/16"
     vpc_name             = "big-data-VPC"
     create_igw           = true
     enable_dns_support   = true
     enable_dns_hostnames = true
   }
   ```

2. **Subnets**
   - VPN Target Subnet: 10.100.0.0/24 (Public)
   - Load Balancer Subnet: 10.100.1.0/24 (Public)
   - EMR Subnet: 10.100.2.0/24 (Private)
   - RDS Subnet: 10.100.3.0/24 (Private)

3. **Security Groups**
   ```hcl
   module "vpc_private_sg" {
     vpc_id              = module.vpc.vpc_id
     security_group_name = "private-sg"
     description         = "Allow all traffic from VPC"
   }
   ```

4. **IAM Configuration**
   - Service Roles (EMR, MWAA)
   - User Management
   - Policy Attachments

## Data Processing Pipeline

1. **Data Ingestion**
   - Secure data upload through VPN
   - S3 bucket with organized structure
   - Event-driven triggers

2. **Processing**
   - EMR cluster for Spark processing
   - MWAA for workflow orchestration
   - Auto-scaling based on workload

3. **Storage**
   - S3 for raw and processed data
   - RDS for metadata
   - Parquet format for efficiency

## Security Implementation

1. **Network Security**
   - VPC isolation
   - Private subnets for processing
   - Security groups and NACLs
   - VPN access

2. **Access Control**
   - IAM roles and policies
   - Certificate-based authentication
   - Least privilege principle

3. **Data Security**
   - Encryption at rest
   - Encryption in transit
   - Secrets management

## Cost Optimization Strategies

1. **Compute Optimization**
   - EMR with spot instances
   - Auto-scaling clusters
   - Automated shutdown

2. **Storage Optimization**
   - S3 lifecycle policies
   - Parquet compression
   - Data archival strategies

## AWS Services Used

1. **Compute and Processing**
   - Amazon EMR (Elastic MapReduce)
   - MWAA (Managed Workflows for Apache Airflow)

2. **Storage**
   - Amazon S3
   - Amazon RDS

3. **Networking**
   - Amazon VPC
   - Client VPN
   - Internet Gateway
   - Gateway Endpoints

4. **Security**
   - AWS Certificate Manager
   - AWS Secrets Manager
   - IAM
   - Security Groups

5. **Monitoring**
   - Amazon CloudWatch
   - CloudWatch Logs

## Prerequisites

1. **AWS Account**
   - Appropriate IAM permissions
   - AWS CLI configured

2. **Development Tools**
   - Terraform >= 1.0.0
   - Python >= 3.8
   - Apache Spark >= 3.x
   - Git

3. **Authentication**
   - AWS credentials
   - VPN certificates
   - GitHub access tokens

## Project Structure

```
big-data-platform/
├── .github/
│   └── workflows/          # CI/CD pipeline definitions
├── terraform/
│   ├── modules/           # Reusable infrastructure components
│   ├── environments/      # Environment-specific configurations
│   └── variables/         # Variable definitions
├── spark/
│   ├── jobs/             # Spark job definitions
│   ├── config/           # Spark configurations
│   └── tests/            # Unit tests for Spark jobs
├── airflow/
│   ├── dags/             # Airflow DAG definitions
│   └── plugins/          # Custom Airflow plugins
├── scripts/
│   ├── setup/            # Setup and installation scripts
│   └── utilities/        # Utility scripts
├── tests/                # Integration tests
├── docs/                 # Additional documentation
└── README.md            # This file
```

## Setup and Installation

1. **Clone the Repository**
   ```bash
   git clone https://github.com/your-org/big-data-platform.git
   cd big-data-platform
   ```

2. **Install Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Configure AWS Credentials**
   ```bash
   aws configure
   ```

4. **Initialize Terraform**
   ```bash
   cd terraform
   terraform init
   ```

## Infrastructure Deployment

1. **Terraform Deployment**
   ```bash
   terraform plan -var-file=environments/prod.tfvars
   terraform apply -var-file=environments/prod.tfvars
   ```

2. **VPN Setup**
   - Download VPN configuration
   - Install AWS VPN client
   - Import certificates

## Data Processing

1. **Synthetic Data Generation**
   - Multiple parquet datasets
   - Total records: 5+ million
   - Varied record distribution

2. **Spark Job Execution**
   - Automated cluster provisioning
   - Job submission
   - Cluster termination

3. **Data Quality Checks**
   - Schema validation
   - Data integrity checks
   - Performance monitoring

## CI/CD Pipeline

1. **GitHub Actions Workflow**
   - Code validation
   - Unit testing
   - Infrastructure validation
   - Deployment automation

2. **Testing Stages**
   - Unit tests
   - Integration tests
   - Infrastructure tests

3. **Deployment Environments**
   - Development
   - Staging
   - Production

## Monitoring and Logging

1. **CloudWatch Metrics**
   - Cluster performance
   - Job execution stats
   - Cost metrics

2. **Logging**
   - Application logs
   - Infrastructure logs
   - Audit logs

## Cost Optimization

1. **Cluster Management**
   - Auto-scaling
   - Spot instances
   - Automatic termination

2. **Storage Optimization**
   - Data lifecycle policies
   - Storage class selection
   - Compression strategies

## Best Practices

1. **Code Management**
   - Version control
   - Code review process
   - Documentation

2. **Security**
   - Least privilege access
   - Regular security updates
   - Encryption standards

3. **Operations**
   - Automated deployments
   - Monitoring and alerting
   - Backup and recovery

## Troubleshooting

Common issues and their solutions:
1. VPN Connection Issues
2. Cluster Provisioning Failures
3. Job Execution Errors
4. Permission Problems

## Contributing

1. Fork the repository
2. Create a feature branch
3. Submit a pull request
4. Follow coding standards

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---
For more information, contact the BuildItAll Data Engineering Team.
