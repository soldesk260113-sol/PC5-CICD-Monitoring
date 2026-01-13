# Antigravity CI/CD Pipeline

## 📋 Overview

완전 자동화된 CI/CD 파이프라인으로 코드 푸시부터 Kubernetes 배포까지 자동으로 처리합니다.

## 🔄 CI/CD Flow

```
[Developer]
    ↓ git push
[Gitea] (10.2.2.40:3001)
    ↓ Mirror (자동)
[GitHub]
    ↓ Webhook
[Jenkins] (10.2.2.40:8080)
    ↓ Pipeline
[1] Docker Build
    ↓
[2] Harbor Push (10.2.2.40:5000)
    ↓
[3] Helm Chart Update
    ↓ git push
[Gitea/GitHub]
    ↓
[ArgoCD] (자동 감지)
    ↓
[Kubernetes Cluster]
```

## 🛠️ Infrastructure Components

### CI/CD Server (CI-OPS: 10.2.2.40)
- **Jenkins**: CI/CD 오케스트레이션
- **Gitea**: 내부 Git 저장소 (GitHub 미러링)
- **Harbor**: Docker Registry (이미지 저장소)

### Kubernetes Cluster
- **Control Plane**: 3대 (HA 구성)
- **Worker Nodes**: 6대
- **ArgoCD**: GitOps 배포 자동화

## 📦 Pipeline Stages

### Stage 1: Checkout
- Gitea에서 소스 코드 가져오기
- 브랜치: `main`

### Stage 2: Build & Test
- 애플리케이션 빌드
- 단위 테스트 실행
- 린트 검사

### Stage 3: Docker Build
- Dockerfile 기반 이미지 빌드
- 이미지 태그: `BUILD_NUMBER`, `latest`

### Stage 4: Image Scan
- Trivy로 보안 취약점 스캔
- HIGH/CRITICAL 취약점 검사

### Stage 5: Push to Harbor
- Harbor Registry에 이미지 푸시
- 태그: `10.2.2.40:5000/myapp:BUILD_NUMBER`

### Stage 6: Update Helm Chart
- Helm Chart values.yaml 업데이트
- 새 이미지 태그 반영
- Git Push (Gitea → GitHub)

### Stage 7: ArgoCD Sync
- ArgoCD가 Git 변경사항 자동 감지
- Kubernetes에 자동 배포

### Stage 8: Verify Deployment
- Pod 상태 확인
- Health Check 실행
- 배포 검증

## 🚀 Quick Start

### 1. Harbor 설치
```bash
cd /root/Antigravity/Ansible
ansible-playbook playbooks/06_deploy_registry.yml
```

### 2. Harbor 프로젝트 생성
- URL: http://10.2.2.40:5000
- Login: admin / HarborAdmin123
- Projects → New Project → `library`

### 3. Jenkins Credentials 추가
```
Jenkins → Credentials → Add:
- ID: harbor-auth
- Username: admin
- Password: HarborAdmin123
```

### 4. Gitea 저장소 생성
```bash
# Gitea에서 myapp 저장소 생성
cd /root/Antigravity/Ansible/myapp
git init
git add .
git commit -m "Initial commit"
git remote add origin http://10.2.2.40:3001/admin/myapp.git
git push -u origin main
```

### 5. GitHub 미러링 설정
```
Gitea → Settings → Repository → Mirroring
- Git Remote Repository URL: https://github.com/your-org/myapp.git
- Direction: Push
- Sync on commit: ✓
```

### 6. GitHub Webhook 설정
```
GitHub → Settings → Webhooks → Add webhook
- Payload URL: http://10.2.2.40:8080/github-webhook/
- Content type: application/json
- Events: Just the push event
```

### 7. Jenkins Pipeline 생성
```
Jenkins → New Item → myapp-pipeline
- Type: Pipeline
- SCM: Git
- Repository: http://10.2.2.40:3001/admin/myapp.git
- Script Path: Jenkinsfile
```

### 8. ArgoCD 설치
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 9. ArgoCD Application 생성
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/helm-charts
    targetRevision: HEAD
    path: myapp
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 📝 Files

### Essential Files
- `Jenkinsfile.app` - Application CI/CD pipeline
- `distribute_jenkins_key.yml` - Jenkins SSH key distribution
- `docs/` - Documentation
- `ops_playbooks/` - Operational playbooks
- `scripts/` - Utility scripts

## 🔧 Configuration

### Jenkinsfile Environment Variables
```groovy
environment {
    REGISTRY = '10.2.2.40:5000'
    IMAGE_NAME = 'myapp'
    K8S_NAMESPACE = 'production'
    GIT_REPO = 'http://10.2.2.40:3001/admin/myapp.git'
    HELM_REPO = 'https://github.com/your-org/helm-charts'
}
```

### Harbor Insecure Registry
```bash
# /etc/docker/daemon.json
{
  "insecure-registries": ["10.2.2.40:5000"]
}
```

## 🧪 Testing

### Manual Build
```bash
# Jenkins에서 수동 빌드
Jenkins → myapp-pipeline → Build Now
```

### Auto Build (Git Push)
```bash
cd /root/Antigravity/Ansible/myapp
echo "// Updated $(date)" >> src/index.js
git add .
git commit -m "Test auto deployment"
git push origin main
```

### Verify Deployment
```bash
kubectl get pods -n production
kubectl get svc -n production
curl http://10.2.2.100/health
```

## 📊 Monitoring

### Jenkins
- URL: http://10.2.2.40:8080
- Pipeline History: Build logs, stages, artifacts

### Harbor
- URL: http://10.2.2.40:5000
- Images: library/myapp with build tags

### ArgoCD
- URL: http://10.2.2.100:30080 (NodePort)
- Applications: Sync status, health

### Kubernetes
```bash
kubectl get all -n production
kubectl logs -f deployment/myapp -n production
```

## 🐛 Troubleshooting

### Issue: Docker login failed
```bash
# Add insecure registry
vi /etc/docker/daemon.json
systemctl restart docker
docker login 10.2.2.40:5000
```

### Issue: ImagePullBackOff
```bash
# Create Harbor secret
kubectl create secret docker-registry harbor-secret \
  --docker-server=10.2.2.40:5000 \
  --docker-username=admin \
  --docker-password=HarborAdmin123 \
  -n production

# Add to deployment
spec:
  imagePullSecrets:
  - name: harbor-secret
```

### Issue: ArgoCD not syncing
```bash
# Check ArgoCD application
kubectl get application -n argocd
kubectl describe application myapp -n argocd

# Manual sync
argocd app sync myapp
```

## 📞 Support

**Documentation**:
- Jenkinsfile: `/root/Antigravity/Ansible/CICD/Jenkinsfile.app`
- Docs: `/root/Antigravity/Ansible/CICD/docs/`

**Access**:
- Jenkins: http://10.2.2.40:8080
- Gitea: http://10.2.2.40:3001
- Harbor: http://10.2.2.40:5000
- ArgoCD: http://10.2.2.100:30080
