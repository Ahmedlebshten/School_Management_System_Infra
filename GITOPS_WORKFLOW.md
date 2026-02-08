# GitOps Workflow Guide

This guide explains how to deploy and manage applications using **ArgoCD** in a GitOps fashion.

---

## What is GitOps?

**GitOps** is a deployment methodology where:

1. **Git is the source of truth** — all desired application state is in Git
2. **Everything is declarative** — YAML manifests describe what should exist
3. **Continuous reconciliation** — ArgoCD constantly ensures cluster matches Git
4. **No manual deployments** — changes happen automatically when you push to Git

### Core Principle: You Don't Deploy, Git Does

```
❌ OLD WAY (Manual):
Developer → kubectl apply → Cluster
            (manual command)

✅ NEW WAY (GitOps):
Developer → Git push → ArgoCD → Cluster
           (automatic via webhook)
```

---

## Directory Structure for Applications

Your infrastructure repository has this structure:

```
Jenkins-Pipeline-Build-Infra/   (Infrastructure repo)
├── argocd-apps/                # ALL APPLICATIONS ARE HERE
│   ├── README.md
│   ├── school-app/             # Example: School app
│   │   ├── kustomization.yaml  (optional, for overlays)
│   │   ├── deployment.yaml     (pod definition)
│   │   ├── service.yaml        (load balancer/port)
│   │   ├── configmap.yaml      (config values)
│   │   ├── secret.yaml         (credentials)
│   │   └── ingress.yaml        (URL routing)
│   ├── monitoring/             # Example: Monitoring stack
│   │   ├── prometheus.yaml
│   │   ├── grafana.yaml
│   │   └── alertmanager.yaml
│   └── ci-apps/                # Example: CI/CD tools
│       ├── nexus.yaml
│       └── sonarqube.yaml
├── modules/
├── main.tf
└── ...
```

---

## Deploying a New Application

### Step 1: Create Application Manifest

Create a new directory in `argocd-apps/` for your application:

```bash
mkdir -p argocd-apps/my-application
```

### Step 2: Write Kubernetes Manifests

Create `deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: default # Or create dedicated namespace
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: my-app
          image: ahmedlebshten/school_management_system:1 # Your Docker image
          ports:
            - containerPort: 8080
          env:
            - name: DATABASE_URL
              valueFrom:
                configMapKeyRef:
                  name: my-app-config
                  key: db_url
            - name: API_KEY
              valueFrom:
                secretKeyRef:
                  name: my-app-secrets
                  key: api_key
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 5
```

Create `service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
  namespace: default
spec:
  type: LoadBalancer # Exposes service to internet
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  selector:
    app: my-app
```

Create `configmap.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-app-config
  namespace: default
data:
  db_url: "postgresql://db.internal:5432/appdb"
  api_timeout: "30"
  log_level: "INFO"
```

Create `secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-app-secrets
  namespace: default
type: Opaque
stringData: # Use stringData for clear values (encode before committing to prod)
  api_key: "xxxxxxxxxx"
  db_password: "xxxxxxxxxx"
```

