# 🏗️ Antigravity Infrastructure (Ansible)

**Antigravity** 프로젝트의 전체 인프라 자동화를 위한 Ansible 저장소입니다.  
네트워크, Kubernetes(K8s), 모니터링, DB, 보안, CI/CD 설정까지 모든 구성을 코드로 관리(IaC)합니다.

---

## 🌍 1. 서버 구성 (Server Topology)

총 **23대**의 VM으로 구성된 멀티 티어 인프라입니다.

| PC Tier | Network Zone | Hostname | IP Address | Role | 비고 |
|:---:|:---:|---|---|---|---|
| **PC1** | **Security** | `SECURE` | `172.16.6.61` (외부)<br>`10.2.1.1` (내부) | Gateway / Firewall | 포트포워딩 |
| | | `WAF` | `10.2.1.2` | Web Application Firewall | 내부 라우팅 |
| | | `DNS` | `10.2.1.3` | DNS Server | 내부 DNS |
| **PC2** | **K8s Control Plane** | `K8S-ControlPlane1` | `10.2.2.2` | K8s Primary Master | HA 리더 |
| | | `K8S-ControlPlane2` | `10.2.2.3` | K8s Secondary Master | HA 멤버 |
| | | `K8S-ControlPlane3` | `10.2.2.4` | K8s Secondary Master | HA 멤버 |
| **PC3** | **K8s Workers** | `K8S-WorkerNode1` | `10.2.2.5` | Worker Node | 워커 그룹 A |
| | | `K8S-WorkerNode2` | `10.2.2.6` | Worker Node | 워커 그룹 A |
| | | `K8S-WorkerNode3` | `10.2.2.7` | Worker Node | 워커 그룹 A |
| **PC4** | **Database & Storage** | `DB-Proxy1` | `10.2.2.20` | ProxySQL | DB 로드밸런서 |
| | | `DB-Proxy2` | `10.2.2.21` | ProxySQL | DB 로드밸런서 |
| | | `DB-Active` | `10.2.3.2` | MySQL Master | 격리망 |
| | | `DB-Standby` | `10.2.3.3` | MySQL Slave | 격리망 |
| | | `DB-Backup` | `10.2.3.4` | MySQL Backup | 격리망 |
| | | `etcd_1` | `10.2.3.20` | Etcd Cluster | 키-값 저장소 |
| | | `etcd_2` | `10.2.3.21` | Etcd Cluster | 키-값 저장소 |
| | | `etcd_3` | `10.2.3.22` | Etcd Cluster | 키-값 저장소 |
| | | `Storage` | `10.2.2.30` | NFS Server | 공유 스토리지 |
| **PC5** | **Operations** | `CI-OPS` | `10.2.2.40` | Jenkins + Gitea | CI/CD 서버 |
| | | `Monitoring` | `10.2.2.50` | Prometheus + Grafana | 모니터링 서버 |
| **PC6** | **K8s Workers** | `K8S-WorkerNode4` | `10.2.2.8` | Worker Node | 워커 그룹 B |
| | | `K8S-WorkerNode5` | `10.2.2.9` | Worker Node | 워커 그룹 B |
| | | `K8S-WorkerNode6` | `10.2.2.10` | Worker Node | 워커 그룹 B |

### 🔐 네트워크 아키텍처
- **외부망 (172.16.6.x)**: SECURE 서버만 접근 가능
- **DMZ (10.2.1.x)**: 보안 계층 (FW, WAF, DNS)
- **서비스망 (10.2.2.x)**: K8s, CI/CD, 모니터링
- **격리망 (10.2.3.x)**: DB 클러스터 (ProxyJump 필수)

---

## 🚀 2. 시작하기 (Getting Started)

### 🔑 1) SSH 키 배포 (필수)
가장 먼저 모든 서버에 SSH 접근 권한을 배포해야 합니다.  
DB 서버(10.2.3.x)는 ProxyJump를 통해 자동으로 처리됩니다.

```bash
cd Script
./allserver_distribute_sshkeys.sh
```

### 🛠️ 2) 전체 프로비저닝 (Full Deployment)
네트워크 설정부터 K8s, 모니터링, CI/CD까지 한번에 구축합니다.

```bash
# 전체 실행 (site.yml)
ansible-playbook -i inventory.ini site.yml
```

### 🎯 3) 개별 플레이북 실행
특정 단계만 실행하려면:

