# Jenkins Pipeline – Automating AWS Infrastructure with Terraform

This repository contains the Terraform code and Jenkins pipeline used to automate the provisioning of AWS infrastructure and bootstrap the GitOps workflow using ArgoCD.

The pipeline pulls the code from GitHub, provisions AWS infrastructure using Terraform, installs ArgoCD on the EKS cluster, and creates the Root Application that manages all Kubernetes applications.

____

## Project Structure:
```
├── modules/                # Reusable Terraform modules  
├── Jenkinsfile             # Jenkins pipeline to automate infra deployment
├── backend.tf              # Remote backend configuration (S3)
├── main.tf                 # Main infrastructure definitions
├── providers.tf            # AWS provider configuration
├── variables.tf            # Variables definitions
├── outputs.tf              # Output values
├── terraform.tfvars        # Variables values (excluded from repo if sensitive)
├── .gitignore
└── README.md
```
____

## What This Pipeline Does?

## The Jenkins pipeline automates the full infrastructure and GitOps bootstrap workflow:

#### 1️⃣ Infrastructure Provisioning (Terraform)

- Checkout code from GitHub
- Terraform Init (backend + plugins)
- Terraform Plan (preview changes)
- Terraform Apply (provision AWS infrastructure including EKS cluster)

#### 2️⃣ ArgoCD Bootstrap (GitOps Initialization)
After the EKS cluster is created, Jenkins:

- Updates kubeconfig to connect to the new cluster
- Creates the argocd namespace
- Installs ArgoCD on the cluster
- Waits for ArgoCD server to be ready
- Applies the Root Application

____

## What Is the Root Application?

## The Root Application is an ArgoCD Application resource that points to the CD repository:

```
spec:
  source:
    repoURL: https://github.com/Ahmedlebshten/School_Management_System_CD.git
    targetRevision: master
    path: applications
```

## Once created:

- ArgoCD monitors the CD repository
- Reads everything inside the /applications folder
- Automatically creates and syncs all child applications (monitoring stack, school app, etc.)

## ⚠️ Important:
Jenkins does NOT deploy the applications directly.
It only installs ArgoCD and creates the Root App.
ArgoCD then handles the rest using GitOps principles.

____

## 🔁 GitOps Flow

- Jenkins provisions infrastructure
- Jenkins installs ArgoCD
- Jenkins creates the Root Application
- ArgoCD pulls application manifests from the CD repository
- Any change pushed to the CD repo is automatically applied to the cluster

No manual kubectl apply is required.

____

## Technologies Used:
- Jenkins
- Terraform 
- AWS (EKS, VPC, etc.)
- ArgoCD
- GitHub
	
____

## 🎯 Purpose of This Pipeline

#### This repository represents Pipeline 1 of a larger DevOps project:

- Infrastructure Pipeline (Jenkins + Terraform) <- (this repo)
- CI Pipeline (GitHub Actions + Amazon ECR)
- GitOps Deployment using ArgoCD

#### This pipeline lays the foundation by:

- Provisioning AWS infrastructure using Terraform
- Creating VPC, IAM Roles, and EKS cluster
- Configuring remote state (S3 backend)
- Installing and bootstrapping ArgoCD
- Enabling GitOps-based deployment automation

____

## ▶️ How to Run

- Ensure Jenkins is running on an EC2 instance with an attached IAM Role  
  (no static AWS credentials required)
- Configure a Jenkins pipeline job pointing to this repository
- Trigger the pipeline manually to provision the infrastructure

#### Jenkins will:

- Provision the full AWS infrastructure
- Install ArgoCD
- Create the Root Application
- Trigger automatic deployment of all Kubernetes applications
____

## 📚 Documentation

#### Detailed technical documentation is available in the `/docs` directory:

- GitOps workflow
- Jenkins pipeline breakdown
- Infrastructure architecture
- Verification checklist