> ⚠️ **Security Note**: Don't commit actual secrets to Git!
> Use [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) or [External Secrets Operator](https://github.com/external-secrets/external-secrets) instead.

### Step 3: Create ArgoCD Application Manifest

Create `argocd-applications.yaml` (in the root `argocd-apps/` directory):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-application
  namespace: argocd
spec:
  project: default

  # Where to get the manifests
  source:
    repoURL: https://github.com/Ahmedlebshten/Jenkins-Pipeline-Build-Infra
    targetRevision: master
    path: argocd-apps/my-application

  # Where to deploy them
  destination:
    server: https://kubernetes.default.svc
    namespace: default

  # Auto-sync settings (GitOps magic!)
  syncPolicy:
    automated:
      prune: true # Delete resources removed from Git
      selfHeal: true # Reconcile if cluster drifts from Git
    syncOptions:
      - CreateNamespace=true # Auto-create namespace if missing

  # Health assessment
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas # Ignore if HPA changes replicas
```

### Step 4: Push to Git

```bash
cd Jenkins-Pipeline-Build-Infra
git add argocd-apps/my-application/
git add argocd-apps/argocd-applications.yaml
git commit -m "Add my-application to ArgoCD deployments"
git push origin master
```

### Step 5: Automatic Deployment

**You're done!** ArgoCD automatically:

1. Detects the new manifest (within ~3 minutes)
2. Creates the Deployment
3. Creates the Service
4. Creates ConfigMap and Secret
5. Launches your application pods
6. Exposes it via LoadBalancer

No manual `kubectl apply` needed!

---

## Updating an Application

### Scenario: Docker Image Updated

Your CI pipeline pushed a new image: `school_management_system:42`

**To deploy the new version:**

1. Update the manifest in Git:

```yaml
# File: argocd-apps/school-app/deployment.yaml
spec:
  template:
    spec:
      containers:
        - image: ahmedlebshten/school_management_system:42 # Changed from :41
```

2. Commit and push:

```bash
git add argocd-apps/school-app/deployment.yaml
git commit -m "Update school-app to image version 42"
git push origin master
```

3. **Automatic:** ArgoCD detects change → Kubernetes rolls out new pods

**Done!** No jenkins, no manual deploy command.

### Scenario: Config Value Changed

Update your ConfigMap:

```yaml
# File: argocd-apps/school-app/configmap.yaml
data:
  log_level: "DEBUG" # Changed from INFO
  api_timeout: "60" # Changed from 30
```

**Same process:** Commit → Git → ArgoCD auto-syncs

### Scenario: Scaling Application

Change replicas in Deployment:

```yaml
spec:
  replicas: 5 # Changed from 3
```

**Same process:** Commit → Git → Kubernetes scales up

---

## Using Image Tags Correctly

### ❌ NOT RECOMMENDED: Using "latest" tag

```yaml
image: ahmedlebshten/school_management_system:latest
```

**Problem:** Can't reproduction which version is deployed

### ✅ RECOMMENDED: Using incremental numeric tags

```yaml
image: ahmedlebshten/school_management_system:42
```

**Benefits:**

- Clear version history
- Easy to rollback (change :42 → :41)
- CI can automatically increment tags

### CI Implementation for Tagging

In your CI pipeline:

```groovy
stage('Build and Push Image') {
  steps {
    sh '''
      # Get current build number
      BUILD_NUM=${BUILD_NUMBER}

      # Build image
      docker build -t school_management_system:$BUILD_NUM .

      # Push to registry
      docker push ahmedlebshten/school_management_system:$BUILD_NUM

      echo "Image pushed: school_management_system:$BUILD_NUM"
    '''
  }
}
```

---

## Multiple Applications Example

```
argocd-apps/
├── school-app-frontend/       # React/Vue frontend
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── school-app-backend/        # API backend
│   ├── deployment.yaml
│   ├── service.yaml
│   └── configmap.yaml
├── database/                  # PostgreSQL
│   ├── statefulset.yaml
│   ├── service.yaml
│   └── pvc.yaml
├── cache/                     # Redis
│   ├── deployment.yaml
│   └── service.yaml
└── argocd-applications.yaml   # Defines all apps to ArgoCD
```

---

## Monitoring Application Status

### Via CLI

```bash
# List all ArgoCD applications
kubectl -n argocd get apps

# Get detailed status
argocd app get my-application

# Watch sync status
argocd app get my-application --watch
```

### Via UI

```bash
# Port-forward to ArgoCD UI
kubectl -n argocd port-forward svc/argocd-server 8080:443

# Open browser
# https://localhost:8080
# Username: admin
# Password: (from secret)
```

**UI shows:**

- ✅ Synced / Out of Sync
- ✅ Healthy / Degraded
- ✅ Git version vs. Cluster version
- ✅ Resource tree (Deployment → ReplicaSet → Pod)

---

## Handling Secrets Securely

### ⚠️ Problem: Secrets in Git

**Storing plaintext secrets in Git is a SECURITY RISK!**

### Solution 1: Use External Secrets Operator (Recommended)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secrets
spec:
  secretStoreRef:
    name: aws-secrets
  target:
    name: my-app-secrets
    template:
      type: Opaque
  data:
    - secretKey: api_key
      remoteRef:
        key: school-app/api_key
    - secretKey: db_password
      remoteRef:
        key: school-app/db_password
```

This way:

- ✅ Secrets stored in AWS Secrets Manager (not Git)
- ✅ Operator fetches secrets at deployment time
- ✅ Git only has reference, not actual secrets

### Solution 2: Use Sealed Secrets

```bash
# Encrypt secret
echo -n 'my-password' | kubeseal -o yaml > sealed-secret.yaml

# Add sealed-secret.yaml to Git (safe)
# Seal Operator automatically decrypts it in cluster
```

---

## Rollback: Reverting to Previous Version

### Using Git History

```bash
# See previous versions
git log --oneline argocd-apps/school-app/deployment.yaml

# Revert to previous version
git revert <commit-hash>
git push origin master
```

**Automatic:** ArgoCD detects change → Kubernetes rolls back to previous image

### Manual Rollback

```bash
# If you must roll back immediately
argocd app rollback my-application <revision>
```

---

## Namespaces and Multi-Tenancy

Deploy to separate namespaces for isolation:

```yaml
# school-app lives in school-app namespace
apiVersion: v1
kind: Namespace
metadata:
  name: school-app

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: school-app # Note: separate namespace
```

Benefits:

- ✅ Resource isolation
- ✅ RBAC policy per namespace
- ✅ Network policies control communication
- ✅ Easy to delete entire app (delete namespace)

---

## Health Checks & Self-Healing

### Liveness Probe (Pod restart)

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  failureThreshold: 3
  periodSeconds: 10
```

If `/health` returns non-200:

- Probe fails 3 times (30 seconds)
- Kubernetes kills Pod
- ReplicaSet starts new Pod

### Readiness Probe (Traffic routing)

```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  failureThreshold: 2
  periodSeconds: 5
```

If `/ready` returns non-200:

- Pod still running (not killed)
- Service removes pod from endpoints
- No traffic sent to pod

### ArgoCD Self-Healing

ArgoCD continuously checks if cluster matches Git:

```yaml
syncPolicy:
  automated:
    selfHeal: true # Reconcile every 3 minutes
```

If someone manually changes pod:

- ArgoCD detects drift
- ArgoCD re-applies Git manifests
- Cluster returns to desired state

---

## Best Practices

### 1. Use Semantic Versioning for Images

```yaml
image: ahmedlebshten/school_management_system:1.2.3 # MAJOR.MINOR.PATCH
```

Or incremental build numbers:

```yaml
image: ahmedlebshten/school_management_system:42 # Build #42
```

### 2. One Application Per Directory

```
argocd-apps/
├── app1/
├── app2/
└── app3/
```

NOT:

```
argocd-apps/
└── all-apps.yaml  # ❌ Don't put everything in one file
```

### 3. Use ConfigMaps for Configuration

```yaml
# ✅ GOOD: Environment-specific config in Git
data:
  environment: "production"
  log_level: "INFO"
```

NOT:

```yaml
# ❌ BAD: Hardcoded in code
env:
  - name: LOG_LEVEL
    value: "DEBUG" # Changes require code redeploy
```

### 4. Separate Secrets from Code

```yaml
# ✅ GOOD: Reference external secret
valueFrom:
  secretKeyRef:
    name: external-secret
    key: api_key
```

NOT:

```yaml
# ❌ BAD: Hardcoded in code or manifest
env:
  - name: API_KEY
    value: "xxxxxxxxxx"
```

### 5. Use Health Checks

```yaml
# ✅ GOOD: Each pod checks health
livenessProbe:
  httpGet:
    path: /health
    port: 8080
```

### 6. Define Resource Requests/Limits

```yaml
# ✅ GOOD: Kubernetes can schedule properly
resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```

### 7. DocumentYour ArgoCD Structure

Create `argocd-apps/README.md`:

```markdown
# ArgoCD Applications

This directory contains all Kubernetes manifests deployed by ArgoCD.

## Structure

- `school-app/` — Main school management application
- `monitoring/` — Prometheus, Grafana
- `ci-tools/` — Jenkins, SonarQube

## Adding New App

1. Create `argocd-apps/my-app/` directory
2. Create `deployment.yaml`, `service.yaml`, etc.
3. Add to `argocd-applications.yaml`
4. Commit and push
5. ArgoCD automatically deploys

## Updating Existing App

1. Edit `deployment.yaml` (change image tag, replicas, config)
2. Commit and push
3. ArgoCD detects change within 3 minutes
4. Kubernetes rolls out update automatically
```

---

## Troubleshooting

### App Out of Sync

```bash
# Check what's different
argocd app diff my-application

# Force sync to Git
argocd app sync my-application
```

### App Stuck in "Progressing"

```bash
# Check pod status
kubectl describe pod -n default -l app=my-app

# Check events
kubectl get events -n default

# Check logs
kubectl logs -n default <pod-name>
```

### Manual Changes Override by ArgoCD

This is actually **GOOD** (self-healing)!

If someone manually scales:

```bash
kubectl scale deployment my-app --replicas=10
```

ArgoCD will revert it to match Git:

```bash
# ArgoCD detects drift
# Reverts to git version (replicas: 3)
```

If you want to keep manual changes:

```bash
# Disable auto-sync temporarily
argocd app set my-application --sync-policy none

# Make manual changes
# When done, update Git
# Re-enable auto-sync
```

---

## Next Steps

1. **Create first application manifest** in `argocd-apps/my-app/`
2. **Push to Git**
3. **Verify ArgoCD detects it** — `kubectl -n argocd get apps`
4. **Monitor deployment** — Watch pods come up
5. **Access application** — Use LoadBalancer endpoint
6. **Update application** — Change image tag, commit, watch ArgoCD deploy
7. **Share with team** — Everyone uses Git to deploy!

---

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://www.gitops.tech/)
- [Kubernetes Manifests Best Practices](https://kubernetes.io/docs/concepts/configuration/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://github.com/external-secrets/external-secrets)
