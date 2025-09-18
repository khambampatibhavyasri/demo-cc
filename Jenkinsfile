pipeline {
    agent any

    environment {
        PROJECT_ID = 'your-project-id'
        REPOSITORY = 'campusconnect-repo'
        LOCATION = 'us-central1'
        IMAGE_NAME = 'campusconnect'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Test') {
            steps {
                script {
                    // Run tests for your application
                    sh 'npm ci'
                    sh 'npm test'
                }
            }
        }

        stage('Build Docker Image') {
            when {
                branch 'main'
            }
            steps {
                script {
                    def imageTag = "${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${BUILD_NUMBER}"
                    sh "docker build -t ${imageTag} ."
                }
            }
        }

        stage('Push to Artifact Registry') {
            when {
                branch 'main'
            }
            steps {
                script {
                    def imageTag = "${LOCATION}-docker.pkg.dev/${PROJECT_ID}/${REPOSITORY}/${IMAGE_NAME}:${BUILD_NUMBER}"
                    sh "docker push ${imageTag}"
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}