```bash
# 네트워크만 설정
ansible-playbook -i inventory.ini playbooks/00_network_provisioning.yml

# Kubernetes만 재구축
ansible-playbook -i inventory.ini playbooks/02_k8s_install.yml

# 모니터링만 배포
ansible-playbook -i inventory.ini playbooks/03_deploy_monitoring.yml
```

---

## 📜 3. 주요 플레이북 설명

| Playbook | Description | 대상 서버 |
|---|---|---|
| **`00_network_provisioning.yml`** | **[Step 0]** 네트워크 IP/Gateway/DNS 할당 + SSH Key 배포 | All_Nodes |
| **`01_common_setup.yml`** | **[Step 1]** 기본 설정 (패키지, 방화벽, 호스트명, UX 환경) | All_Nodes |
| **`04_db_storage_setup.yml`** | **[Step 2]** MySQL Replication + ProxySQL + NFS 구성 | PC4 | - 안씀
| **`02-1_reset_k8s_node.yml`** | **[Step 3-1]** K8s 노드 초기화 (기존 클러스터 제거) | K8S_Cluster |
| **`02_k8s_install.yml`** | **[Step 3-2]** Kubernetes HA 클러스터 구축 (Master/Worker) | PC2, PC3, PC6 |
| **`03_deploy_monitoring.yml`** | **[Step 4]** Prometheus + Grafana + Alertmanager + Node Exporter | Monitoring + All_Nodes |
| **`05_deploy_cicd.yml`** | **[Step 5]** Jenkins + Gitea 배포 | CI-OPS |
| **`06_deploy_registry.yml`** | **[Step 6]** Harbor Docker Registry 배포 | CI-OPS |
| **`05_app_deploy.yml`** | **[Step 7]** 애플리케이션 배포 (K8s Manifests) | K8S_Cluster |
| **`site_pc5.yml`** | **[Utility]** PC5 전용 배포 (CI/CD + Registry) | PC5 |

---

## 🧩 4. Role 구조 (Ansible Roles)

프로젝트는 역할 기반 아키텍처로 구성되어 있습니다.

### � 인프라 Role
- **`common`**: 모든 서버 공통 설정 (패키지, 방화벽, NTP)
- **`docker`**: Docker Engine 설치 및 설정

### 🔹 Kubernetes Role
- **`k8s_base`**: K8s 공통 설정 (containerd, kubeadm, kubelet)
- **`k8s_master`**: Control Plane 초기화 및 조인
- **`k8s_worker`**: Worker 노드 조인
- **`keepalived_haproxy`**: K8s HA 구성 (VIP: 10.2.2.100)

### 🔹 데이터베이스 Role - 임시
- **`mysql_master_slave`**: MySQL Replication 구성
- **`db_proxy`**: ProxySQL 로드밸런서
- **`storage_mount`**: NFS 마운트 설정

### 🔹 모니터링 Role
- **`monitoring`**: Prometheus, Grafana, Alertmanager 스택

### 🔹 CI/CD Role
- **`jenkins`**: Jenkins 설치 및 파이프라인 설정
- **`gitea`**: Gitea (내부 Git 서버) 설치
- **`harbor`**: Harbor Docker Registry 설치 (이미지 저장소 + Trivy 스캔)

### 🔹 보안 Role - 임시
- **`HAproxy`**: 로드밸런서
- **`WAF`**: 웹 방화벽 설정
- **`nginx`**: 웹 서버 및 리버스 프록시

### 🔹 애플리케이션 Role
- **`api_deploy`**: API 서버 배포

---

## 🖥️ 5. UX 개선 사항 (Desktop Environment)

모든 서버에 자동으로 설치되는 개발 환경 및 GUI 도구:

### 📦 설치 패키지
- **Google Chrome**: 최신 웹 브라우저
- **VS Code**: 코드 에디터 (Root 권한 설정 포함)
- **GNOME Tools**: gnome-tweaks, gnome-extensions-app, dconf-editor

### 🎨 사용자 경험
- **Tier별 색상 프롬프트**: 
  - PC1 (Red), PC2 (Green), PC3 (Yellow), PC4 (Blue), PC5 (Purple), PC6 (Cyan)
- **호스트명 자동 포맷**: `PC1-SECURE`, `PC2-K8S-ControlPlane1` 등
- **바탕화면 바로가기**: 
  - Antigravity 프로젝트 폴더
  - Google Chrome
  - VS Code
- **다국어 지원**: 한국어/영어 OS 모두 지원 (바탕화면 경로 자동 감지)

---

## 🔍 6. 모니터링 시스템 (Monitoring)

