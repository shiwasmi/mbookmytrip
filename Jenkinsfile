pipeline {
    agent any
    triggers {
        githubPush()
    }
    environment {
        AWS_ACCOUNT_ID = "251335054837"
        REGION = "ap-south-1"
        ECR_URL = "${AWS_ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"
        BRANCH_NAME = "${env.BRANCH_NAME}"
        BUILD_NUMBER = "${env.BUILD_NUMBER}"
        IMAGE_TAG = "${BRANCH_NAME}-mbookmytrip-v1.${BUILD_NUMBER}"
        IMAGE_TAG = "${BRANCH_NAME}-mbookmytrip-v1.${BUILD_NUMBER}"
        DEV_IMAGE_TAG = "dev-mbookmytrip-v1.${BUILD_NUMBER}"
        TEST_IMAGE_TAG = "test-mbookmytrip-v1.${BUILD_NUMBER}"
        STAGE_IMAGE_TAG = "stage-mbookmytrip-v1.${BUILD_NUMBER}"
        PROD_IMAGE_TAG = "prod-mbookmytrip-v1.${BUILD_NUMBER}"
    }
    options {
        buildDiscarder(logRotator(numToKeepStr: '5', artifactNumToKeepStr: '5'))
    }
    tools {
        maven 'mvn_3.9.9'
    }

    stages {
        stage('Code Compilation') {
            when { branch 'dev' }
            steps {
                echo 'Code Compilation in Progress!'
                sh 'mvn clean compile'
                echo 'Code Compilation Completed!'
            }
        }

        stage('Code QA Execution') {
            steps {
                echo 'JUnit Test Execution in Progress!'
                sh 'mvn clean test'
                echo 'JUnit Test Execution Completed!'
            }
        }

        stage('Code Package') {
            steps {
                echo 'Packaging Code into WAR Artifact'
                sh 'mvn clean package'
                echo 'WAR Artifact Created Successfully!'
            }
        }

        stage('Build & Tag Docker Image') {
            steps {
                echo "Building Docker Image: ${ECR_URL}/mbookmytrip:${DEV_IMAGE_TAG}"
                sh "docker build -t ${ECR_URL}/mbookmytrip:${DEV_IMAGE_TAG} ."
                echo 'Docker Image Built Successfully!'
            }
        }

        stage('Push Docker Image to Amazon ECR') {
            steps {
                echo "Pushing Docker Image to ECR: ${ECR_URL}/mbookmytrip:${DEV_IMAGE_TAG}"
                withDockerRegistry([credentialsId: 'ecr-ap-south-1-ecr-credentials', url: "https://${ECR_URL}"]) {
                    sh "docker push ${ECR_URL}/mbookmytrip:${DEV_IMAGE_TAG}"
                }
                echo "Docker Image Pushed to ECR Successfully!"
            }
        }

        stage('Cleanup Local Docker Images') {
            steps {
                echo "Cleaning up local Docker images"
                sh """
                    docker rmi ${ECR_URL}/mbookmytrip:${DEV_IMAGE_TAG} || true
                    docker image prune -f
                """
                echo "Local Docker images cleaned up successfully"
            }
        }

        stage('Tag Docker Image for Stage and Prod') {
            when {
                anyOf {
                    branch 'Stage'
                    branch 'prod'
                }
            }
            steps {
                script {
                    def targetTag = BRANCH_NAME == 'prod' ? PROD_IMAGE_TAG : STAGE_IMAGE_TAG
                    def sourceTag = BRANCH_NAME == 'stage' ? DEV_IMAGE_TAG : STAGE_IMAGE_TAG
                    def sourceImage = "${ECR_URL}/mbookmytrip:${sourceTag}"
                    def targetImage = "${ECR_URL}/mbookmytrip:${targetTag}"

                    echo "Pulling Source Image: ${sourceImage}"

                    withDockerRegistry([credentialsId: 'ecr-ap-south-1-ecr-credentials', url: "https://${ECR_URL}"]) {
                        def pullStatus = sh(script: "docker pull ${sourceImage}", returnStatus: true)
                        if (pullStatus != 0) {
                            error("Source image ${sourceImage} does not exist or failed to pull.")
                        }
                    }

                    echo "Tagging Source Image as Target: ${targetImage}"
                    sh "docker tag ${sourceImage} ${targetImage}"
                    echo "Pushing Target Image to ECR: ${targetImage}"
                    sh "docker push ${targetImage}"
                    echo "Cleaning Up Local Images"
                    sh "docker rmi ${sourceImage} ${targetImage}"
                }
            }
        }

        stage('Deploy app to dev env') {
            when { branch 'dev' }
            steps {
                script {
                    echo "Deploying to Dev Environment"
                    def yamlFile = 'kubernetes/dev/05-deployment.yaml'

                    sh """
                    sed -i 's|<latest>|${DEV_IMAGE_TAG}|g' ${yamlFile}
                    cat ${yamlFile} | grep ${DEV_IMAGE_TAG} || echo "Replacement failed in ${yamlFile}"
                    """

                    sh """
                    kubectl --kubeconfig=/var/lib/jenkins/.kube/config apply -f kubernetes/dev/
                    """

                    def configMapChanged = sh(script: "git diff --name-only HEAD~1 | grep -q 'kubernetes/dev/06-configmap.yaml'", returnStatus: true)
                    if (configMapChanged == 0) {
                        echo "ConfigMap changed, restarting pods"
                        sh "kubectl --kubeconfig=/var/lib/jenkins/.kube/config rollout restart deployment dev-mbookmytrip"
                    }
                }
            }
        }

        stage('Deploy app to test env') {
            when { branch 'test' }
            steps {
                script {
                    echo "Deploying to Test Environment"
                    def yamlFile = 'kubernetes/dev/05-deployment.yaml'

                    sh """
                    sed -i 's|<latest>|${TEST_IMAGE_TAG}|g' ${yamlFile}
                    cat ${yamlFile} | grep ${TEST_IMAGE_TAG} || echo "Replacement failed in ${yamlFile}"
                    """

                    sh """
                    kubectl --kubeconfig=/var/lib/jenkins/.kube/config apply -f kubernetes/test/
                    """

                    def configMapChanged = sh(script: "git diff --name-only HEAD~1 | grep -q 'kubernetes/test/06-configmap.yaml'", returnStatus: true)
                    if (configMapChanged == 0) {
                        echo "ConfigMap changed, restarting pods"
                        sh "kubectl --kubeconfig=/var/lib/jenkins/.kube/config rollout restart deployment test-mbookmytrip"
                    }
                }
            }
        }
        stage('Deploy app to stage env') {
            when { branch 'stage' }
            steps {
                script {
                    echo "Deploying to Stage Environment"
                    def yamlFile = 'kubernetes/stage/05-deployment.yaml'

                    sh """
                    sed -i 's|<latest>|${STAGE_IMAGE_TAG}|g' ${yamlFile}
                    cat ${yamlFile} | grep ${STAGE_IMAGE_TAG} || echo "Replacement failed in ${yamlFile}"
                    """

                    sh """
                    kubectl --kubeconfig=/var/lib/jenkins/.kube/config apply -f kubernetes/stage/
                    """
                }
            }
        }

        stage('Deploy app to prod env') {
            when { branch 'prod' }
            steps {
                script {
                    echo "Deploying to Prod Environment"
                    def yamlFile = 'kubernetes/prod/05-deployment.yaml'

                    sh """
                    sed -i 's|<latest>|${PROD_IMAGE_TAG}|g' ${yamlFile}
                    cat ${yamlFile} | grep ${PROD_IMAGE_TAG} || echo "Replacement failed in ${yamlFile}"
                    """

                    sh """
                    kubectl --kubeconfig=/var/lib/jenkins/.kube/config apply -f kubernetes/prod/
                    """
                }
            }
        }
    }

    post {
        success {
            echo "Deployment to ${env.BRANCH_NAME} environment completed successfully"
        }
        failure {
            echo "Deployment to ${env.BRANCH_NAME} environment failed. Check logs for details."
        }
    }
}
