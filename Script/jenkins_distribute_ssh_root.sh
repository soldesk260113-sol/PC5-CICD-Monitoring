#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Jenkins SSH 키 배포 스크립트 (jenkins → root)
# ═══════════════════════════════════════════════════════════════════════════
# 용도: Jenkins 컨테이너의 SSH 키를 모든 서버의 root 계정에 배포
# 대상: root@<서버IP>
# 비밀번호: centos (root 계정 비밀번호)
# ═══════════════════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────────────────
# 설정
# ───────────────────────────────────────────────────────────────────────────
JENKINS_CONTAINER="jenkins"
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
    "10.2.2.50"     # Monitoring
    "10.2.2.51"     # Monitoring_Backup
    "10.2.2.60"     # DNS
)

echo "═══════════════════════════════════════════════════════════════════════════"
echo "Jenkins SSH 키 배포 (jenkins → root)"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

# ───────────────────────────────────────────────────────────────────────────
# Step 1: Jenkins 컨테이너 확인
# ───────────────────────────────────────────────────────────────────────────
echo "[1/6] Jenkins 컨테이너 확인..."
if ! docker ps | grep -q "$JENKINS_CONTAINER"; then
    echo "❌ 오류: Jenkins 컨테이너가 실행 중이 아닙니다."
    exit 1
fi
echo "✅ Jenkins 컨테이너 실행 중 확인"
echo ""

# ───────────────────────────────────────────────────────────────────────────
# Step 2: Jenkins 컨테이너에 sshpass 설치
# ───────────────────────────────────────────────────────────────────────────
echo "[2/6] Jenkins 컨테이너에 sshpass 설치 확인..."
docker exec $JENKINS_CONTAINER bash -c "
    if ! command -v sshpass &> /dev/null; then
        echo '  → sshpass 설치 중...'
        apt-get update -qq && apt-get install -y sshpass > /dev/null 2>&1
        echo '  → sshpass 설치 완료'
    else
        echo '  → sshpass 이미 설치됨'
    fi
"
echo ""

# ───────────────────────────────────────────────────────────────────────────
# Step 3: Jenkins SSH 키 생성 (없을 경우)
# ───────────────────────────────────────────────────────────────────────────
echo "[3/6] Jenkins SSH 키 확인 및 생성..."
docker exec $JENKINS_CONTAINER bash -c "
    if [ ! -f /var/jenkins_home/.ssh/id_rsa ]; then
        echo '  → SSH 키 생성 중...'
        mkdir -p /var/jenkins_home/.ssh
        ssh-keygen -t rsa -b 2048 -N '' -f /var/jenkins_home/.ssh/id_rsa -C 'jenkins@antigravity'
        chmod 700 /var/jenkins_home/.ssh
        chmod 600 /var/jenkins_home/.ssh/id_rsa
        chmod 644 /var/jenkins_home/.ssh/id_rsa.pub
        echo '  → SSH 키 생성 완료'
    else
        echo '  → 기존 SSH 키 사용'
    fi
"

# Jenkins 공개키 가져오기
JENKINS_PUB_KEY=$(docker exec $JENKINS_CONTAINER cat /var/jenkins_home/.ssh/id_rsa.pub)
echo "  → 공개키: ${JENKINS_PUB_KEY:0:60}..."
echo ""

# ───────────────────────────────────────────────────────────────────────────
# Step 4: 서버들에 SSH 키 배포 (Jenkins 컨테이너에서)
# ───────────────────────────────────────────────────────────────────────────
echo "[4/6] 서버들에 SSH 키 배포 시작 (총 ${#SERVERS[@]}대)..."
echo "───────────────────────────────────────────────────────────────────────────"

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_SERVERS=()

