# Exact Jenkins Jobs You Need

This document provides EXACTLY what you asked for in the requirements.

---

## Answer to Question 3: "Tell me EXACTLY what Jenkins jobs I need to create"

### Summary Table

| #   | Job Name                 | Type     | Repository | Trigger    | Manual | Auto  | Status       |
| --- | ------------------------ | -------- | ---------- | ---------- | ------ | ----- | ------------ |
| 1   | `Infrastructure-Deploy`  | Pipeline | infra-repo | No webhook | ✅ YES | ❌ NO | ⚙️ Bootstrap |
| 2   | `Infrastructure-Destroy` | Pipeline | infra-repo | No webhook | ✅ YES | ❌ NO | 🗑️ Teardown  |

**Total Jenkins jobs needed: 2**

---

## Job 1: Infrastructure-Deploy

### Metadata

- **Name:** `Infrastructure-Deploy`
- **Type:** Pipeline (Declarative or Scripted)
- **Display Name:** `Infrastructure-Deploy` (exact)

### Repository Configuration

- **Repository URL:** `https://github.com/Ahmedlebshten/Jenkins-Pipeline-Build-Infra.git`
- **Branch:** `master` (not main, not develop)
- **Jenkinsfile Path:** `Jenkinsfile` (root of repository)

### Build Parameters

```
Name: ACTION
Type: Choice Parameter
Choices:
  plan
  apply
Default Choice: plan
Description: "Terraform action: 'plan' (preview changes), 'apply' (provision infrastructure)"
```

### Build Triggers

- ❌ Do NOT check "GitHub hook trigger for GITScm polling"
- ❌ Do NOT check "Poll SCM"
- ❌ Do NOT check "Build periodically"
- ✅ Manual trigger ONLY — User must click "Build with Parameters"

### Build Timeout

- ⏱️ Timeout: 2 hours (120 minutes)

### Concurrent Build

- ❌ Disable concurrent builds

### Build Discarder

- Keep builds: 50
- Keep build logs: 30 days

### Credentials

- AWS credentials via EC2 IAM role (not Jenkins credentials)
- No secrets stored in job configuration

### What This Job Does

When run with **ACTION = plan**:

```
✅ Checks out Terraform code
✅ Initializes Terraform
✅ Plans infrastructure changes (shows what will be created)
✅ STOPS — Does not apply changes
✅ Safe preview, can be reviewed before apply
```

When run with **ACTION = apply**:

```
✅ Runs everything from "plan"
✅ Applies Terraform changes
✅ Provisions EKS cluster, VPC, IAM roles
✅ Installs ArgoCD
✅ Creates root ArgoCD Application
✅ Takes ~20-30 minutes
```

### How to Run

**In Jenkins UI:**

1. Go to `Infrastructure-Deploy` job
2. Click "Build with Parameters"
3. Select `ACTION = plan`
4. Click "Build"
5. Monitor logs (should show terraform plan output)
6. Review what will be created
7. If OK:
   - Click "Build with Parameters" again
   - Select `ACTION = apply`
   - Click "Build"
   - Monitor for ~30 minutes
   - Verify success in logs

### Success Indicators

```
✅ Build succeeds
✅ Log shows "Infrastructure provisioned successfully"
✅ Log shows "ArgoCD installed and ready"
✅ Log shows "Root ArgoCD Application created successfully"
✅ No errors or warnings
```

### Common Issues

| Issue                | Solution                                              |
| -------------------- | ----------------------------------------------------- |
| S3 backend not found | Ensure `jenkins-terraform-backend-9904` bucket exists |
| `kubectl: not found` | Install kubectl on Jenkins agent                      |
| `eksctl: not found`  | Install eksctl on Jenkins agent                       |
| `aws: not found`     | Install AWS CLI on Jenkins agent                      |
| Permission denied    | Jenkins EC2 IAM role lacks permissions                |

---

## Job 2: Infrastructure-Destroy

### Metadata

- **Name:** `Infrastructure-Destroy`
- **Type:** Pipeline (Declarative or Scripted)
- **Display Name:** `Infrastructure-Destroy` (exact)

### Repository Configuration

- **Repository URL:** `https://github.com/Ahmedlebshten/Jenkins-Pipeline-Build-Infra.git`
- **Branch:** `master` (not main, not develop)
- **Jenkinsfile Path:** `Jenkinsfile.destroy` (root of repository)

### Build Parameters

```
Name: CONFIRM_DESTROY
Type: String Parameter
Default Value: (leave empty)
Description: "Type exactly 'yes-destroy-infrastructure' to proceed with destruction. This is your final safety confirmation."
```

### Build Triggers

- ❌ Do NOT check ANY automatic triggers
- ✅ Manual trigger ONLY — User must explicitly run with confirmation

