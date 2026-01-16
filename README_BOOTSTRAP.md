# Ansible Control Node 초기화 가이드 (Bootstrap)

이 문서는 VM(Control Node)이 초기화되거나 새로운 환경을 구축할 때, **Jenkins 및 Ansible 환경을 한 번에 복구**하는 방법을 설명합니다.

## 🚀 빠른 시작 (Quick Start)

가장 간단한 방법은 자동화 스크립트를 실행하는 것입니다.

```bash
# 1. 터미널 접속 (root 권한 권장)
cd /root/Antigravity/Ansible/Script

# 2. 실행 권한 부여
chmod +x bootstrap_master_node.sh

# 3. 스크립트 실행
./bootstrap_master_node.sh
```

---

## 📋 상세 절차 (Manual Steps)

스크립트를 사용하지 않고 단계별로 진행하려면 아래 절차를 따르세요.

### 1. 필수 패키지 설치

Ansible 실행을 위한 기본 도구를 설치합니다.

```bash
sudo dnf install -y ansible-core python3-pip sshpass git
```

### 2. VM SSH 키 배포

Control Node(현재 VM)에서 다른 서버들로 접속할 수 있도록 SSH 키를 배포합니다.

```bash
cd /root/Antigravity/Ansible/Script

# ansible 계정 키 배포 (필수)
./vm_distribute_ssh_ansible.sh

# 연결 테스트
ansible -i ../inventory.ini all -m ping
```

### 3. Jenkins 및 CI/CD 도구 배포

Ansible 플레이북을 실행하여 Jenkins, Gitea, Helm 등을 설치합니다.

```bash
cd /root/Antigravity/Ansible

# CI/CD 플레이북 실행
ansible-playbook -i inventory.ini playbooks/05_deploy_cicd.yml
```

이 과정에서 수행되는 작업:
- Jenkins 설치 및 컨테이너 실행
- Jenkins 내부 SSH 키 생성
- 모든 서버에 Jenkins SSH 키 자동 배포
- Git, Helm 설치

### 4. Jenkins 접속 확인

설치가 완료되면 브라우저에서 접속해보세요.

- **Jenkins:** http://10.2.2.40:8080
- **Gitea:** http://10.2.2.40:3000

---

## 🛠️ 문제 해결 (Troubleshooting)

### SSH 연결 실패
만약 스크립트 실행 중 SSH 연결 실패 오류가 발생하면, 대상 서버의 비밀번호가 **기본값(ansible)**인지 확인하세요.

```bash
# 개별 서버 키 배포 재시도
cd /root/Antigravity/Ansible/Script
./vm_distribute_ssh_ansible.sh
```

### Jenkins 컨테이너 오프라인
Jenkins가 실행되지 않는다면 로그를 확인하세요.

```bash
cd /opt/jenkins_stack
docker compose logs -f
```

### 서버 재부팅 후 연결 끊김
서버 재부팅으로 SSH 키가 사라졌다면, Jenkins 파이프라인의 **Pre-flight Check & Heal** 단계가 자동으로 복구합니다. 또는 수동으로 복구할 수 있습니다:

```bash
cd /root/Antigravity/Ansible/Script
./jenkins_distribute_ssh_ansible.sh
```
