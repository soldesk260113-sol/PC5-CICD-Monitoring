# SSH 키 배포 스크립트 가이드

## 📋 개요

SSH 키 배포 스크립트는 **4가지 조합**으로 구성되어 있습니다:

| 스크립트 | 소스 | 대상 계정 | 비밀번호 | 용도 |
|---------|------|----------|---------|------|
| `vm_distribute_ssh_root.sh` | VM (root) | root@서버 | centos | VM root 계정 SSH 키 배포 |
| `vm_distribute_ssh_ansible.sh` | VM (ansible) | ansible@서버 | ansible | VM ansible 계정 SSH 키 배포 |
| `jenkins_distribute_ssh_root.sh` | Jenkins 컨테이너 | root@서버 | centos | Jenkins → root 계정 SSH 키 배포 |
| `jenkins_distribute_ssh_ansible.sh` | Jenkins 컨테이너 | ansible@서버 | ansible | Jenkins → ansible 계정 SSH 키 배포 |

## 🔑 스크립트 상세 설명

### 1. `vm_distribute_ssh_root.sh`
**용도:** 현재 VM의 root 계정 SSH 키를 모든 서버의 root 계정에 배포

**실행 방법:**
```bash
cd /root/Antigravity/Ansible/Script
sudo ./vm_distribute_ssh_root.sh
```

**대상:**
- 계정: `root@<서버IP>`
- 비밀번호: `centos`
- 서버: inventory.ini의 모든 서버 (24대)

**사용 시나리오:**
- VM에서 root 권한으로 서버 관리가 필요할 때
- 초기 서버 설정 시 root 접속이 필요할 때

---

### 2. `vm_distribute_ssh_ansible.sh`
**용도:** 현재 VM의 ansible 계정 SSH 키를 모든 서버의 ansible 계정에 배포

**실행 방법:**
```bash
cd /root/Antigravity/Ansible/Script
./vm_distribute_ssh_ansible.sh
```

**대상:**
- 계정: `ansible@<서버IP>`
- 비밀번호: `ansible`
- 서버: inventory.ini의 모든 서버 (24대)

**사용 시나리오:**
- Ansible 플레이북을 VM에서 직접 실행할 때
- 수동으로 서버 관리가 필요할 때

---

### 3. `jenkins_distribute_ssh_root.sh`
**용도:** Jenkins 컨테이너의 SSH 키를 모든 서버의 root 계정에 배포

**실행 방법:**
```bash
cd /root/Antigravity/Ansible/Script
./jenkins_distribute_ssh_root.sh
```

**대상:**
- 계정: `root@<서버IP>`
- 비밀번호: `centos`
- 서버: inventory.ini의 모든 서버 (23대, Jenkins 자신 제외)

**사용 시나리오:**
- Jenkins에서 root 권한이 필요한 작업을 수행할 때
- 시스템 레벨 설정이 필요한 플레이북 실행 시

---

### 4. `jenkins_distribute_ssh_ansible.sh` ⭐ (기본 사용)
**용도:** Jenkins 컨테이너의 SSH 키를 모든 서버의 ansible 계정에 배포

**실행 방법:**
```bash
cd /root/Antigravity/Ansible/Script
./jenkins_distribute_ssh_ansible.sh
```

**대상:**
- 계정: `ansible@<서버IP>`
- 비밀번호: `ansible`
- 서버: inventory.ini의 모든 서버 (23대, Jenkins 자신 제외)

**사용 시나리오:**
- **Jenkins 파이프라인에서 Ansible 플레이북 실행 시 (기본)**
- Jenkins 재배포 후 자동 실행됨 (`roles/jenkins/tasks/main.yml`)

**자동 실행:**
- ✅ Jenkins 배포 시 자동 실행됨
- ✅ `playbooks/05_deploy_cicd.yml` 실행 시 자동 설정

---

## 🚀 일반적인 사용 시나리오

### 시나리오 1: 최초 인프라 구축
```bash
# 1. VM root 계정으로 모든 서버 접속 설정
sudo ./vm_distribute_ssh_root.sh

# 2. VM ansible 계정으로 Ansible 플레이북 실행 준비
./vm_distribute_ssh_ansible.sh

# 3. Jenkins 배포 (자동으로 jenkins_distribute_ssh_ansible.sh 실행됨)
# Jenkins 파이프라인에서 playbooks/05_deploy_cicd.yml 실행
```

