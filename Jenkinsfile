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
        
        
/*
        stage('Terraform Destroy') {
            steps {
                echo "🗑️ Destroying Terraform infrastructure..."
                sh 'terraform destroy -auto-approve'
                echo "✅ Infrastructure destroyed successfully!"
            }
        }
        */
        
    }

    post {
    success {
        echo "✅ Infra pipeline succeeded — triggering downstream pipelines..."

        // Trigger Install-ArgoCD pipeline that install ArgoCD on EKS cluster
        build job: 'Install-ArgoCD', wait: false, propagate: false

        // delay before triggering CD-Create-ArgoCD-Application pipeline
        echo "⏳ Waiting 20 seconds before triggering CD-Create-ArgoCD-Application pipeline..."
        sh "sleep 20"

        // Trigger CD-Create-ArgoCD-Application pipeline 
        build job: 'CD-Create-ArgoCD-Application', wait: false, propagate: false

        // Trigger monitoring pipeline  
        build job: 'CD-Create-Monitoring-Application', wait: false, propagate: false

        // Trigger security-tools pipeline  
        build job: 'Security-Tools-Create-Application', wait: false, propagate: false

        echo "✅ Downstream CD pipelines triggered successfully!"
    }

    failure {
        echo "❌ Infra pipeline failed — skipping downstream pipelines."
   }
}
}
