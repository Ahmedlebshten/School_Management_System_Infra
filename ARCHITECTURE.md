# Architecture: Infrastructure + CI/CD Automation

This document explains how your infrastructure, CI, and CD systems work together to achieve **one-button automation with no manual steps**.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DEVELOPER WORKFLOW                                 │
└─────────────────────────────────────────────────────────────────────────────┘

1️⃣  INFRASTRUCTURE BOOTSTRAP (Manual, Once)
    ┌──────────────────┐
    │ Run Jenkins Job: │
    │ Infrastructure- │
    │ Deploy (apply)  │
    └────────┬─────────┘
             │
             │ (20-30 mins)
             ▼
    ┌──────────────────────────────────────────────┐
    │  ✅ AWS Infrastructure Provisioned:           │
    │    - VPC (10.0.0.0/16)                       │
    │    - EKS Cluster (3 nodes)                   │
    │    - IAM roles & policies                    │
    │    - Security groups                         │
    │  ✅ ArgoCD Installed on EKS                  │
    │  ✅ Root Application (App of Apps) created  │
    └──────────────────────────────────────────────┘


2️⃣  AUTOMATIC CI PIPELINE (GitHub webhook)
    ┌─────────────────────────────────┐
    │ Developer pushes code to:        │
    │ Ahmedlebshten/                  │
    │ School_Management_System (repo) │
    └────────┬────────────────────────┘
             │
             │ GitHub webhook fires
             ▼
    ┌──────────────────────────────────────────────┐
    │ Jenkins CI Pipeline Triggered:               │
    │  1. Checkout code                            │
    │  2. Build Docker image                       │
    │  3. Run tests                                │
    │  4. Push image to Docker Hub                 │
    │     Image: ahmedlebshten/                    │
    │             school_management_system:1       │
    │             school_management_system:2       │
    │             school_management_system:3 ...   │
    │  ✅ Build artifacts stored (not in infra)   │
    └──────────────────────────────────────────────┘


3️⃣  AUTOMATIC CD PIPELINE (ArgoCD watches Git)
    ┌──────────────────────────────────────┐
    │ When app manifests in Git change:    │
    │ Ahmedlebshten/                       │
    │ Jenkins-Pipeline-Build-Infra         │
    │ (argocd-apps/ directory)            │
    └────────┬─────────────────────────────┘
             │
             │ ArgoCD detects change (continuous sync)
             ▼
    ┌──────────────────────────────────────────────┐
    │ ArgoCD Deploys Automatically:                 │
    │  1. Fetch latest manifests from Git          │
    │  2. Compare current vs. desired state        │
    │  3. Apply manifests to Kubernetes            │
    │  4. Manage deployments forever               │
    │     (self-healing, auto-sync)               │
    │  ✅ App running in EKS cluster               │
    └──────────────────────────────────────────────┘


4️⃣  DEVELOPER USES APPLICATION
    ┌──────────────────────────────────────┐
    │ Application running on EKS cluster:  │
    │  - URL exposed via LoadBalancer      │
    │  - Auto-scaled by Kubernetes         │
    │  - Self-healing health checks        │
    │  - Rolling updates on image change   │
    └──────────────────────────────────────┘


5️⃣  UPDATE APPLICATION (No Jenkins involved!)
    ┌──────────────────────────────────────┐
    │ Developer pushes new code to:        │
    │ School_Management_System (repo)      │
    └────────┬─────────────────────────────┘
             │
             │ Repeats steps 2️⃣  & 3️⃣
             │
             ▼ (automatically)
    ┌──────────────────────────────────────┐
    │ New Docker image built & pushed      │
    │ New image: .../school_management:4   │
    │ ArgoCD detects new image tag        │
    │ Kubernetes rolls out update          │
    └──────────────────────────────────────┘

