/*
================================================================================
  INFRASTRUCTURE PIPELINE - School Management System
================================================================================
*/

pipeline {
  agent {
    docker {
      image 'ghcr.io/antonbabenko/terraform-aws-cli:latest'
      args '-u root'
    }
  }

  options {
    disableConcurrentBuilds()
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '50'))
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

    /* ================= INSTALL REQUIRED TOOLS ================= */
    stage('Install Kubernetes Tools') {
      steps {
        sh '''
          set -e
          echo "🔧 Installing kubectl & eksctl..."

          curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
          chmod +x kubectl
          mv kubectl /usr/local/bin/

          curl -sL https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz | tar xz
          mv eksctl /usr/local/bin/

          kubectl version --client
          eksctl version
        '''
      }
    }

    /* ================= CHECKOUT ================= */
    stage('Checkout Code') {
      steps {
        echo "📥 Checking out infrastructure code from Git repository..."
        git branch: 'master', url: 'https://github.com/Ahmedlebshten/School_Management_System_Infra'
        echo "✅ Code checked out successfully"
      }
    }

    /* ================= TERRAFORM INIT ================= */
    stage('Terraform Init') {
      steps {
        sh 'terraform init -reconfigure -no-color'
      }
    }

    /* ================= TERRAFORM PLAN ================= */
    stage('Terraform Plan') {
      steps {
        sh 'terraform plan -out=tfplan -no-color'
      }
    }

    /* ================= TERRAFORM APPLY ================= */
    stage('Terraform Apply') {
      when { expression { params.ACTION == 'apply' } }
      steps {
        sh 'terraform apply -auto-approve -no-color tfplan'
      }
    }

    /* ================= BOOTSTRAP ARGOCD ================= */
    stage('Bootstrap ArgoCD') {
      when { expression { params.ACTION == 'apply' } }
      steps {
        sh '''
          set -e
          CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
          AWS_REGION=$(terraform output -raw aws_region)

          aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

          eksctl create iamidentitymapping \
            --region $AWS_REGION \
            --cluster $CLUSTER_NAME \
            --arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/Jenkins-EC2-Role \
            --username jenkins \
            --group system:masters || true

          kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
          kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
          kubectl -n argocd wait --for=condition=Available deployment/argocd-server --timeout=300s
        '''
      }
    }

    /* ================= ROOT APP ================= */
    stage('Create ArgoCD Root Application') {
      when { expression { params.ACTION == 'apply' } }
      steps {
        sh '''
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
spec:
  project: default
  source:
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
EOF
'''
      }
    }
  }

  post {
    always {
      sh 'rm -f tfplan'
    }
  }
}