### 시나리오 2: Jenkins 재배포
```bash
# Jenkins 재배포 시 자동으로 jenkins_distribute_ssh_ansible.sh 실행됨
# 추가 작업 불필요!
```

### 시나리오 3: 새로운 서버 추가
```bash
# 1. inventory.ini에 새 서버 추가
# 2. 모든 스크립트 재실행
sudo ./vm_distribute_ssh_root.sh
./vm_distribute_ssh_ansible.sh
./jenkins_distribute_ssh_ansible.sh
```

### 시나리오 4: 수동으로 Jenkins SSH 키 재배포
```bash
# Jenkins 컨테이너가 실행 중일 때
cd /root/Antigravity/Ansible/Script
./jenkins_distribute_ssh_ansible.sh
```

---

## 🔧 스크립트 기능

### 공통 기능
- ✅ SSH 키 자동 생성 (없을 경우)
- ✅ sshpass 자동 설치
- ✅ 10.2.3.x 서브넷 프록시 지원 (DB-Proxy1을 통한 접속)
- ✅ 타임아웃 처리 (오프라인 서버 자동 스킵)
- ✅ 배포 결과 요약 (성공/실패/스킵 카운트)

### Jenkins 스크립트 추가 기능
- ✅ Jenkins 컨테이너 내부에서 직접 배포 시도
- ✅ 실패한 서버는 현재 VM에서 자동 재시도
- ✅ Jenkins 컨테이너 상태 확인

---

## 📝 비밀번호 정보

| 계정 | 비밀번호 | 용도 |
|------|---------|------|
| root | centos | 시스템 관리자 계정 |
| ansible | ansible | Ansible 자동화 계정 |

**보안 참고:**
- 프로덕션 환경에서는 비밀번호를 변경하세요
- SSH 키 배포 후에는 비밀번호 인증을 비활성화하는 것을 권장합니다

---

## 🎯 권장 사용 방법

### 일반적인 경우
```bash
# VM에서 Ansible 플레이북 실행 시
./vm_distribute_ssh_ansible.sh

# Jenkins에서 Ansible 플레이북 실행 시 (자동)
# jenkins_distribute_ssh_ansible.sh가 자동 실행됨
```

### Root 권한이 필요한 경우
```bash
# VM에서 root 작업 시
sudo ./vm_distribute_ssh_root.sh

# Jenkins에서 root 작업 시
./jenkins_distribute_ssh_root.sh
```

---

## ⚠️ 주의사항

1. **스크립트 실행 위치**
   - 모든 스크립트는 `/root/Antigravity/Ansible/Script/` 디렉토리에서 실행
   - 상대 경로를 사용하므로 다른 위치에서 실행하면 오류 발생 가능

2. **Jenkins 스크립트**
   - Jenkins 컨테이너가 실행 중이어야 함
   - Docker가 설치되어 있어야 함

3. **프록시 서버**
   - 10.2.3.x 서브넷 접속 시 DB-Proxy1(10.2.2.20)이 실행 중이어야 함
   - DB-Proxy1에 SSH 키가 먼저 배포되어 있어야 함

4. **비밀번호**
   - 스크립트 내부의 PASSWORD 변수를 환경에 맞게 수정
   - 보안을 위해 배포 후 비밀번호 변경 권장

---

## 🔍 문제 해결

### "Permission denied" 오류
**원인:** 비밀번호가 틀리거나 SSH 키가 제대로 배포되지 않음

**해결:**
```bash
# 비밀번호 확인
# root: centos
# ansible: ansible

# 스크립트 재실행
./vm_distribute_ssh_ansible.sh
```

### "Jenkins 컨테이너가 실행 중이 아닙니다" 오류
**원인:** Jenkins 컨테이너가 중지됨

**해결:**
```bash
# Jenkins 컨테이너 시작
cd /opt/jenkins_stack
docker compose up -d
```

### 10.2.3.x 서버 접속 실패
**원인:** DB-Proxy1에 SSH 키가 없거나 프록시 서버가 중지됨

**해결:**
```bash
# 1. DB-Proxy1 SSH 키 확인
ssh ansible@10.2.2.20 'hostname'

# 2. DB-Proxy1에 SSH 키 배포
./vm_distribute_ssh_ansible.sh
```

---

## 📚 관련 문서

- `README_SSH_DEPLOYMENT.md` - SSH 배포 전체 가이드
- `README_JENKINS_REDEPLOYMENT.md` - Jenkins 재배포 자동화 가이드
- `roles/jenkins/tasks/main.yml` - Jenkins 배포 자동화 설정
