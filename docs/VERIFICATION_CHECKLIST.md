# Verification Checklist

Use this checklist to verify the refactoring is complete and correct before deploying to production.

---

## Code Changes Verification

- [ ] **Jenkinsfile refactored**
  - [ ] Removed `terraform destroy` from main pipeline
  - [ ] Uncommented `terraform apply` stage
  - [ ] Added `ACTION` parameter (plan/apply choice)
  - [ ] Added ArgoCD bootstrap stage
  - [ ] Added "Create Root Application" stage
  - [ ] Removed ALL downstream `build job:` triggers
  - [ ] Added proper documentation comments on each stage
  - [ ] Post-success message explains no Jenkins involved in CD

- [ ] **Jenkinsfile.destroy created**
  - [ ] File exists: `Jenkinsfile.destroy`
  - [ ] Includes explicit destruction confirmation
  - [ ] Requires `CONFIRM_DESTROY = "yes-destroy-infrastructure"`
  - [ ] Clear warnings about data loss
  - [ ] Proper error handling and recovery notes
  - [ ] Fully commented for clarity

- [ ] **outputs.tf enhanced**
  - [ ] Export `aws_region` (used by Jenkinsfile)
  - [ ] Export `project_name` (for consistency)
  - [ ] Export `environment` (for multi-env support)

- [ ] **Documentation created**
  - [ ] `JENKINS_SETUP.md` — Jenkins job configuration guide
  - [ ] `ARCHITECTURE.md` — System design and flow diagrams
  - [ ] `GITOPS_WORKFLOW.md` — GitOps best practices guide
  - [ ] `REFACTORING_SUMMARY.md` — What changed and why
  - [ ] `QUICK_START.md` — Quick reference
  - [ ] `VERIFICATION_CHECKLIST.md` — This file

---

## Jenkins Configuration Verification

- [ ] **Infrastructure-Deploy job created**
  - [ ] Name: Exactly `Infrastructure-Deploy`
  - [ ] Type: Pipeline
  - [ ] Repository: `https://github.com/Ahmedlebshten/Jenkins-Pipeline-Build-Infra`
  - [ ] Branch: `master`
  - [ ] Jenkinsfile path: `Jenkinsfile` (root)
  - [ ] Build parameter: ACTION (choice: plan, apply)
  - [ ] Trigger: ❌ NO automatic triggers
  - [ ] Trigger: ✅ Manual only

- [ ] **Infrastructure-Destroy job created**
  - [ ] Name: Exactly `Infrastructure-Destroy`
  - [ ] Type: Pipeline
  - [ ] Repository: `https://github.com/Ahmedlebshten/Jenkins-Pipeline-Build-Infra`
  - [ ] Branch: `master`
  - [ ] Jenkinsfile path: `Jenkinsfile.destroy`
  - [ ] Build parameter: CONFIRM_DESTROY (string, no default)
  - [ ] Trigger: ❌ NO automatic triggers
  - [ ] Trigger: ✅ Manual only

- [ ] **Old jobs deleted (if they existed)**
  - [ ] ❌ Deleted: `Install-ArgoCD`
  - [ ] ❌ Deleted: `CD-Create-ArgoCD-Application`
  - [ ] ❌ Deleted: `CD-Create-Monitoring-Application`
  - [ ] ❌ Deleted: `Security-Tools-Create-Application`
  - [ ] ❌ Deleted: Any other application deployment jobs

- [ ] **Jenkins prerequisites verified**
  - [ ] Jenkins has Pipeline plugin installed
  - [ ] Jenkins has Git plugin installed
  - [ ] EC2 instance has IAM role (EKS, VPC, IAM permissions)
  - [ ] `kubectl` installed on Jenkins agent
  - [ ] `aws` CLI installed on Jenkins agent
  - [ ] `eksctl` installed on Jenkins agent
  - [ ] S3 backend bucket exists: `jenkins-terraform-backend-9904`
  - [ ] S3 bucket accessible from Jenkins (via IAM role)

---

## Infrastructure Tests

- [ ] **Run Terraform Plan (Safe Preview)**

  ```bash
  # Go to Jenkins → Infrastructure-Deploy
  # Build with Parameters: ACTION = plan
  # Click Build
  # ✅ Plan shows infra to be created
  # ✅ No "Destroy" actions in plan
  # ✅ Terraform validates successfully
  ```

- [ ] **Apply Infrastructure (First Time)**

  ```bash
  # Go to Jenkins → Infrastructure-Deploy
  # Build with Parameters: ACTION = apply
  # Click Build
  # ⏳ Wait 20-30 minutes
  # ✅ Terraform apply succeeds
  # ✅ VPC created (check AWS Console)
  # ✅ EKS cluster created (check AWS Console)
  # ✅ IAM roles created
  ```

