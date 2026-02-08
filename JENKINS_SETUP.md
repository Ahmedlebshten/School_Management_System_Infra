# Jenkins Jobs Configuration Guide

After refactoring, you need to create exactly **TWO Jenkins jobs** in your Jenkins instance.

---

## Overview

| Job Name                   | Type                            | Repository        | Trigger         | Purpose                                                      |
| -------------------------- | ------------------------------- | ----------------- | --------------- | ------------------------------------------------------------ |
| **Infrastructure-Deploy**  | Pipeline (Scripted/Declarative) | This repo (infra) | **Manual Only** | Provisions AWS infrastructure + bootstraps ArgoCD            |
| **Infrastructure-Destroy** | Pipeline (Scripted/Declarative) | This repo (infra) | **Manual Only** | Destroys AWS infrastructure (requires explicit confirmation) |

---

## Job 1: Infrastructure-Deploy (Main Pipeline)

### Configuration

**Name:** `Infrastructure-Deploy`

**Type:** Pipeline

**Repository:**

```
URL: https://github.com/Ahmedlebshten/Jenkins-Pipeline-Build-Infra.git
Branch: master
```

**Jenkinsfile Location:** `Jenkinsfile` (root of repo)

### Build Trigger

⚠️ **DO NOT ENABLE ANY AUTOMATIC TRIGGERS**

- ❌ Do NOT enable "GitHub webhook trigger"
- ❌ Do NOT enable "Poll SCM"
- ❌ Do NOT enable "Build periodically"
- ✅ **Manual trigger ONLY** — Click "Build with Parameters" in Jenkins UI

### Build Parameters

This job accepts a build parameter:

```
Name: ACTION
Type: Choice Parameter
Choices:
  - plan
  - apply
Default: plan
Description: "Terraform action: 'plan' (preview changes), 'apply' (provision infrastructure)"
```

### Credentials Required

Ensure Jenkins has credentials configured:

- **AWS Access Key / Role:** Jenkins EC2 instance should have IAM role with terraform permissions
  - The EC2 instance running Jenkins must have:
    - Policy: `AmazonEKSFullAccess`
    - Policy: `AmazonVPCFullAccess`
    - Policy: `IAMFullAccess` (for role creation)
    - S3 access for state file bucket

- **GitHub Token:** (for pulling Terraform code)
  - Credentials ID: `github-credentials` (can be any name)
  - Used in Jenkins credentials store

### Build Steps

⚠️ **The Jenkinsfile handles everything — NO additional build steps needed**

The Jenkinsfile automatically:

1. Checks out code
2. Runs terraform init
3. Runs terraform plan
4. Runs terraform apply (if ACTION=apply)
5. Bootstraps ArgoCD
6. Creates root ArgoCD Application

### Expected Behavior

#### When ACTION = "plan":

```
✅ Terraform plan created
✅ Shows what WOULD be created (no changes applied)
✅ Safe to review
```

#### When ACTION = "apply":

```
✅ Terraform apply executes
✅ AWS infrastructure provisioned
✅ ArgoCD installed
✅ Root application created
✅ Takes ~20-30 minutes total
```

### Success Indicators

After successful build:

```
✅ ✅ ✅ INFRASTRUCTURE PIPELINE COMPLETED SUCCESSFULLY ✅ ✅ ✅

NEXT STEPS - Automated by GitOps:
1️⃣  CI PIPELINE (Automatic via GitHub webhook)
2️⃣  ARGOCD DEPLOYMENT (Automatic via GitOps)
3️⃣  NO JENKINS INVOLVED IN APP DEPLOYMENT
```

### First-Time Setup Checklist

- [ ] Job name is exactly `Infrastructure-Deploy`
- [ ] Repository URL points to correct Git repo
- [ ] Branch is set to `master`
- [ ] Jenkinsfile path is root: `Jenkinsfile`
- [ ] NO automatic triggers enabled
- [ ] Build parameters include `ACTION` choice parameter
- [ ] AWS credentials/role configured on Jenkins EC2
- [ ] Terraform backend S3 bucket exists and is accessible
- [ ] Run build with ACTION=plan first (safe preview)
- [ ] Review terraform plan output
- [ ] Run build with ACTION=apply to provision infrastructure

---

## Job 2: Infrastructure-Destroy (Cleanup)

### Configuration

**Name:** `Infrastructure-Destroy`

**Type:** Pipeline

**Repository:**

```
URL: https://github.com/Ahmedlebshten/Jenkins-Pipeline-Build-Infra.git
Branch: master
```

**Jenkinsfile Location:** `Jenkinsfile.destroy` (root of repo)

### Build Trigger

⚠️ **MUST BE MANUAL ONLY**

- ❌ Do NOT enable any automatic triggers
- ✅ **Manual trigger ONLY** — Only run when intentionally destroying infrastructure

### Build Parameters

This job requires a confirmation parameter:

```
Name: CONFIRM_DESTROY
Type: String Parameter
Default: (empty)
Description: "Type exactly 'yes-destroy-infrastructure' to proceed with destruction. This is your final safety confirmation."
```

### Credentials Required

Same as Infrastructure-Deploy:

- AWS access (via EC2 IAM role)
- S3 state file access

### How to Use Infrastructure-Destroy

**⚠️ DANGER ZONE — Only use when you INTENTIONALLY want to delete infrastructure**

1. Go to Jenkins
2. Click on `Infrastructure-Destroy` job
3. Click "Build with Parameters"
4. In the text field for `CONFIRM_DESTROY`, type exactly:
   ```
   yes-destroy-infrastructure
   ```
