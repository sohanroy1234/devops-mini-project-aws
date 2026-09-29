// CI/CD: GitHub -> Jenkins -> test -> Docker build -> Amazon ECR -> ECS Fargate (behind an ALB)
// Jenkins runs on EC2 with an IAM instance profile, so no AWS keys are needed in Jenkins.

pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '15'))
    }

    // Poll GitHub every ~2 min. (Replace with a webhook + "GitHub hook trigger" if Jenkins is reachable.)
    triggers { pollSCM('H/2 * * * *') }

    environment {
        AWS_REGION      = 'ap-south-1'                  // must match terraform var.aws_region
        AWS_DEFAULT_REGION = 'ap-south-1'
        APP_NAME        = 'devops-mini-project'         // must match terraform var.project_name
        ECR_REPO        = 'devops-mini-project'
        ECS_CLUSTER     = 'devops-mini-project-cluster'
        ECS_SERVICE     = 'devops-mini-project'
        TASK_FAMILY     = 'devops-mini-project'
        ALB_NAME        = 'devops-mini-project-alb'
        DESIRED_COUNT   = '2'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
                script {
                    def sha = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    env.IMAGE_TAG   = "${env.BUILD_NUMBER}-${sha}"
                    env.APP_VERSION = env.IMAGE_TAG
                }
                echo "Building ${env.IMAGE_TAG}"
            }
        }

        stage('Install & Test') {
            steps {
                dir('app') {
                    sh 'node --version && npm --version'
                    sh 'npm ci'
                    sh 'npm test -- --ci'
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'app/coverage/junit.xml'
                }
            }
        }

        stage('AWS Identity') {
            steps {
                script {
                    env.AWS_ACCOUNT_ID = sh(
                        script: 'aws sts get-caller-identity --query Account --output text',
                        returnStdout: true).trim()
                    env.ECR_REGISTRY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                    env.IMAGE_URI    = "${env.ECR_REGISTRY}/${env.ECR_REPO}:${env.IMAGE_TAG}"
                }
                echo "Deploying to account ${env.AWS_ACCOUNT_ID} in ${env.AWS_REGION}"
            }
        }

        stage('Docker Build') {
            steps {
                sh '''
                    docker build \
                      --build-arg APP_VERSION="$APP_VERSION" \
                      -t "$IMAGE_URI" \
                      -t "$ECR_REGISTRY/$ECR_REPO:latest" \
                      .
                '''
            }
        }

        stage('Push to ECR') {
            when { expression { env.GIT_BRANCH ==~ /(origin\/)?main/ } }
            steps {
                sh '''
                    aws ecr get-login-password --region "$AWS_REGION" \
                      | docker login --username AWS --password-stdin "$ECR_REGISTRY"
                    docker push "$IMAGE_URI"
                    docker push "$ECR_REGISTRY/$ECR_REPO:latest"
                '''
            }
            post {
                always { sh 'docker logout "$ECR_REGISTRY" || true' }
            }
        }

        stage('Deploy to ECS Fargate') {
            when { expression { env.GIT_BRANCH ==~ /(origin\/)?main/ } }
            steps {
                sh './scripts/deploy-ecs.sh'
            }
        }

        stage('Smoke Test') {
            when { expression { env.GIT_BRANCH ==~ /(origin\/)?main/ } }
            steps {
                script {
                    def albDns = sh(
                        script: '''aws elbv2 describe-load-balancers --names "$ALB_NAME" \
                                     --region "$AWS_REGION" --query 'LoadBalancers[0].DNSName' --output text''',
                        returnStdout: true).trim()
                    env.APP_URL = "http://${albDns}"
                }
                sh './scripts/smoke-test.sh "$APP_URL" "$APP_VERSION"'
                echo "App is live at ${env.APP_URL}"
            }
        }
    }

    post {
        success { echo "PIPELINE PASSED - ${env.IMAGE_TAG} deployed${env.APP_URL ? ' at ' + env.APP_URL : ''}" }
        failure { echo 'PIPELINE FAILED - check the console output above (ECS auto-rolls back bad deploys)' }
        always {
            sh 'docker image prune -f || true'
            cleanWs()
        }
    }
}