### 📊 구성 요소
- **Prometheus** (`10.2.2.50:9090`): 메트릭 수집 및 저장
- **Grafana** (`10.2.2.50:3000`): 시각화 대시보드
- **Alertmanager** (`10.2.2.50:9093`): 알림 관리
- **Node Exporter** (모든 서버 `:9100`): 시스템 메트릭 수집

### 🚨 알림 시스템
- **이메일 알림**: Alertmanager → Postfix → `/var/mail/root`
- **알림 포맷**: `[ALERT] Summary (Severity) @ Node - Description`
- **자동 청소**: 매일 18:00 및 부팅 시 메일함 자동 삭제

### 🛠️ 유용한 명령어
```bash
# Monitoring 서버에서 알림 확인
check_alerts

# Prometheus 타겟 상태 확인
curl http://10.2.2.50:9090/api/v1/targets

# Grafana 접속 (외부)
http://172.16.6.61:3000
```

### 🌐 외부 접속
SECURE 서버를 통한 포트 포워딩:
- **Grafana**: `http://172.16.6.61:3000`
- **Prometheus**: `http://172.16.6.61:9090`
- **Alertmanager**: `http://172.16.6.61:9093`

---

## 🔧 7. CI/CD 시스템

### 📦 설치 도구
- **Jenkins** (`10.2.2.40:8080`): CI/CD 파이프라인
- **Gitea** (`10.2.2.40:3001`): 내부 Git 서버
- **Harbor** (`10.2.2.40:5000`): Docker Registry (이미지 저장소)
  - Trivy 보안 스캔 포함
  - ChartMuseum (Helm Chart 저장소) 포함
  - 기본 계정: `admin` / `admin123`

### 🔄 파이프라인 구조

#### 인프라 배포 파이프라인
Jenkins는 Gitea에서 Ansible 코드를 가져와 인프라를 자동 배포합니다.
- **저장소**: `Antigravity` (Ansible playbooks)
- **트리거**: Gitea Webhook (Push 이벤트)
- **승인**: Manual Approval 단계 포함

#### 애플리케이션 배포 파이프라인
8단계 CI/CD 파이프라인으로 애플리케이션을 자동 배포합니다.

```groovy
// Jenkinsfile.app 예시
pipeline {
    agent any
    stages {
        stage('Checkout') { ... }
        stage('Build & Test') { ... }
        stage('Docker Build') { ... }
        stage('Push to Registry') { ... }  // Harbor에 푸시
    }
}
```

### 📚 CI/CD 문서
상세한 CI/CD 구축 가이드는 다음 문서를 참고하세요:
- **개선 가이드**: [`CICD/CICD_IMPROVEMENT.md`](CICD/CICD_IMPROVEMENT.md)
- **Harbor 워크플로우**: [`CICD/docs/Harbor_Image_Upload_Guide.md`](CICD/docs/Harbor_Image_Upload_Guide.md)


### 🎯 샘플 애플리케이션
- **위치**: [`Applications/myapp/`](Applications/myapp/)
- **구성**: Node.js Express + Dockerfile + K8s Manifests + Jenkinsfile
- **배포**: Gitea → Jenkins → Harbor → Kubernetes

---

## 🧪 8. 유용한 도구 & 팁 (Tools & Tips)

### 🧪 Dry Run (시뮬레이션)
실제 변경 없이 설정 검증:

```bash
ansible-playbook -i inventory.ini playbooks/00_network_provisioning.yml --check
```

### 🔗 DB 네트워크 접속 (ProxyJump)
10.2.3.x 대역은 직접 접속 불가, `DB-Proxy1 (10.2.2.20)` 경유 필수:

```bash
# SSH Config 예시 (~/.ssh/config)
Host DB-Active
    HostName 10.2.3.2
    ProxyJump root@10.2.2.20
```

### 🏷️ Tag 기반 실행
특정 작업만 실행:

```bash
# K8s만 설치
ansible-playbook -i inventory.ini site.yml --tags k8s

# 모니터링만 배포
ansible-playbook -i inventory.ini site.yml --tags monitoring
```

### 📝 인벤토리 확인
```bash
# 모든 호스트 확인
ansible-inventory -i inventory.ini --list

# 특정 그룹 확인
ansible-inventory -i inventory.ini --graph K8S_Cluster
```

---

## ⚠️ 9. 주의사항 (Important Notes)