### Build Timeout

- ⏱️ Timeout: 1 hour (60 minutes)

### Concurrent Build

- ❌ Disable concurrent builds (critical!)

### Build Discarder

- Keep builds: 100 (audit trail)
- Keep build logs: 90 days (forensics)

### Credentials

- Same as Infrastructure-Deploy job
- AWS credentials via EC2 IAM role

### What This Job Does

This job ONLY runs if `CONFIRM_DESTROY` = `yes-destroy-infrastructure`

```
🚨 If correct confirmation provided:
✅ Checks out Terraform code
✅ Initializes Terraform
✅ Destroys ALL infrastructure:
    - EKS cluster (deletes all running pods)
    - VPC and all subnets
    - NAT Gateways
    - Security Groups
    - IAM roles and policies
    - All associated AWS resources
✅ Takes ~15-20 minutes
```

### How to Run

**⚠️ DESTRUCTIVE ACTION — USE WITH CAUTION**

1. Go to `Infrastructure-Destroy` job
2. Click "Build with Parameters"
3. In the `CONFIRM_DESTROY` field, type EXACTLY:
   ```
   yes-destroy-infrastructure
   ```
4. Click "Build"
5. Monitor logs carefully
6. Wait for completion (~20 minutes)
7. Verify resources deleted in AWS Console

### Success Indicators

```
✅ Build succeeds
✅ Log shows "terraform destroy -auto-approve" executed
✅ Log shows "Terraform destroy completed successfully"
✅ Log shows "INFRASTRUCTURE DESTRUCTION COMPLETED"
✅ AWS Console shows 0 EC2 instances in region
✅ AWS Console shows no EKS clusters
```

### Safety Mechanisms

- ❌ No automatic triggers
- ❌ No schedule
- ✅ Explicit manual confirmation required
- ✅ Confirmation string is hard to type accidentally
- ✅ Job fails immediately if confirmation missing
- ✅ Clear warnings before destruction
- ✅ Terraform state kept for recovery

---

## Jobs That Should NO LONGER EXIST

**DELETE these if they exist in Jenkins:**

```
❌ Install-ArgoCD
   (ArgoCD now installed by Infrastructure-Deploy)

❌ CD-Create-ArgoCD-Application
   (Applications now deployed by ArgoCD watching Git)

❌ CD-Create-Monitoring-Application
   (Monitoring deployed by ArgoCD)

❌ Security-Tools-Create-Application
   (Security tools deployed by ArgoCD)

❌ Any job that deploys applications
   (All app deployments are now GitOps via ArgoCD)

❌ Any job that triggers other pipelines
   (No pipeline chaining anymore)
```

**Why delete them?**

- ✅ They're no longer needed (functionality moved to GitOps)
- ✅ Prevents accidental triggering
- ✅ Reduces Jenkins clutter
- ✅ Enforces GitOps discipline

---

## Answer to Question 4: "Explain the final end-to-end flow clearly"

### Flow Chart

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     INITIAL INFRASTRUCTURE SETUP                         │
└─────────────────────────────────────────────────────────────────────────┘

Human clicks: Jenkins → Infrastructure-Deploy → Build with Parameters
Parameter: ACTION = plan

  ↓

Jenkins runs: terraform init, terraform plan
Output: Shows what will be created (VPC, EKS, IAM, Security Groups)

  ↓ (Human reviews the plan)

Human clicks: Jenkins → Infrastructure-Deploy → Build with Parameters
Parameter: ACTION = apply

  ↓

Jenkins runs:
  1. terraform init (20 seconds)
  2. terraform plan (3 minutes)
  3. terraform apply (15 minutes)
  4. ArgoCD bootstrap (3 minutes)
     - Updates kubeconfig
     - Maps Jenkins IAM to Kubernetes RBAC
     - Installs ArgoCD server
     - Waits for server readiness
  5. Creates root ArgoCD Application (pointing to Git repo)

  ↓ (Total: ~25 minutes)

✅ RESULT:
   - EKS cluster fully provisioned (3 nodes)
   - ArgoCD installed and running
   - Root Application ready to deploy apps
   - No manual steps needed
   - Nothing manually applied by Jenkins


┌─────────────────────────────────────────────────────────────────────────┐
│                     DEVELOPER PUSHES APPLICATION CODE                    │
└─────────────────────────────────────────────────────────────────────────┘

Developer: $ git push origin main
Repository: https://github.com/Ahmedlebshten/School_Management_System

  ↓

GitHub webhook auto-triggers: Jenkins CI pipeline
(NOTE: This is SEPARATE from infrastructure repo)

  ↓

Jenkins CI reads: Jenkinsfile from the APPLICATION repo (not infra repo)

  ↓

