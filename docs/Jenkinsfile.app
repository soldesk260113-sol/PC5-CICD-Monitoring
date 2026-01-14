pipeline {
    agent any
    
    environment {
        REGISTRY = 'registry.local'
        IMAGE_NAME = 'myapp'
        K8S_NAMESPACE = 'production'
        GIT_REPO = 'http://10.2.2.40:3001/admin/myapp.git'
    }

    stages {
        stage('Checkout') {
            steps {
                echo "📥 소스 코드 체크아웃 중..."
                git branch: 'main',
                    url: "${GIT_REPO}",
                    credentialsId: 'gitea-auth'
            }
        }
        
        stage('Build & Test') {
            steps {
                echo "🔨 애플리케이션 빌드 및 테스트 중..."
                script {
                    // Node.js 예시
                    sh '''
                        npm install
                        npm run lint
                        npm test
                    '''
                    
                    // 또는 Go 예시
                    // sh 'go build -v ./...'
                    // sh 'go test -v ./...'
                    
                    // 또는 Python 예시
                    // sh 'pip install -r requirements.txt'
                    // sh 'pytest tests/'
                }
            }
        }
        
        stage('Docker Build') {
            steps {
                echo "🐳 Docker 이미지 빌드 중..."
                sh """
                    docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} .
                    docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${IMAGE_NAME}:latest
                """
            }
        }
        
        stage('Image Scan') {
            steps {
                echo "🔍 이미지 보안 스캔 중..."
                script {
                    try {
                        sh "trivy image --severity HIGH,CRITICAL ${IMAGE_NAME}:${BUILD_NUMBER}"
                    } catch (Exception e) {
                        echo "⚠️  경고: 이미지 스캔에서 취약점 발견"
                        // Critical 취약점이 있으면 중단하려면 throw e
                    }
                }
            }
        }
        
        stage('Push to Registry') {
            steps {
                echo "📦 Docker Registry에 이미지 푸시 중..."
                withCredentials([usernamePassword(
                    credentialsId: 'harbor-auth',
                    usernameVariable: 'REGISTRY_USER',
                    passwordVariable: 'REGISTRY_PASS'
                )]) {
                    sh """
                        docker login ${REGISTRY} -u \${REGISTRY_USER} -p \${REGISTRY_PASS}
                        docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}
                        docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${REGISTRY}/${IMAGE_NAME}:latest
                        docker push ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}
                        docker push ${REGISTRY}/${IMAGE_NAME}:latest
                    """
                }
            }
        }
        
        stage('Update K8s Manifest') {
            steps {
                echo "📝 Kubernetes Manifest 업데이트 중..."
                sh """
                    sed -i 's|image: .*|image: ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}|g' k8s_manifests/deployment.yaml
                    cat k8s_manifests/deployment.yaml
                """
            }
        }
        
        stage('Deploy to K8s') {
            input {
                message "Kubernetes에 배포하시겠습니까?"
                ok "배포 시작"
            }
            steps {
                echo "🚀 Kubernetes 배포 중..."
                sh """
                    kubectl set image deployment/${IMAGE_NAME} \
                        ${IMAGE_NAME}=${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER} \
                        -n ${K8S_NAMESPACE}
                    
                    echo "⏳ 롤아웃 상태 확인 중..."
                    kubectl rollout status deployment/${IMAGE_NAME} -n ${K8S_NAMESPACE} --timeout=5m
                """
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo "✅ 배포 검증 중..."
                sh """
                    kubectl get pods -n ${K8S_NAMESPACE} -l app=${IMAGE_NAME}
                    kubectl get svc -n ${K8S_NAMESPACE} -l app=${IMAGE_NAME}
                """
                
                script {
                    // Health Check
                    try {
                        sh """
                            sleep 10
                            curl -f http://10.2.2.100/api/health || exit 1
                        """
                        echo "✅ Health Check 성공!"
                    } catch (Exception e) {
                        echo "❌ Health Check 실패!"
                        throw e
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo "✅ 배포 성공!"
            echo "이미지: ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}"
            echo "배포 시각: ${new Date()}"
        }
        failure {
            echo "❌ 배포 실패!"
            echo "롤백 중..."
            sh """
                kubectl rollout undo deployment/${IMAGE_NAME} -n ${K8S_NAMESPACE} || true
            """
        }
        always {
            echo "🧹 정리 작업 중..."
            sh """
                docker rmi ${IMAGE_NAME}:${BUILD_NUMBER} || true
                docker rmi ${IMAGE_NAME}:latest || true
            """
        }
    }
}