for ip in "${SERVERS[@]}"; do
    printf "%-20s : " "$ip"
    
    # 10.2.3.x 서브넷은 프록시 사용
    if [[ "$ip" == 10.2.3.* ]]; then
        USE_PROXY="yes"
    else
        USE_PROXY="no"
    fi
    
    # Jenkins 컨테이너 내부에서 SSH 키 배포 실행
    RESULT=$(timeout 30 docker exec $JENKINS_CONTAINER bash -c "
        SSH_OPTS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5'
        
        if [ '$USE_PROXY' = 'yes' ]; then
            PROXY_CMD='ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -W %h:%p -q $TARGET_USER@$PROXY_HOST'
            SSH_OPTS=\"\$SSH_OPTS -o ProxyCommand=\\\"\$PROXY_CMD\\\"\"
        fi
        
        if timeout 10 sshpass -p '$PASSWORD' ssh \$SSH_OPTS $TARGET_USER@$ip \"
            mkdir -p ~/.ssh && chmod 700 ~/.ssh
            grep -qF '$JENKINS_PUB_KEY' ~/.ssh/authorized_keys 2>/dev/null || echo '$JENKINS_PUB_KEY' >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
        \" &>/dev/null; then
            if timeout 5 ssh \$SSH_OPTS -o PasswordAuthentication=no -o PubkeyAuthentication=yes $TARGET_USER@$ip 'exit 0' &>/dev/null; then
                echo 'SUCCESS'
            else
                echo 'VERIFY_FAILED'
            fi
        else
            echo 'DEPLOY_FAILED'
        fi
    " 2>&1 | tail -1)
    
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 124 ]; then
        echo "⏱️  타임아웃"
        ((FAIL_COUNT++))
        FAILED_SERVERS+=("$ip")
    elif [ "$RESULT" = "SUCCESS" ]; then
        echo "✅ 성공"
        ((SUCCESS_COUNT++))
    elif [ "$RESULT" = "VERIFY_FAILED" ]; then
        echo "⚠️  배포됨 (검증 실패)"
        ((SUCCESS_COUNT++))
    else
        echo "❌ 실패 (재시도 예정)"
        ((FAIL_COUNT++))
        FAILED_SERVERS+=("$ip")
    fi
done

echo "───────────────────────────────────────────────────────────────────────────"
echo ""

# ───────────────────────────────────────────────────────────────────────────
# Step 5: 실패한 서버들에 대해 현재 VM에서 재시도
# ───────────────────────────────────────────────────────────────────────────
if [ ${#FAILED_SERVERS[@]} -gt 0 ]; then
    echo "[5/6] 실패한 서버들에 대해 현재 VM에서 재시도 (${#FAILED_SERVERS[@]}대)..."
    echo "───────────────────────────────────────────────────────────────────────────"
    
    for ip in "${FAILED_SERVERS[@]}"; do
        printf "%-20s : " "$ip"
        
        if sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 $TARGET_USER@$ip "
            mkdir -p ~/.ssh && chmod 700 ~/.ssh
            grep -qF '$JENKINS_PUB_KEY' ~/.ssh/authorized_keys 2>/dev/null || echo '$JENKINS_PUB_KEY' >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
        " &>/dev/null; then
            echo "✅ 재시도 성공"
            ((SUCCESS_COUNT++))
            ((FAIL_COUNT--))
        else
            echo "❌ 재시도 실패"
        fi
    done
    
    echo "───────────────────────────────────────────────────────────────────────────"
    echo ""
else
    echo "[5/6] 재시도가 필요한 서버 없음"
    echo ""
fi

# ───────────────────────────────────────────────────────────────────────────
# Step 6: 결과 요약
# ───────────────────────────────────────────────────────────────────────────
echo "[6/6] 배포 결과 요약"
echo "───────────────────────────────────────────────────────────────────────────"
echo "  총 서버 수    : ${#SERVERS[@]}"
echo "  성공          : $SUCCESS_COUNT"
echo "  실패          : $FAIL_COUNT"
echo "───────────────────────────────────────────────────────────────────────────"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo "✅ Jenkins SSH 키 배포 완료 (jenkins → root)"
    exit 0
else
    echo "⚠️  일부 서버에 키 배포 실패"
    exit 1
fi