- [ ] **Verify EKS Cluster**

  ```bash
  # Get cluster info
  aws eks describe-cluster \
    --name hello-devops-production-cluster \
    --region us-east-1

  # Update kubeconfig
  aws eks update-kubeconfig \
    --region us-east-1 \
    --name hello-devops-production-cluster

  # Verify nodes
  kubectl get nodes
  # ✅ Should show 2-3 nodes in Ready state
  ```

---

## ArgoCD Bootstrap Verification

- [ ] **ArgoCD installed**

  ```bash
  kubectl -n argocd get pods
  # ✅ Should see:
  #   argocd-server
  #   argocd-repo-server
  #   argocd-controller-manager
  #   argocd-redis
  #   argocd-dex-server
  ```

- [ ] **ArgoCD server ready**

  ```bash
  kubectl -n argocd wait --for=condition=Available \
    deployment/argocd-server \
    --timeout=60s
  # ✅ Should show: condition met
  ```

- [ ] **Jenkins IAM role mapped to RBAC**

  ```bash
  # Check the mapping
  aws eks list-identity-provider-configs \
    --cluster-name hello-devops-production-cluster \
    --region us-east-1
  ```

- [ ] **Root Application created**

  ```bash
  kubectl -n argocd get apps
  # ✅ Should see: root-app in list

  kubectl -n argocd describe app root-app
  # ✅ Shows: argocd-apps directory as source
  # ✅ Target: argocd namespace
  ```

---

## Separation of Concerns Verification

- [ ] **Jenkins does NOT trigger other jobs**
  - [ ] Jenkinsfile contains NO `build job:` statements
  - [ ] Jenkinsfile contains NO `trigger downstream` statements
  - [ ] No hard `sleep()` calls between operations

- [ ] **Jenkins does NOT deploy applications**
  - [ ] Jenkinsfile contains NO `kubectl apply` for apps
  - [ ] Jenkinsfile contains NO ArgoCD Application creation for apps
  - [ ] Jenkinsfile ONLY creates root application

- [ ] **ArgoCD, not Jenkins, handles application deployments**
  - [ ] ArgoCD watches `argocd-apps/` directory
  - [ ] ArgoCD automatically syncs changes
  - [ ] Jenkins has no involvement in app deployment

- [ ] **Terraform destroy is separate**
  - [ ] Jenkinsfile (apply) has NO destroy stage
  - [ ] Jenkinsfile.destroy is separate file
  - [ ] Destroy requires explicit confirmation

---

## Application Deployment Test

- [ ] **Create test application manifests**

  ```bash
  mkdir -p argocd-apps/test-app

  cat > argocd-apps/test-app/deployment.yaml <<'EOF'
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: test-app
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: test-app
    template:
      metadata:
        labels:
          app: test-app
      spec:
        containers:
        - image: nginx:latest
          name: nginx
          ports:
          - containerPort: 80
  EOF

  cat > argocd-apps/test-app/service.yaml <<'EOF'
  apiVersion: v1
  kind: Service
  metadata:
    name: test-app
  spec:
    type: LoadBalancer
    ports:
    - port: 80
      targetPort: 80
    selector:
      app: test-app
  EOF

  git add argocd-apps/test-app/
  git commit -m "Add test app"
  git push origin master
  ```

- [ ] **Verify ArgoCD detects and deploys**

  ```bash
  # Wait 3-5 minutes maximum

  # Check ArgoCD sees it
  kubectl -n argocd get apps | grep test-app
  # ✅ Should show test-app

  # Check pods created
  kubectl get pods | grep test-app
  # ✅ Should show pod running

  # Check service created
  kubectl get svc | grep test-app
  # ✅ Should show LoadBalancer with external IP
  ```

- [ ] **Verify self-healing (ArgoCD reverts manual changes)**

  ```bash
  # Manually change something (intentionally)
  kubectl scale deployment test-app --replicas=5

  # Check it changed
  kubectl get deployment test-app
  # Shows: replicas: 5

  # Wait 3 minutes for ArgoCD sync
  # (Or force: argocd app sync test-app)

  # ArgoCD reverts to Git version
  kubectl get deployment test-app
  # ✅ Shows: replicas: 1 (back to Git state)
  ```

- [ ] **Test update (change image tag)**

  ```bash
  # Simulate CI pushing new image
  # Update deployment
  sed -i 's/nginx:latest/nginx:1.25/' \
    argocd-apps/test-app/deployment.yaml

  git add argocd-apps/test-app/deployment.yaml
  git commit -m "Update test-app to nginx 1.25"
  git push origin master

  # Wait 3-5 minutes
  # Check pods updating
  kubectl rollout status deployment/test-app
  # ✅ Should see rollout completion
  ```

- [ ] **Clean up test app**

  ```bash
  # Remove from Git
  rm -rf argocd-apps/test-app/
  git add -A
  git commit -m "Remove test app"
  git push origin master

  # Wait for sync
  # App should be deleted
  kubectl get pods | grep test-app
  # ✅ Should show: No resources found
  ```