Jenkins CI stages:
  1. Checkout code
  2. Build Docker image
  3. Run tests
  4. Push image to Docker Hub
     Image: ahmedlebshten/school_management_system:42

  ↓ (Total: ~5-10 minutes)

✅ RESULT:
   - Docker image pushed to registry
   - New image available for deployment
   - Image tag: school_management_system:42


┌─────────────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT VIA ARGOCD (GitOps)                        │
└─────────────────────────────────────────────────────────────────────────┘

Update Git manifest to use new image:
File: argocd-apps/school-app/deployment.yaml
Change from: image: ...school_management_system:41
Change to:   image: ...school_management_system:42

Developer: $ git push origin master
Repository: https://github.com/Ahmedlebshten/Jenkins-Pipeline-Build-Infra

  ↓

ArgoCD (running in EKS) continuously watches this Git repo
(Checks every 3 minutes by default)

  ↓

ArgoCD detects: deployment.yaml changed
New image tag: 42 (was 41)

  ↓

ArgoCD automatically syncs:
  1. Reads manifest from Git
  2. Compares to current Kubernetes state
  3. Detects difference (image tag changed)
  4. Applies new deployment
  5. Kubernetes rolls out new pods
  6. Old pods (v41) → New pods (v42)
  7. Health checks pass → Application is live

  ↓ (Total: ~5-10 minutes, automatic)

✅ RESULT:
   - Application updated in Kubernetes
   - New version running and serving traffic
   - NO JENKINS INVOLVED IN DEPLOYMENT
   - NO MANUAL kubectl COMMANDS NEEDED
   - Deployment is automatic and auditable (in Git)


┌─────────────────────────────────────────────────────────────────────────┐
│                          DAILY OPERATIONS                                │
└─────────────────────────────────────────────────────────────────────────┘

Scenario 1: Scale application to 10 replicas
  Developer edits: argocd-apps/school-app/deployment.yaml
  Change: spec.replicas: 3 → 10
  Commit and push
  → ArgoCD detects → Kubernetes scales → Done (5 mins, automatic)

Scenario 2: Update configuration
  Developer edits: argocd-apps/school-app/configmap.yaml
  Commit and push
  → ArgoCD detects → Kubernetes applies config → Done (2 mins, automatic)

Scenario 3: Add monitoring stack
  Developer creates: argocd-apps/prometheus/deployment.yaml (new app)
  Commit and push
  → ArgoCD detects → Kubernetes deploys → Done (5 mins, automatic)

Scenario 4: Rollback to previous version
  Developer runs: git revert <commit-hash>
  Commit and push
  → ArgoCD detects → Kubernetes reverts pods → Done (5 mins, automatic)

KEY POINT: ALL operations use Git, NOT Jenkins pipelines!


┌─────────────────────────────────────────────────────────────────────────┐
│                          DESTROY INFRASTRUCTURE                          │
└─────────────────────────────────────────────────────────────────────────┘

Human clicks: Jenkins → Infrastructure-Destroy → Build with Parameters
Parameter: CONFIRM_DESTROY = (leave empty by default)

  ↓

Jenkins checks confirmation... FAILS
Error: "Destruction confirmation failed! You must type: yes-destroy-infrastructure"

  ↓ (Human protection against accidents)

Human clicks: Jenkins → Infrastructure-Destroy → Build with Parameters
Parameter: CONFIRM_DESTROY = yes-destroy-infrastructure

  ↓

Jenkins runs: terraform destroy -auto-approve

  ↓

Terraform destroys all resources:
  - EKS cluster → All running pods killed
  - VPC, subnets, gateways
  - IAM roles
  - Everything except S3 state file and backend bucket

  ↓ (Total: ~15-20 minutes)

✅ RESULT:
   - All infrastructure deleted
   - Terraform state preserved (for recovery)
   - Clean slate for next deployment
```

---

## Data Flow Summary

```
┌──────────────────┐
│  Developer Code  │
│ School_Management│
│   _System Repo   │
└────────┬─────────┘
         │
         ├── (Webhook: code push)
         │
         ▼
┌──────────────────────────┐
│   Jenkins CI Pipeline    │
│ • Build Docker image     │
│ • Run tests              │
│ • Push to registry       │
└────────┬─────────────────┘
         │
         ├── (Image pushed)
         │
         ▼
┌──────────────────────────┐
│    Docker Registry       │
│  school_management:42    │
└────────┬─────────────────┘
         │
         ├── (Update manifest)
         │
         ▼
┌──────────────────────────┐
│  Infrastructure Repo     │
│ argocd-apps/school-app/ │
│   deployment.yaml        │
│   (image tag = 42)      │
└────────┬─────────────────┘
         │
         ├── (Git webhook)
         │
         ▼