================================================================================
```

---

## Key Responsibilities

### Jenkins Responsibilities

✅ **ONLY on Infrastructure pipeline:**

- Provision AWS infrastructure (VPC, EKS, IAM)
- Install ArgoCD
- Create root ArgoCD Application
- Stop here ⛔ Do not touch applications

❌ **NOT responsible for:**

- Building Docker images
- Pushing images to registry
- Deploying applications
- Managing application configuration
- Triggering other pipelines

### ArgoCD Responsibilities

✅ **GitOps automation:**

- Watch Git repositories
- Detect manifest changes
- Deploy applications automatically
- Maintain desired state
- Self-heal (revert manual changes)
- Manage multiple environments

### GitHub (Application Repo)

✅ **Triggers CI pipeline:**

- Developer pushes code
- GitHub webhook fires
- Jenkins CI jobs triggered
- Docker image built & pushed

**Note:** No integration with CD/infrastructure direct (webhook only triggers CI)

### AWS / EKS

✅ **Provides platform:**

- Kubernetes cluster
- Compute resources (EC2 nodes)
- Network (VPC, subnets)

---

## Repositories Involved

| Repository                       | Purpose                 | Branch   | Webhook                 |
| -------------------------------- | ----------------------- | -------- | ----------------------- |
| **School_Management_System**     | Application source code | `main`   | ✅ YES (triggers CI)    |
| **Jenkins-Pipeline-Build-Infra** | Infrastructure + ArgoCD | `master` | ❌ NO (manual only)     |
| **argocd-apps/** (in infra repo) | Application manifests   | `master` | ✅ YES (ArgoCD watches) |

---

## Directory Structure: argocd-apps/

This directory must exist in the infrastructure repo and contain Kubernetes manifests:

```
Jenkins-Pipeline-Build-Infra/
├── argocd-apps/                    # ArgoCD watches this directory
│   ├── README.md
│   ├── school-app-dev/            # Dev environment
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   ├── school-app-prod/           # Prod environment
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   └── monitoring/                # Monitoring apps
│       ├── prometheus.yaml
│       └── alertmanager.yaml
├── modules/                        # Terraform modules (unchanged)
├── terraform files                 # Terraform (unchanged)
└── Jenkinsfile                     # Infrastructure pipeline

```

---

## Example: How Code Change Flows Through System

### Scenario: Developer Fixes a Bug

```
STEP 1: Developer codes and pushes to GitHub
┌─────────────────────────────────────────┐
│ $ git push origin main                  │
│ # Pushes to: School_Management_System   │
└──────────────┬──────────────────────────┘

STEP 2: GitHub webhook triggers CI (instant)
┌──────────────────────────────────────────────────────┐
│ Jenkins Job: school-management-system-ci             │
│                                                       │
│ Stage 1: Checkout code (from main branch)           │
│ Stage 2: Build Docker image                         │
│          Dockerfile → Docker image                   │
│ Stage 3: Run tests (unit, integration)              │
│ Stage 4: Push to registry                           │
│          Image: ahmedlebshten/...system:101         │
│                 (tag = build number)                │
└─────────────────┬──────────────────────────────────┘
                  │ (5-10 minutes)

STEP 3: ArgoCD detects new image (continuous)
┌──────────────────────────────────────────────────────┐
│ ArgoCD polls Git repo for manifest changes           │
│                                                       │
│ Manifest content:                                    │
│ spec:                                                │
│   containers:                                        │
│   - image: ahmedlebshten/...system:101              │
│                                                       │
│ ArgoCD detects image tag changed from 100 → 101     │
└─────────────────┬──────────────────────────────────┘
                  │ (1-3 minutes delay)

STEP 4: ArgoCD deploys new version
┌──────────────────────────────────────────────────────┐
│ kubectl set image deployment/school-app              │
│   school-app=ahmedlebshten/...system:101            │
│                                                       │
│ Kubernetes rolling update:                           │
│ Old pods (v100) → New pods (v101)                   │
│ ✅ Application updated in EKS cluster               │
│                                                       │
│ Health checks pass? → Application accessible        │
└──────────────────────────────────────────────────────┘

TOTAL TIME: 6-15 minutes (no manual steps!)
```

---

## No Manual Steps After Infra Pipeline

### What Users Must Do Manually

- ✅ Run Infrastructure-Deploy once (with ACTION=plan, then ACTION=apply)
- ✅ Create manifests in argocd-apps/ directory (one time per app)
- ✅ Push application code to GitHub (normal development)

### What Is Completely Automatic

- ❌ Jenkins should NOT build Docker images (GitHub webhook)
- ❌ Jenkins should NOT deploy apps (ArgoCD handles this)
- ❌ Jenkins should NOT trigger other pipelines
- ❌ Manual kubectl apply
- ❌ Manual image pushes
- ❌ Manual deployment triggering

---

## Security Boundaries

### What Jenkins Can Do

✅ Maintain infrastructure code
✅ Run terraform
✅ Access AWS

### What Jenkins CANNOT Do

❌ Deploy applications
❌ Modify application manifests
❌ Access application repositories
❌ Manage app configurations

### What ArgoCD Does

✅ Deploy from Git manifests
✅ Manage application lifecycle
✅ Sync with Git repository
✅ Self-heal deployments

---

## State Management

### Terraform State

```
Location: S3 bucket jenkins-terraform-backend-9904
File: data/eks/terraform.tfstate
Access: Jenkins EC2 instance (via IAM role)
Locking: DynamoDB (prevents concurrent modifications)
Encryption: S3 server-side encryption
```

### Kubernetes State

```
Location: etcd in EKS cluster
Managed by: Kubernetes API
Access: kubectl (authenticated via AWS IAM)
Backup: EKS control plane handles automatic backups
```

### Application State

```
Location: ArgoCD stores in Git (source of truth)
Tracking: Git repo (argocd-apps/)
Sync: Automatic reconciliation every 3 minutes
Recovery: Git history allows rollback to any version
```

---

## Disaster Recovery

### Scenario 1: EKS Cluster Fails

```
RECOVERY STEPS:
1. Run Infrastructure-Deploy (ACTION=apply)
   → Creates new EKS cluster
   → Installs ArgoCD

