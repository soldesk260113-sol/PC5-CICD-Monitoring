#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# VM SSH 키 배포 스크립트 (root → root)
# ═══════════════════════════════════════════════════════════════════════════
# 용도: 현재 VM의 root 계정 SSH 키를 모든 서버의 root 계정에 배포
# 대상: root@<서버IP>
# 비밀번호: centos (root 계정 비밀번호)
# ═══════════════════════════════════════════════════════════════════════════

set -e

# ───────────────────────────────────────────────────────────────────────────
# 설정
# ───────────────────────────────────────────────────────────────────────────
PASSWORD="centos"  # root 계정 비밀번호
TARGET_USER="root"
PROXY_HOST="10.2.2.20"

# inventory.ini에서 추출한 모든 서버 IP 목록
SERVERS=(
    # [PC1] Security Tier
    "172.16.6.61"   # SECURE
    "10.2.1.2"      # WAF
    
    # [PC2] K8S Control Plane
    "10.2.2.2"      # K8S-ControlPlane1
    "10.2.2.3"      # K8S-ControlPlane2
    "10.2.2.4"      # K8S-ControlPlane3
    
    # [PC3] K8S Worker Nodes (Set A)
    "10.2.2.5"      # K8S-WorkerNode1
    "10.2.2.6"      # K8S-WorkerNode2
    "10.2.2.7"      # K8S-WorkerNode3
    
    # [PC6] K8S Worker Nodes (Set B)
    "10.2.2.8"      # K8S-WorkerNode4
    "10.2.2.9"      # K8S-WorkerNode5
    "10.2.2.10"     # K8S-WorkerNode6
    
    # [PC4] DB & Storage
    "10.2.2.20"     # DB-Proxy1
    "10.2.2.21"     # DB-Proxy2
    "10.2.3.2"      # DB-Active (via Proxy)
    "10.2.3.3"      # DB-Standby (via Proxy)
    "10.2.3.4"      # DB-Backup (via Proxy)
    "10.2.3.20"     # etcd_1 (via Proxy)
    "10.2.3.21"     # etcd_2 (via Proxy)
    "10.2.3.22"     # etcd_3 (via Proxy)
    "10.2.2.30"     # Storage
    
    # [PC5] OPS
    "10.2.2.40"     # CICD-OPS
    "10.2.2.50"     # Monitoring
    "10.2.2.51"     # Monitoring_Backup
    "10.2.2.60"     # DNS
)

echo "═══════════════════════════════════════════════════════════════════════════"
echo "VM SSH 키 배포 (root → root)"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

# ───────────────────────────────────────────────────────────────────────────
# Step 1: sshpass 설치 확인
# ───────────────────────────────────────────────────────────────────────────
echo "[1/4] sshpass 설치 확인..."
if ! command -v sshpass &> /dev/null; then
    echo "  → sshpass 설치 중..."
    sudo dnf install -y sshpass > /dev/null 2>&1
    echo "  → sshpass 설치 완료"
else
    echo "  → sshpass 이미 설치됨"
fi
echo ""

# ───────────────────────────────────────────────────────────────────────────
# Step 2: SSH 키 생성 (없을 경우)
# ───────────────────────────────────────────────────────────────────────────
echo "[2/4] SSH 키 확인 및 생성..."
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "  → SSH 키 생성 중..."
    ssh-keygen -t rsa -b 2048 -N "" -f ~/.ssh/id_rsa
    echo "  → SSH 키 생성 완료"
else
    echo "  → 기존 SSH 키 사용"
fi

PUB_KEY=$(cat ~/.ssh/id_rsa.pub)
echo "  → 공개키: ${PUB_KEY:0:60}..."
echo ""

# ───────────────────────────────────────────────────────────────────────────
# Step 3: 서버들에 SSH 키 배포
# ───────────────────────────────────────────────────────────────────────────
echo "[3/4] 서버들에 SSH 키 배포 시작 (총 ${#SERVERS[@]}대)..."
echo "───────────────────────────────────────────────────────────────────────────"

SUCCESS_COUNT=0
FAIL_COUNT=0

for ip in "${SERVERS[@]}"; do
    printf "%-20s : " "$ip"
    
    # 10.2.3.x 서브넷은 프록시 사용
    if [[ "$ip" == 10.2.3.* ]]; then
        SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o ProxyCommand='ssh -o StrictHostKeyChecking=no -W %h:%p -q $TARGET_USER@$PROXY_HOST'"
    else
        SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
    fi
    
    # SSH 키 배포
    if sshpass -p "$PASSWORD" ssh $SSH_OPTS "$TARGET_USER@$ip" "
        mkdir -p ~/.ssh && chmod 700 ~/.ssh
        grep -qF '$PUB_KEY' ~/.ssh/authorized_keys 2>/dev/null || echo '$PUB_KEY' >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        restorecon -R -v ~/.ssh 2>/dev/null || true
    " &>/dev/null; then
        # 무암호 접속 확인
        if ssh $SSH_OPTS -o PasswordAuthentication=no -o PubkeyAuthentication=yes "$TARGET_USER@$ip" 'exit 0' &>/dev/null; then
            echo "✅ 성공"
            ((SUCCESS_COUNT++))
        else
            echo "⚠️  배포됨 (검증 실패)"
            ((SUCCESS_COUNT++))
        fi
    else
        echo "❌ 실패"
        ((FAIL_COUNT++))
    fi
done

echo "───────────────────────────────────────────────────────────────────────────"
echo ""

# ───────────────────────────────────────────────────────────────────────────
# Step 4: 결과 요약
# ───────────────────────────────────────────────────────────────────────────
echo "[4/4] 배포 결과 요약"
echo "───────────────────────────────────────────────────────────────────────────"
echo "  총 서버 수    : ${#SERVERS[@]}"
echo "  성공          : $SUCCESS_COUNT"
echo "  실패          : $FAIL_COUNT"
echo "───────────────────────────────────────────────────────────────────────────"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo "✅ VM SSH 키 배포 완료 (root → root)"
    exit 0
else
    echo "⚠️  일부 서버에 키 배포 실패"
    exit 1
fi
