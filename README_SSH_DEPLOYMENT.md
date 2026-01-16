# Antigravity Infrastructure - SSH 키 배포 가이드

## 📋 개요

Jenkins에서 Ansible 플레이북을 실행하려면 모든 서버에 Jenkins 컨테이너의 SSH 키가 배포되어 있어야 합니다.

## 🔑 SSH 키 배포 절차

### 1단계: Jenkins SSH 키 자동 배포

Jenkins 컨테이너를 재배포하거나 새로운 서버를 추가했을 때 실행합니다.

```bash
cd /root/Antigravity/Ansible
./Script/jenkins_distribute_sshkeys.sh
```

**이 스크립트가 하는 일:**
1. Jenkins 컨테이너에 SSH 키가 없으면 자동 생성
2. `inventory.ini`의 모든 서버에 Jenkins SSH 키 배포 시도
3. 실패한 서버는 현재 VM에서 자동 재시도

**배포 대상 서버:**
- PC1: SECURE, WAF
- PC2: K8S-ControlPlane1~3
- PC3: K8S-WorkerNode1~3
- PC4: DB-Proxy1~2, DB-Active/Standby/Backup, etcd_1~3, Storage
- PC5: Monitoring, Monitoring_Backup, DNS
- PC6: K8S-WorkerNode4~6

### 2단계: Jenkins 파이프라인 실행

Jenkins 웹 UI에서 파이프라인을 실행합니다.

**접속 URL:** http://172.16.6.61:8080 (외부) 또는 http://10.2.2.40:8080 (내부)

**파라미터:**
- `PLAYBOOK`: 실행할 플레이북 선택
  - `site.yml`: 전체 인프라 배포 (순서대로 모든 플레이북 실행)
  - `playbooks/00_network_provisioning.yml`: 네트워크 설정
  - `playbooks/01_common_setup.yml`: 공통 설정
  - `playbooks/02_k8s_install.yml`: Kubernetes 클러스터 구축
  - `playbooks/03_deploy_monitoring.yml`: 모니터링 시스템 배포
  - `playbooks/04_deploy_db.yml`: 데이터베이스 및 스토리지 배포
  - `playbooks/05_deploy_cicd.yml`: CI/CD 시스템 배포
  - `playbooks/06_deploy_registry.yml`: Docker Registry 배포
  - `playbooks/07_deploy_argocd.yml`: ArgoCD 배포
  - `playbooks/08_deploy_security.yml`: 보안 계층 배포

- `LIMIT`: 대상 호스트 제한 (기본값: `all`)
  - 예: `PC2` (PC2만), `!DB_Servers` (DB 서버 제외), `K8S_Cluster` (K8S 클러스터만)

- `DRY_RUN`: Dry Run 모드 (기본값: `false`)
  - `true`: 변경사항 시뮬레이션만 수행 (실제 적용 안 함)
  - `false`: Dry Run 후 승인 단계를 거쳐 실제 배포

## 🔧 문제 해결

### Jenkins에서 특정 서버 접속 실패 시

**증상:** `Permission denied (publickey,gssapi-keyex,gssapi-with-mic,password)`

**원인:** Jenkins SSH 키가 해당 서버에 배포되지 않음

**해결방법:**
```bash
# 1단계 스크립트 재실행
./Script/jenkins_distribute_sshkeys.sh
```

### 10.2.3.x 서브넷 서버 접속 문제

**대상 서버:** DB-Active, DB-Standby, DB-Backup, etcd_1, etcd_2, etcd_3

**특징:** 이 서버들은 DB-Proxy1(10.2.2.20)을 통한 SSH 프록시 접속 필요

**Ansible 설정:**
- `group_vars/ETCD_Cluster.yml`
- `group_vars/DB_Servers.yml`

```yaml
ansible_ssh_common_args: '-o ProxyCommand="ssh -W %h:%p -q {{ ansible_user }}@10.2.2.20"'
```

**Jenkins 컨테이너에서 수동 테스트:**
```bash
# 프록시 서버 접속 확인
docker exec jenkins ssh -o StrictHostKeyChecking=no ansible@10.2.2.20 'hostname'

# 프록시를 통한 etcd 서버 접속 확인
docker exec jenkins ssh -o StrictHostKeyChecking=no \
  -o 'ProxyCommand=ssh -W %h:%p -q ansible@10.2.2.20' \
  ansible@10.2.3.20 'hostname'
```

## 📝 site.yml 실행 순서

`site.yml`을 실행하면 다음 순서로 플레이북이 실행됩니다:

1. **00_network_provisioning.yml** - 네트워크 설정 (IP, DNS)
2. **01_common_setup.yml** - 공통 설정 (패키지, 방화벽, NTP 등)
3. **08_deploy_security.yml** - 보안 계층 (SECURE, WAF, DNS)
4. **04_deploy_db.yml** - 데이터베이스 및 스토리지
   - DB-Proxy (HAProxy + Keepalived)
   - Etcd Cluster
   - PostgreSQL Cluster (Patroni)
   - Backup & Storage
5. **02-1_reset_k8s_node.yml** - Kubernetes 노드 초기화
6. **02_k8s_install.yml** - Kubernetes 클러스터 구축
7. **03_deploy_monitoring.yml** - 모니터링 시스템
8. **05_deploy_cicd.yml** - CI/CD 시스템
9. **06_deploy_registry.yml** - Docker Registry
10. **07_deploy_argocd.yml** - ArgoCD
11. **07_deploy_argocd_apps.yml** - ArgoCD Applications

## 🚀 빠른 시작

### 최초 배포 (전체 인프라)

```bash
# 1. Jenkins SSH 키 배포
cd /root/Antigravity/Ansible
./Script/jenkins_distribute_sshkeys.sh

# 2. Jenkins 웹 UI 접속
# http://172.16.6.61:8080

# 3. 파이프라인 실행
# - PLAYBOOK: site.yml
# - LIMIT: all
# - DRY_RUN: false (체크 해제)

# 4. Dry Run 결과 확인 후 승인
```

### 특정 플레이북만 실행

```bash
# 예: DB 서버만 재배포
# Jenkins 웹 UI에서:
# - PLAYBOOK: playbooks/04_deploy_db.yml
# - LIMIT: all
# - DRY_RUN: false
```

### 특정 호스트 그룹만 대상

```bash
# 예: Kubernetes 클러스터만 재설치
# Jenkins 웹 UI에서:
# - PLAYBOOK: playbooks/02_k8s_install.yml
# - LIMIT: K8S_Cluster
# - DRY_RUN: false
```

## ⚠️ 주의사항

1. **Jenkins SSH 키 배포는 필수**
   - Jenkins 컨테이너 재배포 시 반드시 1단계 스크립트 실행
   - 새로운 서버 추가 시에도 스크립트 재실행

2. **Dry Run 먼저 실행**
   - 실제 배포 전에 항상 Dry Run으로 변경사항 확인
   - 예상치 못한 변경사항이 있는지 검토

3. **순서 준수**
   - `site.yml`은 정해진 순서대로 실행됨
   - 개별 플레이북 실행 시 의존성 확인 필요

4. **오프라인 서버**
   - SSH 키 배포 스크립트는 오프라인 서버를 자동으로 스킵
   - 서버가 켜지면 스크립트 재실행

## 📞 문제 발생 시

1. Jenkins 로그 확인: http://172.16.6.61:8080/job/Ansible-Pipeline/
2. Ansible 실행 로그 확인
3. SSH 접속 테스트:
   ```bash
   docker exec jenkins ssh ansible@<서버IP> 'hostname'
   ```
