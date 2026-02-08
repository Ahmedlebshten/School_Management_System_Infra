# Quick Start Guide

**Fast reference for getting infrastructure + CI/CD running.**

---

## TL;DR

**Two Jenkins jobs. That's it.**

```
1. Infrastructure-Deploy     (terraform init/plan/apply + ArgoCD bootstrap)
2. Infrastructure-Destroy    (manual destruction with confirmation)

Everything else happens automatically via Git.
```

---

## Setup (5 Steps)

### Step 1: Create Jenkins Job #1 (Deploy)

In Jenkins UI:

```
New Item → Pipeline

Name: Infrastructure-Deploy
Repository: https://github.com/Ahmedlebshten/Jenkins-Pipeline-Build-Infra
Branch: master
Jenkinsfile: Jenkinsfile (from root)
Trigger: ❌ Manual only (no webhook)
Parameters: ✅ ACTION (choice: plan, apply)
```

### Step 2: Create Jenkins Job #2 (Destroy)

In Jenkins UI:

```
New Item → Pipeline

Name: Infrastructure-Destroy
Repository: https://github.com/Ahmedlebshten/Jenkins-Pipeline-Build-Infra
Branch: master
Jenkinsfile: Jenkinsfile.destroy
Trigger: ❌ Manual only (no webhook)
Parameters: ✅ CONFIRM_DESTROY (string, no default)
```

### Step 3: Delete Old Jobs

Delete these if they exist:

```
❌ Install-ArgoCD
❌ CD-Create-ArgoCD-Application
❌ CD-Create-Monitoring-Application
❌ Security-Tools-Create-Application
```

### Step 4: Run Bootstrap

```bash
# Go to Jenkins → Infrastructure-Deploy
# Click "Build with Parameters"
# ACTION = "plan"
# Click Build
# Review output (shows what will be created)

# Click "Build with Parameters" again
# ACTION = "apply"
# Click Build
# Wait ~30 minutes for cluster to provision
# ✅ Done! Cluster + ArgoCD ready
```

### Step 5: Create Application Manifests

```bash
cd Jenkins-Pipeline-Build-Infra

mkdir -p argocd-apps/school-app/

cat > argocd-apps/school-app/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: school-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: school-app
  template:
    metadata:
      labels:
        app: school-app
    spec:
      containers:
      - image: ahmedlebshten/school_management_system:1
        name: app
        ports:
        - containerPort: 8080
EOF

cat > argocd-apps/school-app/service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: school-app
spec:
  type: LoadBalancer
  ports:
  - port: 80
    targetPort: 8080
  selector:
    app: school-app
EOF

git add argocd-apps/
git commit -m "Add school-app to ArgoCD"
git push origin master

# ✅ ArgoCD auto-deploys within 3 minutes
```

---

## Daily Workflow

### Deploy New Version

```bash
# 1. Manually or via CI, new Docker image pushed:
#    ahmedlebshten/school_management_system:42

# 2. In infrastructure repo:
cd Jenkins-Pipeline-Build-Infra

# 3. Update deployment
sed -i 's/school_management_system:.*/school_management_system:42/' \
  argocd-apps/school-app/deployment.yaml

# 4. Commit and push
git add argocd-apps/school-app/deployment.yaml
git commit -m "Update to image v42"
git push origin master

# ✅ ArgoCD detects change → Kubernetes rolls out new version ~5 mins
# ✅ No Jenkins pipeline needed!
```

### Scale Application

```bash
# In infrastructure repo:
# Edit argocd-apps/school-app/deployment.yaml
# Change: spec.replicas = 10

git add argocd-apps/school-app/deployment.yaml
git commit -m "Scale to 10 replicas"
git push origin master

# ✅ ArgoCD detects → Kubernetes scales pods
```

### Add New Application

```bash
# 1. Create directory
mkdir -p argocd-apps/monitoring/

# 2. Create manifests (deployment.yaml, service.yaml, etc.)
# 3. Commit and push
git add argocd-apps/monitoring/
git commit -m "Add monitoring stack"
git push origin master

# ✅ ArgoCD auto-detects and deploys
# ✅ No Jenkins changes needed!
```

---

## Viewing Status

### Via CLI

```bash
# See all apps
kubectl -n argocd get apps

# Check specific app
argocd app get school-app

# See pods
kubectl get pods -n default

# Check logs
kubectl logs -n default -l app=school-app
```

### Via UI

```bash
# Port-forward to ArgoCD
kubectl -n argocd port-forward svc/argocd-server 8080:443

# Open browser
https://localhost:8080

# Login
Username: admin
Password: kubectl -n argocd get secret \
  argocd-initial-admin-secret -o \
  jsonpath="{.data.password}" | base64 -d
```

