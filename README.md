# Jenkins Pipeline – Automating AWS Infrastructure with Terraform

This repository contains the Terraform code and Jenkins pipeline used to automate the provisioning of AWS infrastructure.
The pipeline pulls the code from GitHub, runs Terraform steps, and builds the infrastructure automatically.

⸻

Project Structure:
.
├── modules/                # Reusable Terraform modules  
├── Jenkinsfile             # Jenkins pipeline to automate infra deployment
├── backend.tf              # Remote backend configuration (S3 + DynamoDB)
├── main.tf                 # Main infrastructure definitions
├── providers.tf            # AWS provider configuration
├── variables.tf            # Variables definitions
├── outputs.tf              # Output values
├── terraform.tfvars        # Variables values (excluded from repo if sensitive)
├── .gitignore
└── README.md

What This Pipeline Does:

The Jenkins pipeline automates the full Terraform workflow:
	1.	Checkout code from GitHub
	2.	Terraform Init (backend + plugins)
	3.	Terraform Plan (preview changes)
	4.	Terraform Apply (provision AWS infrastructure)

No manual AWS Console interaction is needed — everything is done through code.

⸻

Technologies Used:
	•	Jenkins
	•	Terraform
	•	AWS
	•	GitHub

⸻

Purpose of This Pipeline:

This repository represents Pipeline 1 of a larger DevOps project:
	1.	Infrastructure Pipeline (this repo)
	2.	CI Pipeline (Docker build + image push)
	3.	GitOps Deployment using ArgoCD

This pipeline lays the foundation by deploying the underlying AWS infrastructure automatically.

⸻

How to Run:
	1.	Add AWS credentials to Jenkins
	2.	Configure a Jenkins job pointing to this repository
	3.	Run the pipeline — Jenkins will build the entire AWS environment
