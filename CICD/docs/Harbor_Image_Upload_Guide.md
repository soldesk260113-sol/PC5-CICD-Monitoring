# Harbor 이미지 업로드 가이드
## 📋 Harbor 접속 정보
- **내부 URL**: http://10.2.2.40:5000
- **외부 URL**: http://172.16.6.61:5000 (포트 포워딩)
- **관리자 계정**: admin
- **관리자 비밀번호**: Admin123

## 🚀 Quick Start
### 1. Harbor 웹 UI 접속
# 브라우저에서 접속
http://10.2.2.40:5000
# 로그인
Username: admin
Password: Admin123

### 2. 프로젝트 생성
1. 로그인 후 **Projects** 클릭
2. **NEW PROJECT** 버튼 클릭
3. 프로젝트 정보 입력:
   - **Project Name**: `library` (또는 원하는 이름)
   - **Access Level**: Public 선택 (외부에서 pull 가능)
   - **Storage Quota**: -1 (무제한) 또는 원하는 용량
4. **OK** 클릭

##################################################################################
# 1. Harbor에서 이미지 가져오기
docker pull 10.2.2.40:5000/library/kma-api:latest
docker pull 10.2.2.40:5000/library/my-web:1.0

# 2. 컨테이너 실행 (백그라운드)
docker run -d -p 8000:8000 --name my-check 10.2.2.40:5000/library/kma-api:latest
docker run -d -p 8081:80 --name my-check2 10.2.2.40:5000/library/my-web:1.0
##################################################################################

##################################################################################
## 🐳 Docker 이미지 업로드
### Step 1: Docker 로그인
# Insecure Registry 설정 (최초 1회)
sudo vi /etc/docker/daemon.json
# 다음 내용 추가
{
  "insecure-registries": ["10.2.2.40:5000"]
}
# Docker 재시작
sudo systemctl restart docker
# Harbor 로그인
docker login 10.2.2.40:5000
# Username: admin
# Password: Admin123

### Step 2: 이미지 태그 지정
# 기존 이미지에 Harbor 태그 추가
docker tag <이미지명>:<태그> 10.2.2.40:5000/<프로젝트명>/<이미지명>:<태그>
# 예시: nginx 이미지를 library 프로젝트에 업로드
docker tag nginx:latest 10.2.2.40:5000/library/nginx:latest
docker tag nginx:latest 10.2.2.40:5000/library/nginx:v1.0

### Step 3: 이미지 Push
# Harbor에 이미지 업로드
docker push 10.2.2.40:5000/<프로젝트명>/<이미지명>:<태그>
# 예시
docker push 10.2.2.40:5000/library/nginx:latest
docker push 10.2.2.40:5000/library/nginx:v1.0

### Step 4: 업로드 확인
# Harbor 웹 UI에서 확인
# Projects → library → Repositories → nginx
# 또는 Docker 명령어로 확인
# docker pull 10.2.2.40:5000/library/nginx:latest
##################################################################################