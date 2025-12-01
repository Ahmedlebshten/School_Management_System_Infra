pipeline {
    agent any

    stages {

        stage('Checkout Code') {
            steps {
                echo "🔹 Checking out repository..."
                git branch: 'master', url: 'https://github.com/Ahmedlebshten/Jenkins-Pipeline-Build-Infra'
            }
        }

        stage('Terraform Init') {
            steps {
                echo "🔹 Initializing Terraform..."
                sh 'terraform init -reconfigure'
            }
        }

        stage('Terraform Plan') {
            steps {
                echo "🔹 Creating Terraform plan..."
                sh 'terraform plan -out=tfplan'
            }
        }

        
        stage('Terraform Apply') {
            steps {
                echo "🔹 Applying Terraform..."
                sh 'terraform apply -auto-approve tfplan'
                echo "✅ Infrastructure deployed successfully!"
            }
        }

        stage('Create ArgoCD Application') {
            steps {
                sh '''
                  set -e

                  export AWS_REGION=us-east-1
                  export CLUSTER_NAME=hello-devops-production-cluster

                  echo "🔹 Updating kubeconfig..."
                  aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

                  echo "🔹 Creating ArgoCD Application..."

                  kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: url-shortener
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/Ahmedlebshten/ArgoCD-Pipeline.git
    targetRevision: HEAD
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
EOF

                  echo "🎉 ArgoCD Application Created Successfully!"
                '''
            }
        }
        
/*
        stage('Terraform Destroy') {
            steps {
                echo "🗑️ Destroying Terraform infrastructure..."
                sh 'terraform destroy -auto-approve'
                echo "🔥 Infrastructure destroyed successfully!"
            }
        }
        */
    }

    post {
        success {
            echo "🎉 Pipeline completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed!"
        }
    }
}