---

## Documentation Verification

- [ ] **All documentation exists**
  - [ ] `JENKINS_SETUP.md` — Complete and detailed
  - [ ] `ARCHITECTURE.md` — Shows flow diagrams and interactions
  - [ ] `GITOPS_WORKFLOW.md` — Covers best practices and examples
  - [ ] `REFACTORING_SUMMARY.md` — Explains what changed
  - [ ] `QUICK_START.md` — Provides quick reference
  - [ ] `VERIFICATION_CHECKLIST.md` — This file

- [ ] **Documentation is accurate**
  - [ ] Jenkins job names match actual jobs
  - [ ] File paths are correct
  - [ ] Commands are tested and work
  - [ ] Examples are clear and complete
  - [ ] Links to files are relative paths

---

## Safety Verification

- [ ] **Production ready**
  - [ ] No hardcoded secrets in Jenkinsfiles
  - [ ] No hardcoded cluster names (uses Terraform outputs)
  - [ ] No hardcoded AWS account IDs (uses dynamic resolution)
  - [ ] Terraform backend encrypted (S3 encryption enabled)
  - [ ] S3 state locking enabled (DynamoDB)

- [ ] **Destruction safety**
  - [ ] Destroy is separate, manual job
  - [ ] Explicit confirmation required
  - [ ] Clear warnings before destruction
  - [ ] Confirmation string is hard to type accidentally

- [ ] **State management**
  - [ ] Terraform state in S3 (remote)
  - [ ] State file encryption enabled
  - [ ] State locking prevents concurrent changes
  - [ ] Jenkins has read/write access

- [ ] **RBAC and Auth**
  - [ ] Jenkins IAM role has minimum required permissions
  - [ ] Kubernetes RBAC configured (Jenkins user mapped)
  - [ ] No overly permissive policies

---

## Troubleshooting Readiness

- [ ] **Team trained on**
  - [ ] How to use Infrastructure-Deploy job
  - [ ] How to use Infrastructure-Destroy job
  - [ ] How to deploy apps via Git (argocd-apps/)
  - [ ] How to update apps (change image tag, commit)
  - [ ] How to troubleshoot (logs, argocd commands)
  - [ ] When to call support (external issue)

- [ ] **Runbooks documented**
  - [ ] How to deploy new application
  - [ ] How to update application
  - [ ] How to scale application
  - [ ] How to rollback deployment
  - [ ] How to destroy infrastructure
  - [ ] How to recover from failure

- [ ] **Monitoring in place**
  - [ ] Can see ArgoCD status (UI or CLI)
  - [ ] Can see pod logs (`kubectl logs`)
  - [ ] Can see cluster events (`kubectl events`)
  - [ ] Alert mechanism for failed deployments (optional)

---

## Production Readiness Final Check

- [ ] **Code review completed**
  - [ ] Jenkinsfiles reviewed by team
  - [ ] Terraform changes reviewed
  - [ ] Documentation reviewed
  - [ ] No objections or blocking issues

- [ ] **Testing completed**
  - [ ] Plan stage tested (safe preview)
  - [ ] Apply stage tested (actual provisioning)
  - [ ] App deployment tested (via Git)
  - [ ] App update tested (image tag change)
  - [ ] Self-healing tested (manual changes reverted)
  - [ ] Rollback tested (git revert)

- [ ] **Documentation complete**
  - [ ] All files exist and are accurate
  - [ ] Team can reference QUICK_START.md
  - [ ] Team trained on GitOps workflow
  - [ ] Emergency contacts documented

- [ ] **Backup and recovery**
  - [ ] Terraform state backups exist
  - [ ] S3 versioning enabled
  - [ ] DR plan documented
  - [ ] Recovery has been tested (optional)

---

## Sign-Off

- [ ] **Reviewed by:** ******\_\_\_\_****** (DevOps Lead)
- [ ] **Tested by:** ******\_\_\_\_****** (QA/Validation)
- [ ] **Approved by:** ******\_\_\_\_****** (Infrastructure Owner)
- [ ] **Date:** ******\_\_\_\_******

---

## Notes & Issues Found

```
[ Use this space to document any issues found during verification ]

Issue: ___________________________
Status: [ ] Open [ ] Fixed
Resolution: _____________________


Issue: ___________________________
Status: [ ] Open [ ] Fixed
Resolution: _____________________
```

---

## Post-Implementation Monitoring

After deploying to production, monitor:

```bash
# Daily checks
kubectl -n argocd get apps                    # All in Synced + Healthy
argocd app list                                # Same info via CLI
kubectl get nodes                              # All Ready

# Weekly reviews
terraform show                                 # State is consistent
aws eks describe-cluster ...                  # Cluster healthy
Terraform state file changes                   # Only expected changes
```

---

If all checkboxes are complete ✅, you are ready for production!