### 🔴 필수 확인 사항
- **`inventory.ini`**: 서버 IP 변경 시 이 파일과 `host_vars/` 디렉토리를 함께 수정해야 합니다.
- **방화벽 (SECURE)**: 외부망 게이트웨이 역할을 하므로 설정 변경 시 신중해야 합니다.
- **DB 접속**: `ssh root@10.2.3.2` 직접 접속은 실패합니다. 반드시 ProxyJump를 사용하세요.
- **K8s HA VIP**: Control Plane HA는 VIP `10.2.2.100`을 사용합니다 (Keepalived).

### 🔧 트러블슈팅
- **네트워크 연결 실패**: `00_network_provisioning.yml` 실행 후 재부팅 필요할 수 있음
- **K8s 조인 실패**: `02-1_reset_k8s_node.yml`로 초기화 후 재시도
- **모니터링 접속 불가**: SECURE 서버의 포트 포워딩 규칙 확인

---

## 📚 10. 디렉토리 구조

```
Ansible/
├── inventory.ini              # Server Inventory (23 VMs)
├── ansible.cfg                # Ansible Configuration
├── site.yml                   # Master Playbook
├── Applications/              # Application Source Code
│   └── myapp/                 # Sample Node.js App
│       ├── src/
│       ├── helm/              # Helm Chart (GitOps) [NEW]
│       │   ├── Chart.yaml
│       │   ├── values.yaml
│       │   └── templates/
│       ├── k8s_manifests/     # Setup K8s Manifests (Reference)
│       ├── Dockerfile
│       ├── Jenkinsfile        # CI/CD Pipeline
│       └── README.md
├── CICD/                      # CI/CD Docs & Playbooks
│   ├── ops_playbooks/
│   ├── scripts/
│   ├── docs/
│   └── Jenkinsfile.app
├── playbooks/                 # Ansible Playbooks
│   ├── 00_network_provisioning.yml
│   ├── 01_common_setup.yml
│   ├── 02-1_reset_k8s_node.yml
│   ├── 02_k8s_install.yml
│   ├── 03_deploy_monitoring.yml
│   ├── 04_db_storage_setup.yml
│   ├── 05_deploy_cicd.yml
│   ├── 06_deploy_registry.yml
│   └── site_pc5.yml
├── roles/                     # Ansible Roles
│   ├── common/
│   ├── docker/
│   ├── k8s_base/
│   ├── k8s_master/
│   ├── k8s_worker/
│   ├── keepalived_haproxy/
│   ├── monitoring/
│   ├── mysql_master_slave/
│   ├── db_proxy/
│   ├── storage_mount/
│   ├── jenkins/
│   ├── gitea/
│   ├── harbor/
│   ├── HAproxy/
│   ├── WAF/
│   ├── nginx/
│   └── api_deploy/
└── Script/                    # Utility Scripts
    ├── allserver_distribute_sshkeys.sh
    └── init_ops_ansible.sh
```

---

## 🎯 11. 다음 단계 (Next Steps)

### ✅ 완료된 작업 (Phase 1 & 2)
1. ✅ 전체 인프라 자동화 (Ansible)
2. ✅ Kubernetes HA 클러스터 구축
3. ✅ 모니터링 시스템 (Prometheus + Grafana)
4. ✅ CI/CD 시스템 (Jenkins + Gitea)
5. ✅ Docker Registry (Harbor)
6. ✅ 샘플 애플리케이션 CI/CD 파이프라인

### 🚀 향후 개선 사항 (Phase 3)
1. **GitOps 도입**: ArgoCD 설치 및 자동 동기화
2. **Helm Chart 작성**: 애플리케이션 패키징 및 버전 관리
3. **모니터링 대시보드 커스터마이징**: Grafana 대시보드 추가 생성
4. **보안 강화**: WAF 규칙 추가, SSL/TLS 인증서 적용

---

**📅 Last Updated**: 2026-01-12
**👤 Maintainer**: Antigravity Team  
**📖 License**: Internal Use Only

---

## 📖 추가 문서

- **CI/CD 개선 가이드**: [`CICD/CICD_IMPROVEMENT.md`](CICD/CICD_IMPROVEMENT.md)
- **Phase 2 배포 가이드**: [`CICD/PHASE2_DEPLOYMENT.md`](CICD/PHASE2_DEPLOYMENT.md)
- **상세 배포 가이드**: [`CICD/DEPLOYMENT_GUIDE_DETAILED.md`](CICD/DEPLOYMENT_GUIDE_DETAILED.md)
- **샘플 앱 README**: [`Applications/myapp/README.md`](Applications/myapp/README.md)