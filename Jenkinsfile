pipeline {
    agent any

    environment {
        PROJECT_ID = 'campusconnect-project-12345'
        REPOSITORY = 'campusconnect-repo'
        LOCATION = 'us-central1'
        IMAGE_NAME = 'campusconnect'
        NODEJS_HOME = tool 'NodeJS-18'
        PATH = "${env.NODEJS_HOME}/bin:${env.PATH}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                echo "✅ Code checked out successfully"
            }
        }

        stage('Frontend Tests') {
            steps {
                dir('cc') {
                    echo "🧪 Running Frontend Tests..."
                    bat 'npm ci'
                    bat 'npm test -- --coverage --watchAll=false --testResultsProcessor=jest-junit'
                }
            }
            post {
                always {
                    publishTestResults testResultsPattern: 'cc/junit.xml'
                    publishHTML([
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'cc/coverage/lcov-report',
                        reportFiles: 'index.html',
                        reportName: 'Frontend Coverage Report'
                    ])
                }
            }
        }

        stage('Backend Tests') {
            steps {
                dir('server') {
                    echo "🧪 Running Backend Tests..."
                    bat 'npm install'
                    bat 'npm test'
                }
            }
        }

        stage('Build Docker Image') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "🐳 Building Docker Image..."
                    def imageTag = "${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${BUILD_NUMBER}"
                    bat "docker build -t ${imageTag} ."
                    env.IMAGE_TAG = imageTag
                }
            }
        }

        stage('Push to Artifact Registry') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "📦 Pushing to Artifact Registry..."
                    withCredentials([file(credentialsId: 'gcp-service-account-key', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                        bat """
                            gcloud auth activate-service-account --key-file=%GOOGLE_APPLICATION_CREDENTIALS%
                            gcloud auth configure-docker ${LOCATION}-docker.pkg.dev
                            docker push ${env.IMAGE_TAG}
                        """
                    }
                }
            }
        }

        stage('Deploy to GKE') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "🚀 Deploying to GKE..."
                    withCredentials([file(credentialsId: 'gcp-service-account-key', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                        bat """
                            gcloud auth activate-service-account --key-file=%GOOGLE_APPLICATION_CREDENTIALS%
                            gcloud container clusters get-credentials campusconnect-cluster --zone=us-central1-a --project=${PROJECT_ID}

                            REM Update deployment with new image
                            powershell -c "(Get-Content k8s-deployment.yaml) -replace 'us-central1-docker.pkg.dev/campusconnect-project-12345/campusconnect-repo/campusconnect:latest', '${env.IMAGE_TAG}' | Set-Content k8s-deployment-updated.yaml"

                            kubectl apply -f k8s-deployment-updated.yaml
                            kubectl rollout status deployment/campusconnect-deployment
                            kubectl get services
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            echo "🧹 Cleaning up workspace..."
            cleanWs()
        }
        success {
            echo "✅ Pipeline completed successfully!"
            emailext (
                subject: "✅ Build Success: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "Build completed successfully!\n\nBuild URL: ${env.BUILD_URL}",
                to: "${env.DEFAULT_RECIPIENTS}"
            )
        }
        failure {
            echo "❌ Pipeline failed!"
            emailext (
                subject: "❌ Build Failed: ${env.JOB_NAME} - ${env.BUILD_NUMBER}",
                body: "Build failed. Please check the console output.\n\nBuild URL: ${env.BUILD_URL}",
                to: "${env.DEFAULT_RECIPIENTS}"
            )
        }
    }
}