5. Click "Build"
6. Monitor logs carefully
7. ⏳ Process takes 15-20 minutes
8. Verify all resources deleted in AWS Console

### What Gets Destroyed

✅ EKS cluster and all running pods
✅ VPC and all subnets
✅ NAT Gateways
✅ Internet Gateways
✅ Route tables
✅ Security groups
✅ IAM roles and policies
✅ All associated AWS resources

### What Does NOT Get Destroyed

❌ Terraform state file (kept for recovery)
❌ S3 backend bucket (kept for re-initialization)
❌ CloudWatch logs (may need manual cleanup)

### Recovery After Destroy

If you destroyed infrastructure and want to rebuild:

1. Run `Infrastructure-Deploy` with ACTION=plan
2. Run `Infrastructure-Deploy` with ACTION=apply
3. New infrastructure will be provisioned
4. Note: Previous data is permanently lost

---

## Important: Jobs That Should NOT Exist

**DELETE these jobs if they exist** (they violate GitOps):

- ❌ `Install-ArgoCD` — Removed (done by main pipeline now)
- ❌ `CD-Create-ArgoCD-Application` — Removed (GitOps handles this)
- ❌ `CD-Create-Monitoring-Application` — Removed (GitOps handles this)
- ❌ `Security-Tools-Create-Application` — Removed (GitOps handles this)
- ❌ Any pipeline that deploys applications — Removed (ArgoCD's job)

---

## Jenkins Global Configuration

### Required Jenkins Plugins

Ensure these plugins are installed:

- ✅ Pipeline
- ✅ Git
- ✅ AWS credentials
- ✅ CloudBees AWS Credentials (optional, helpful)

### Jenkins EC2 Instance IAM Role

The EC2 instance running Jenkins needs an IAM role with:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["eks:*", "ec2:*", "iam:*", "vpc:*", "s3:*", "logs:*"],
      "Resource": "*"
    }
  ]
}
```

### Jenkins Environment Variables

Set these in Jenkins Configure System (or in the Jenkinsfile):

```
AWS_REGION=us-east-1
AWS_DEFAULT_REGION=us-east-1
KUBECONFIG=~/.kube/config
```

---

## Testing the Setup

### Step 1: Verify Jobs Exist

```bash
# Via Jenkins CLI or UI:
# - Infrastructure-Deploy
# - Infrastructure-Destroy
```

### Step 2: Test with Plan (Safe)

```bash
# Run Infrastructure-Deploy with ACTION=plan
# This shows what WOULD happen without making changes
```

### Step 3: Review Terraform Plan Output

```
- Check that it wants to create VPC
- Check that it wants to create EKS cluster
- Check that it wants to create IAM roles
- NO resources should be deleted
```

### Step 4: Apply Infrastructure (if Plan looks good)

```bash
# Run Infrastructure-Deploy with ACTION=apply
# This provisions actual AWS resources
# Approx time: 20-30 minutes
```

### Step 5: Verify ArgoCD Bootstrap

```bash
# After apply completes, check:
kubectl -n argocd get pods
# Should see argocd-server, argocd-repo-server, etc.

# Try to access ArgoCD:
kubectl -n argocd port-forward svc/argocd-server 8080:443
# Open https://localhost:8080
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Step 6: Verify Root Application

```bash
# Check if root-app was created:
kubectl -n argocd get app

# Should see:
# NAME       SYNC STATUS   HEALTH STATUS
# root-app   Unknown       Unknown
```

---

## Troubleshooting

### Problem: Build fails at "Terraform Init"

**Symptoms:** Error about backend bucket

**Solution:**

1. Check that S3 bucket exists: `jenkins-terraform-backend-9904`
2. Check that Jenkins IAM role can access the bucket
3. Verify bucket region matches `backend.tf` configuration

### Problem: "kubeconfig not found" at ArgoCD bootstrap

**Symptoms:** kubectl: not found

**Solution:**

1. Ensure `kubectl` and `aws` CLI installed on Jenkins agent
2. Ensure AWS credentials available to Jenkins
3. Verify Jenkins EC2 instance has IAM role

### Problem: "eksctl: not found"

**Symptoms:** Error at "Mapping Jenkins IAM role"

**Solution:**

1. Install eksctl on Jenkins agent:
   ```bash
   curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz
   sudo mv eksctl /usr/local/bin
   ```

### Problem: Destroy fails partway through

**Symptoms:** Error but some resources deleted

**Solution:**

1. Check AWS Console for remaining resources
2. Remove resources with deletion protection
3. Delete orphaned ELBs
4. Retry destroy pipeline

---

## Final Checklist

Use this before going to production:

- [ ] Both jobs created in Jenkins
- [ ] No other application deployment jobs exist
- [ ] Infrastructure-Deploy manual trigger only
- [ ] Infrastructure-Destroy manual trigger only
- [ ] AWS credentials configured
- [ ] S3 backend bucket ready
- [ ] kubectl and aws CLI installed on Jenkins
- [ ] eksctl installed on Jenkins
- [ ] Tested "plan" successfully
- [ ] Tested "apply" successfully (or will do first time)
- [ ] ArgoCD installs successfully
- [ ] Root application created
- [ ] Team trained on GitOps workflow
- [ ] Documentation updated

---

## Questions?

Refer to:

- `ARCHITECTURE.md` — How everything works together
- `GITOPS_WORKFLOW.md` — How applications are deployed automatically
- `Jenkinsfile` — Inline comments explaining each stage
- `Jenkinsfile.destroy` — Inline comments explaining destruction
