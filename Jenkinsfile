pipeline {
  agent any

  options {
    disableConcurrentBuilds()
    buildDiscarder(logRotator(daysToKeepStr: '30', numToKeepStr: '50'))
    timeout(time: 2, unit: 'HOURS')
  }

  parameters {
    choice(
      name: 'ACTION',
      choices: ['plan', 'apply'],
      description: 'Terraform action: plan (preview) / apply (provision)'
    )
  }

  stages {

    stage('Checkout Code') {
      steps {
        git branch: 'master',
            url: 'https://github.com/Ahmedlebshten/School_Management_System_Infra'
      }
    }

    stage('Terraform Init') {
      steps {
        sh 'terraform init -reconfigure -no-color'
      }
    }

    stage('Terraform Plan') {
      steps {
        sh 'terraform plan -out=tfplan -no-color'
      }
    }

    stage('Terraform Apply') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        sh 'terraform apply -auto-approve tfplan'
      }
    }

    stage('Bootstrap ArgoCD') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        sh '''
          aws eks update-kubeconfig \
            --region us-east-1 \
            --name $(terraform output -raw eks_cluster_name)

          kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
          kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
          kubectl -n argocd wait --for=condition=Available deployment/argocd-server --timeout=300s
        '''
      }
    }

    stage('Create ArgoCD Root Application') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        sh '''
          kubectl apply -f argocd-apps/root-app.yaml
        '''
      }
    }
  }

  post {
    always {
      script {
        if (fileExists('tfplan')) {
          sh 'rm -f tfplan'
        }
      }
    }
  }
}
