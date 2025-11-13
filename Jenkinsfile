pipeline {
    agent any

    environment {
        AWS_ACCESS_KEY_ID     = credentials('aws-access-key')
        AWS_SECRET_ACCESS_KEY = credentials('aws-secret-key')
    }

    stages {

        stage('Checkout Code') {
            steps {
                echo "🔹 Checking out repository..."
                git branch: 'master', url: 'https://github.com/Ahmedlebshten/Jenkins-Pipeline-Project'
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
                echo "🔹 Applying Terraform plan..."
              //  sh 'terraform apply -auto-approve tfplan'
                sh 'terraform destroy -auto-approve tfplan'
                echo "✅ Terraform infrastructure deployed successfully!"
            }
        }
    }

    post {
        success {
            echo "🎉 Pipeline executed successfully! Infrastructure is ready."
        }
        failure {
            echo "❌ Pipeline failed. Please check the console output for details."
        }
    }
}