---

## Destroying Infrastructure

### ⚠️ WARNING: This deletes everything!

```bash
# Go to Jenkins → Infrastructure-Destroy
# Click "Build with Parameters"
# In CONFIRM_DESTROY field, type exactly:
yes-destroy-infrastructure

# Click Build
# ⏳ Wait 15-20 minutes
# ✅ All resources deleted
```

---

## Troubleshooting

### App not deploying?

```bash
# 1. Check manifests exist
git ls argocd-apps/school-app/

# 2. Validate YAML
kubectl apply -f argocd-apps/school-app/ --dry-run=client

# 3. Check ArgoCD sees it
argocd app get school-app

# 4. Check pods
kubectl get pods -n default

# 5. Check events
kubectl describe pod <pod-name> -n default
```

### Deployment stuck?

```bash
# Check image exists
docker pull ahmedlebshten/school_management_system:42

# Check registry credentials
kubectl get secret -A | grep docker

# Check node resources
kubectl top nodes
```

### ArgoCD not starting?

```bash
# Check pods
kubectl -n argocd get pods

# Check logs
kubectl -n argocd logs deployment/argocd-server

# Check if stuck
kubectl -n argocd describe pod argocd-server-xxx
```

---

## Terraform Commands (For Reference)

```bash
# Preview changes
terraform plan

# Apply changes
terraform apply

# Destroy (via pipeline, not CLI)
terraform destroy

# Check state
terraform show

# Validate syntax
terraform validate
```

---

## Important Files

| File                  | Purpose                         |
| --------------------- | ------------------------------- |
| `Jenkinsfile`         | Infrastructure pipeline (apply) |
| `Jenkinsfile.destroy` | Destroy pipeline (manual)       |
| `argocd-apps/`        | Application manifests (GitOps)  |
| `main.tf`             | Infrastructure definition       |
| `terraform.tfvars`    | Configuration values            |

---

## Key Concepts

### Git-Driven Deployment

```
You edit → Commit → Push → ArgoCD detects → Auto-deploys
(in Git)   (Git)   (Git)   (continuous)   (Kubernetes)

No Jenkins pipeline needed!
```

### Self-Healing

```
If someone manually change pods:
Cluster state ≠ Git state
    ↓
ArgoCD detects drift
    ↓
Reverts to Git version
    ↓
Cluster state = Git state again

Git always wins!
```

### App of Apps

```
Root Application
    ├── App: school-app
    ├── App: monitoring
    ├── App: ci-tools
    └── App: databases

One root app manages all sub-apps
One argocd-apps/ directory is source of truth
```

---

## One-Page Cheat Sheet

```bash
# Bootstrap (one time)
1. Jenkins → Infrastructure-Deploy
2. ACTION = plan, Build, review
3. ACTION = apply, Build, wait 30 mins
4. ✅ Cluster ready

# Daily Ops (everything via Git)
5. Create app manifests in argocd-apps/
6. Commit and push
7. ArgoCD auto-deploys (3 mins)

# Update app (from CI)
8. New Docker image built → pushed to registry
9. Update image tag in Git manifest
10. Commit and push
11. ArgoCD auto-rolls out (5 mins)

# Scale app (via Git)
12. Change replicas in deployment.yaml
13. Commit and push
14. ArgoCD auto-scales (1 min)

# Destroy (if needed)
15. Jenkins → Infrastructure-Destroy
16. CONFIRM_DESTROY = "yes-destroy-infrastructure"
17. Build, wait 20 mins
18. ✅ All deleted
```

---

## Documentation

- **Detailed Setup**: See `JENKINS_SETUP.md`
- **Architecture & Flow**: See `ARCHITECTURE.md`
- **GitOps Best Practices**: See `GITOPS_WORKFLOW.md`
- **Complete Change Summary**: See `REFACTORING_SUMMARY.md`

---

## Support

Q: Why don't my manifests deploy?
A: Check `GITOPS_WORKFLOW.md` → Troubleshooting section

Q: How do I rollback?
A: `git revert <commit>` → Push → ArgoCD auto-reverts

Q: Can I deploy from different Git repo?
A: Yes. Change `source.repoURL` in Application spec

Q: How do I use secrets securely?
A: See `GITOPS_WORKFLOW.md` → Handling Secrets Securely

Q: Can I disable auto-sync?
A: Yes. Set `syncPolicy.automated: false` per app

---

**Remember:** Git is your deployment tool now, not Jenkins. Everything flows through Git.