┌──────────────────────────┐
│   ArgoCD (in EKS)        │
│ • Watches Git            │
│ • Detects changes        │
│ • Syncs to cluster       │
└────────┬─────────────────┘
         │
         ├── (Apply manifests)
         │
         ▼
┌──────────────────────────┐
│   Kubernetes Cluster     │
│ • Deployment created     │
│ • Pods start (v42)       │
│ • Service exposes        │
└──────────────────────────┘

TOTAL TIME (no manual steps): 15-25 minutes
JENKINS INVOLVEMENT: 0 after initial bootstrap
```

---

## Who Does What

### Jenkins (Infrastructure Pipeline)

```
✅ Manages: Infrastructure-as-Code (Terraform)
✅ Manages: ArgoCD bootstrap and initial setup
✅ Does: terraform init, plan, apply
✅ Does: kubectl setup and auth
✅ Does: ArgoCD installation

❌ Does NOT: Build Docker images (CI does)
❌ Does NOT: Deploy applications (ArgoCD does)
❌ Does NOT: Trigger other pipelines (bad practice)
❌ Does NOT: Manage application configuration
```

### ArgoCD (Continuous Deployment)

```
✅ Manages: All Kubernetes application deployments
✅ Watches: Git repository for manifest changes
✅ Does: Sync desired state (Git) to actual state (K8s)
✅ Does: Self-healing (revert manual changes)
✅ Does: Propagate changes without Jenkins

❌ Does NOT: Build infrastructure
❌ Does NOT: Manage AWS resources
❌ Does NOT: Build Docker images
```

### CI Pipeline (Separate Jenkins Job)

```
✅ Manages: Application source code building
✅ Does: Build Docker images
✅ Does: Run tests
✅ Does: Push images to registry

❌ Does NOT: Deploy applications (ArgoCD does)
❌ Does NOT: Manage infrastructure
❌ Does NOT: Trigger other pipelines
```

### Git Repository (Source of Truth)

```
✅ Stores: Infrastructure code (Terraform)
✅ Stores: Application manifests (deployment.yaml, etc.)
✅ Provides: Full audit trail (who changed what, when)
✅ Enables: Rollback (git revert)

❌ Stores: Docker images (registry does)
❌ Stores: Kubernetes state (etcd does)
❌ Stores: Secrets (external secret management)
```

---

## Key Concepts

### 1. One-Button Infrastructure Provisioning

```
Click: Infrastructure-Deploy (ACTION=plan) → Click: Infrastructure-Deploy (ACTION=apply)
Wait: ~25 minutes
Result: Complete EKS cluster with ArgoCD, ready for apps
```

### 2. No Jenkins in Application Deployment

```
App deployment = Push to Git (manifest change)
Jenkins = NOT involved
ArgoCD = Automatically syncs from Git
Time: <5 minutes (automatic)
```

### 3. GitOps as the CD Engine

```
Source of Truth: Git repository (argocd-apps/)
Enforcement: ArgoCD (watches Git, syncs to K8s)
Automation: Self-triggering (no Jenkins pipelines)
Audit Trail: Git history (who, what, when, why)
```

### 4. Destruction is Explicit and Safe

```
Trigger: Manual only (no schedule, no automation)
Confirmation: String that's hard to type accidentally
Backup: Terraform state preserved for recovery
Time: ~20 minutes (automated teardown)
```

---

## This Architecture Achieves

✅ **One-button automation** — Run one pipeline to bootstrap entire infrastructure
✅ **No manual steps** — Everything automated after initial setup
✅ **GitOps principles** — Git is the single source of truth
✅ **Continuous deployment** — Changes sync automatically via ArgoCD
✅ **Clear responsibility** — Jenkins = infrastructure, ArgoCD = applications
✅ **Auditability** — All changes tracked in Git
✅ **Safety** — Destruction requires explicit confirmation
✅ **Scalability** — Add apps by pushing YAML, not creating Jenkins jobs
✅ **Disaster recovery** — Rebuild from Terraform code + Git manifests

---

## Final Checklist Before Production

- [ ] Job "Infrastructure-Deploy" created in Jenkins
- [ ] Job "Infrastructure-Destroy" created in Jenkins
- [ ] Old CD pipeline jobs deleted
- [ ] AWS credentials available to Jenkins (via EC2 IAM role)
- [ ] Required CLI tools installed: kubectl, aws, eksctl
- [ ] S3 backend bucket exists and accessible
- [ ] Tested: Infrastructure-Deploy with ACTION=plan
- [ ] Tested: Infrastructure-Deploy with ACTION=apply
- [ ] Tested: Application deployment via Git (argocd-apps/)
- [ ] Tested: Application update (image tag change)
- [ ] Team trained on new GitOps workflow
- [ ] Documentation shared with team

Once all complete → You have a production-ready infrastructure with continuous deployment via GitOps!
