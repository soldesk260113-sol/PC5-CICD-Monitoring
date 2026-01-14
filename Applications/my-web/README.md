# myapp - Sample Application

## 📋 개요

Jenkins + Harbor CI/CD 파이프라인 데모용 샘플 Node.js 애플리케이션

## 🚀 빠른 시작

### 로컬 개발

```bash
# 의존성 설치
npm install

# 개발 서버 실행
npm run dev

# 테스트
npm test

# 프로덕션 빌드
npm run build
```

### Docker 빌드 및 실행

```bash
# 이미지 빌드
docker build -t myapp:1.0 .

# 컨테이너 실행
docker run -d -p 3000:3000 --name myapp myapp:1.0

# 확인
curl http://localhost:3000/health
```

## 🔄 CI/CD 워크플로우

### Jenkins Pipeline

1. **Checkout** - Gitea에서 소스 코드 가져오기
2. **Build & Test** - 애플리케이션 빌드 및 테스트
3. **Docker Build** - Docker 이미지 빌드
4. **Image Scan** - Trivy로 보안 스캔
5. **Push to Harbor** - Harbor Registry에 업로드

### Harbor에서 확인

```
URL: http://10.2.2.40:5000
Login: admin / Admin123
Projects → library → myapp
```

### 다른 서버에서 사용

```bash
# Docker 설정 (최초 1회)
cat > /etc/docker/daemon.json << EOF
{
  "insecure-registries": ["10.2.2.40:5000"]
}
EOF
systemctl restart docker

# Harbor 로그인
docker login 10.2.2.40:5000 -u admin -p Admin123

# 이미지 Pull
docker pull 10.2.2.40:5000/library/myapp:latest

# 실행
docker run -d -p 8080:3000 --name myapp \
  --restart=always \
  10.2.2.40:5000/library/myapp:latest

# 확인
curl http://localhost:8080/health
```

## 📁 프로젝트 구조

```
myapp/
├── src/
│   └── index.js          # 메인 애플리케이션
├── tests/
│   └── app.test.js       # 테스트
├── k8s_manifests/        # Kubernetes 매니페스트 (참고용)
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
├── Dockerfile            # Docker 이미지 빌드
├── Jenkinsfile           # Jenkins 파이프라인
├── package.json          # Node.js 의존성
└── README.md
```

## 🔧 환경 변수

- `NODE_ENV`: 실행 환경 (production/development)
- `PORT`: 서버 포트 (기본: 3000)
- `APP_VERSION`: 애플리케이션 버전

## 🛠️ API 엔드포인트

- `GET /` - 홈페이지
- `GET /health` - Health check
- `GET /ready` - Readiness check
- `GET /api/info` - 애플리케이션 정보

## 📦 Harbor 이미지 태그

- `latest` - 최신 빌드
- `<BUILD_NUMBER>` - 특정 빌드 번호 (예: 42)

## 🔗 관련 링크

- **Jenkins**: http://10.2.2.40:8080
- **Gitea**: http://10.2.2.40:3001
- **Harbor**: http://10.2.2.40:5000