2. ArgoCD automatically syncs from Git
   → Starts all applications
   → Reconnects services

⏱️  TIME: ~30 minutes
✅ NO DATA LOSS (stateless apps in example)
```

### Scenario 2: Terraform State Corrupted

```
1. Check S3 bucket versioning
   → Restore previous state file version

2. Run Infrastructure-Deploy (ACTION=plan)
   → Verify it matches actual AWS state

3. If manual changes made in AWS:
   → Update Terraform code to match
   → Re-import resources: terraform import
```

### Scenario 3: Application Manifest Issue

```
1. ArgoCD detects deployment failure
   → Stops attempting sync

2. Fix manifest in Git
   → Push corrected YAML

3. ArgoCD detects change
   → Automatically re-syncs
   → Application healthy again

⏱️  TIME: <5 minutes
```

---

## Monitoring & Observability

### Jenkins Logs

```
Path: Jenkins UI → Infrastructure-Deploy → Log page
Contains: Terraform output, ArgoCD bootstrap steps
```

### Terraform State

```
$ terraform show              # View current state
$ terraform validate          # Check syntax
$ terraform plan             # Preview changes
```

### Kubernetes Resources

```
$ kubectl -n argocd get apps        # View ArgoCD applications
$ kubectl get deployments -A        # View all deployments
$ kubectl describe deployment <app> # Debug app issues
```

### ArgoCD UI

```
Access: kubectl -n argocd port-forward svc/argocd-server 8080:443
URL: https://localhost:8080
Dashboard: Shows all applications, sync status, health
```

---

## Scaling Considerations

### Adding More Applications

```
Process:
1. Create manifest in argocd-apps/<app-name>/
   ├── deployment.yaml
   ├── service.yaml
   └── configmap.yaml

2. Push to Git
   $ git push origin master

3. ArgoCD automatically detects
   → Creates application in Kubernetes

4. No Pipeline needed!
```

### Adding More Environments

```
Structure:
argocd-apps/
├── dev/
│   ├── app1.yaml
│   └── app2.yaml
├── staging/
│   ├── app1.yaml
│   └── app2.yaml
└── prod/
    ├── app1.yaml
    └── app2.yaml

Each ArgoCD instance points to its own directory
```

### Scaling EKS Cluster

```
Update terraform.tfvars:
node_group_desired_size = 5  # Was 2

Run: Infrastructure-Deploy (plan, then apply)
Terraform: Auto-scales node group
⏱️  TIME: ~10 minutes
```

---

## Troubleshooting Flowchart

```
Application not deploying?

  1. Check Git manifests exist
     $ git ls argocd-apps/

  2. Check ArgoCD sees them
     kubectl -n argocd get apps

  3. Check sync status
     argocd app get <app-name>

  4. Check Kubernetes
     kubectl get pods -n <app-namespace>

  5. Check logs
     kubectl logs -n <app-namespace> <pod-name>

  6. Fix manifest, commit, push
     ArgoCD auto-syncs in <3 mins
```

---

## Key Metrics

| Metric                          | Value                         |
| ------------------------------- | ----------------------------- |
| **First Infrastructure Deploy** | ~30 minutes                   |
| **New App Deploy**              | 1-5 minutes (after Git push)  |
| **App Update Deploy**           | 3-10 minutes (after Git push) |
| **Cluster Recovery**            | ~30 minutes                   |
| **ArgoCD Sync Interval**        | ~3 minutes                    |
| **Cluster Uptime Target**       | 99.9% (AWS SLA)               |

---

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
