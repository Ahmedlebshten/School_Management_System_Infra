/*
================================================================================
  INFRASTRUCTURE PIPELINE - School Management System
================================================================================

PHILOSOPHY: This pipeline ONLY bootstraps the Kubernetes cluster and ArgoCD.
It does NOT deploy applications. CD is handled by GitOps (ArgoCD).

RESPONSIBILITIES:
  ✅ Provision AWS infrastructure (VPC, EKS, IAM, Security Groups)
  ✅ Bootstrap Kubernetes cluster
  ✅ Install ArgoCD for GitOps deployments
  ✅ Create root ArgoCD Application (App of Apps pattern)
  ✅ STOP — Applications are deployed by ArgoCD watching Git repos

WHAT THIS DOES NOT DO:
  ❌ Does NOT deploy applications
  ❌ Does NOT trigger CI pipelines
  ❌ Does NOT trigger CD pipelines
  ❌ Does NOT destroy infrastructure (separate manual job)

TRIGGER:
  Manual trigger ONLY

NEXT STEPS FOR AUTOMATION:
  1. CI Pipeline: Auto-triggered by GitHub webhook on code push
  2. ArgoCD: Auto-syncs applications when Git repos change
  3. No manual steps needed after this pipeline runs

================================================================================
*/

pipeline {
    agent any

    options {
        // Prevent concurrent builds to avoid state lock contention
        disableConcurrentBuilds()
        // Keep build logs for 30 days
        buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '50'))
        // Timeout after 2 hours
        timeout(time: 2, unit: 'HOURS')
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['plan', 'apply'],
            description: 'Terraform action: "plan" (preview), "apply" (provision)'
        )
    }

    stages {
        /*
        ========================================================================
        STAGE 1: CHECKOUT CODE FROM REPOSITORY
        ========================================================================
        Pulls the infrastructure code from the main branch.
        Ensures we always use the latest infrastructure definitions.
        */
        stage('Checkout Code') {
            steps {
                echo "📥 Checking out infrastructure code from Git repository..."
                git branch: 'master', url: 'https://github.com/Ahmedlebshten/School_Management_System_Infra'
                echo "✅ Code checked out successfully"
            }
        }

        /*
        ========================================================================
        STAGE 2: TERRAFORM INITIALIZATION
        ========================================================================
        - Initializes Terraform working directory
        - Downloads required providers (AWS, Kubernetes)
        - Configures S3 remote backend for state management
        - Ensures all dependencies are available

        Why: Terraform requires initialization before any operations.
        */
        stage('Terraform Init') {
            steps {
                echo "🔧 Initializing Terraform working directory..."
                sh '''
                    terraform init \
                        -reconfigure \
                        -no-color
                '''
                echo "✅ Terraform initialization complete"
            }
        }

        /*
        ========================================================================
        STAGE 3: TERRAFORM PLAN
        ========================================================================
        - Creates an execution plan showing what will be created/modified/destroyed
        - Validates infrastructure code syntax and logic
        - Does NOT apply changes (safe preview)
        - Saves plan to file for later application

        Why: Review before applying prevents mistakes in production.
        */
        stage('Terraform Plan') {
            steps {
                echo "📋 Creating Terraform execution plan..."
                sh '''
                    terraform plan \
                        -out=tfplan \
                        -no-color
                '''
                echo "✅ Terraform plan created (saved to tfplan)"
                echo ""
                echo "📌 Review the plan above carefully before approving apply!"
            }
        }

        /*
        ========================================================================
        STAGE 4: TERRAFORM APPLY (CONDITIONAL ON PARAMETER)
        ========================================================================
        - Provisions all AWS infrastructure
        - Creates VPC, EKS cluster, IAM roles, Security Groups
        - Only runs if ACTION parameter is set to 'apply'
        - Uses the pre-planned tfplan file for deterministic execution

        Why: Separation of plan/apply is a DevOps best practice.
        */
        stage('Terraform Apply') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "🚀 Applying Terraform plan (provisioning AWS infrastructure)..."
                sh '''
                    terraform apply \
                        -no-color \
                        -auto-approve \
                        tfplan
                '''
                echo "✅ Infrastructure provisioned successfully"
            }
        }

        /*
        ========================================================================
        STAGE 5: BOOTSTRAP ARGOCD
        ========================================================================
        - Fetches EKS cluster details from Terraform outputs
        - Updates kubeconfig to access the newly created cluster
        - Maps Jenkins IAM role to Kubernetes RBAC
        - Installs ArgoCD using official manifests
        - Waits for ArgoCD server to be ready before proceeding
        - Creates root Application (App of Apps) for automatic deployments

        Why: This enables GitOps-based CD. No Jenkins needs to touch app deployments.

        ArgoCD will:
          1. Watch Git repositories for application manifests
          2. Automatically sync applications when code is pushed
          3. Manage all deployments without Jenkins involvement
        */
        stage('Bootstrap ArgoCD') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "⚙️ Bootstrapping ArgoCD for GitOps-based CD..."
                sh '''
                    set -e

                    # Get cluster details from Terraform outputs
                    CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
                    AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
                    JENKINS_ROLE_ARN="arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/Jenkins-EC2-Role"

                    echo "📌 Cluster Name: $CLUSTER_NAME"
                    echo "📌 AWS Region: $AWS_REGION"
                    echo "📌 Jenkins Role ARN: $JENKINS_ROLE_ARN"

                    # Update kubeconfig to access the EKS cluster
                    echo "🔐 Updating kubeconfig..."
                    aws eks update-kubeconfig \
                        --region $AWS_REGION \
                        --name $CLUSTER_NAME

                    # Map Jenkins EC2 IAM role to Kubernetes RBAC
                    # This allows Jenkins to interact with the cluster
                    echo "🔑 Mapping Jenkins IAM role to Kubernetes RBAC..."
                    eksctl create iamidentitymapping \
                        --region $AWS_REGION \
                        --cluster $CLUSTER_NAME \
                        --arn $JENKINS_ROLE_ARN \
                        --username jenkins-ec2-role \
                        --group system:masters || echo "⚠️  IAM mapping may already exist, continuing..."

                    # Create argocd namespace
                    echo "📦 Creating ArgoCD namespace..."
                    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

                    # Install ArgoCD using official manifests
                    echo "🎯 Installing ArgoCD from official repository..."
                    kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

                    # Wait for ArgoCD server deployment to be ready
                    echo "⏳ Waiting for ArgoCD server to become ready (max 5 minutes)..."
                    kubectl -n argocd wait --for=condition=Available deployment/argocd-server --timeout=300s

                    echo "✅ ArgoCD installed and ready!"
                    
                    # Display ArgoCD access information
                    echo ""
                    echo "===================================================================="
                    echo "🎉 ARGOCD BOOTSTRAP COMPLETE"
                    echo "===================================================================="
                    echo "To access ArgoCD UI:"
                    echo "  kubectl -n argocd port-forward svc/argocd-server 9090:443"
                    echo "  Then open: https://localhost:9090"
                    echo ""
                    echo "Default password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
                    echo "===================================================================="
                '''
            }
        }

        /*
        ========================================================================
        STAGE 6: CREATE ROOT ARGOCD APPLICATION (App of Apps Pattern)
        ========================================================================
        - Creates the main ArgoCD Application that points to Git repo
        - This is the "App of Apps" pattern for managing all deployments
        - ArgoCD will continuously watch this repo and sync all applications
        - When you push manifests to Git, ArgoCD automatically deploys them

        Why: This enables true GitOps. Add apps by pushing YAML files to Git, not
        by running Jenkins pipelines. Kubernetes becomes the source of truth.
        */
        stage('Create ArgoCD Root Application') {
            when {
                expression { params.ACTION == 'apply' }
            }
            steps {
                echo "🌳 Creating ArgoCD root application (App of Apps pattern)..."
                sh '''
                    set -e

                    CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
                    AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")

                    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

                    echo "📝 Creating root ArgoCD Application..."
                    kubectl apply -f - <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
    # Replace with your actual GitOps repository
    repoURL: https://github.com/Ahmedlebshten/School_Management_System_Infra.git
    targetRevision: master
    path: argocd-apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

                    echo "✅ Root ArgoCD Application created successfully!"
                    echo ""
                    echo "📌 NOTE: This root app points to 'argocd-apps' path in Git."
                    echo "    To add more apps, push YAML files to that directory."
                    echo "    ArgoCD will automatically detect and deploy them!"
                '''
            }
        }

    }

    post {
        success {
            echo ""
            echo "✅ ✅ ✅ INFRASTRUCTURE PIPELINE COMPLETED SUCCESSFULLY ✅ ✅ ✅"
            echo ""
            echo "===================================================================="
            echo "NEXT STEPS - Automated by GitOps:"
            echo "===================================================================="
            echo ""
            echo "1️⃣  CI PIPELINE (Automatic):"
            echo "    • GitHub webhook auto-triggers when code is pushed"
            echo "    • Builds Docker image and pushes to registry"
            echo "    • No Jenkins involvement needed (Docker build handles it)"
            echo ""
            echo "2️⃣  ARGOCD DEPLOYMENT (Automatic):"
            echo "    • ArgoCD watches Git repositories continuously"
            echo "    • When you push app manifests, ArgoCD detects the change"
            echo "    • Automatically deploys/updates applications in EKS"
            echo "    • Self-healing: if deployment drifts, ArgoCD corrects it"
            echo ""
            echo "3️⃣  NO JENKINS INVOLVED IN APP DEPLOYMENT:"
            echo "    • Jenkins only bootstrapped infrastructure"
            echo "    • All application deployments are GitOps-driven"
            echo "    • Kubernetes manifests in Git = source of truth"
            echo ""
            echo "===================================================================="
        }

        failure {
            echo ""
            echo "❌ ❌ ❌ INFRASTRUCTURE PIPELINE FAILED ❌ ❌ ❌"
            echo ""
            echo "Check the logs above for details."
            echo "Terraform state may be locked - see error messages."
            echo ""
            echo "IMPORTANT: This pipeline does NOT trigger any downstream jobs."
            echo "Fix the infrastructure issues and try again."
        }

        always {
            // Clean up plan file to avoid large artifacts
            sh 'rm -f tfplan'
        }
    }
}
