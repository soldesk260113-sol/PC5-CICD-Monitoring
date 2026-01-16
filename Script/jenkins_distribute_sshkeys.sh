#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Jenkins 컨테이너 SSH 키 자동 배포 스크립트 (통합 버전)
# ═══════════════════════════════════════════════════════════════════════════
# 용도: Jenkins 재배포 시 inventory.ini의 모든 서버에 SSH 키 배포
# 기능:
#   1. Jenkins 컨테이너 내부에 SSH 키가 없으면 자동 생성
#   2. inventory.ini의 모든 서버에 키 배포 (Jenkins 컨테이너에서 시도)
#   3. 실패한 서버는 현재 VM에서 sshpass로 재시도
#   4. 10.2.3.x 서브넷은 DB-Proxy1(10.2.2.20)을 통한 프록시 접속
# ═══════════════════════════════════════════════════════════════════════════

# ───────────────────────────────────────────────────────────────────────────
# 설정
# ───────────────────────────────────────────────────────────────────────────
JENKINS_CONTAINER="jenkins"
PASSWORD="ansible"  # 서버들의 ansible 사용자 비밀번호
PROXY_HOST="10.2.2.20"  # DB-Proxy1 (10.2.3.x 서브넷 접속용)

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
echo "Jenkins 컨테이너 SSH 키 자동 배포 시작"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

# ───────────────────────────────────────────────────────────────────────────
# Step 1: Jenkins 컨테이너 확인
# ───────────────────────────────────────────────────────────────────────────
echo "[1/6] Jenkins 컨테이너 확인..."
if ! docker ps | grep -q "$JENKINS_CONTAINER"; then
    echo "❌ 오류: Jenkins 컨테이너가 실행 중이 아닙니다."
    echo "   docker ps 로 컨테이너 이름을 확인하세요."
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
        echo '  → SSH 키가 없습니다. 새로 생성합니다...'
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
SKIP_COUNT=0
FAILED_SERVERS=()

for ip in "${SERVERS[@]}"; do
    printf "%-20s : " "$ip"
    
    # 10.2.3.x 서브넷은 프록시 사용
    if [[ "$ip" == 10.2.3.* ]]; then
        USE_PROXY="yes"
    else
        USE_PROXY="no"
    fi
    
    # Jenkins 컨테이너 내부에서 SSH 키 배포 실행 (타임아웃 30초)
    RESULT=$(timeout 30 docker exec $JENKINS_CONTAINER bash -c "
        # SSH 기본 옵션 (타임아웃 5초로 단축)
        SSH_OPTS='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -o ServerAliveInterval=2 -o ServerAliveCountMax=2'
        
        # 프록시 설정
        if [ '$USE_PROXY' = 'yes' ]; then
            PROXY_CMD='ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -W %h:%p -q ansible@$PROXY_HOST'
            SSH_OPTS=\"\$SSH_OPTS -o ProxyCommand=\\\"\$PROXY_CMD\\\"\"
        fi
        
        # 키 배포 시도 (타임아웃 시 자동 실패)
        if timeout 10 sshpass -p '$PASSWORD' ssh \$SSH_OPTS ansible@$ip \"
            mkdir -p ~/.ssh && chmod 700 ~/.ssh
            grep -qF '$JENKINS_PUB_KEY' ~/.ssh/authorized_keys 2>/dev/null || echo '$JENKINS_PUB_KEY' >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
            restorecon -R -v ~/.ssh 2>/dev/null || true
        \" &>/dev/null; then
            # 무암호 접속 확인
            if timeout 5 ssh \$SSH_OPTS -o PasswordAuthentication=no -o PubkeyAuthentication=yes ansible@$ip 'exit 0' &>/dev/null; then
                echo 'SUCCESS'
            else
                echo 'VERIFY_FAILED'
            fi
        else
            echo 'DEPLOY_FAILED'
        fi
    " 2>&1 | tail -1)
    
    EXIT_CODE=$?
    
    # 결과 처리
    if [ $EXIT_CODE -eq 124 ]; then
        # timeout 명령어의 종료 코드 124 = 타임아웃
        echo "⏱️  타임아웃 (서버 꺼짐?)"
        ((SKIP_COUNT++))
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
    
    RETRY_SUCCESS=0
    RETRY_FAIL=0
    
    for ip in "${FAILED_SERVERS[@]}"; do
        printf "%-20s : " "$ip"
        
        # 현재 VM에서 sshpass를 사용하여 Jenkins 키 배포
        if sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ansible@$ip "
            mkdir -p ~/.ssh && chmod 700 ~/.ssh
            grep -qF '$JENKINS_PUB_KEY' ~/.ssh/authorized_keys 2>/dev/null || echo '$JENKINS_PUB_KEY' >> ~/.ssh/authorized_keys
            chmod 600 ~/.ssh/authorized_keys
        " &>/dev/null; then
            echo "✅ 재시도 성공"
            ((RETRY_SUCCESS++))
            ((SUCCESS_COUNT++))
            ((FAIL_COUNT--))
        else
            echo "❌ 재시도 실패"
            ((RETRY_FAIL++))
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
echo "  총 서버 수       : ${#SERVERS[@]}"
echo "  성공             : $SUCCESS_COUNT"
echo "  실패             : $FAIL_COUNT"
echo "  스킵 (오프라인)  : $SKIP_COUNT"
echo "───────────────────────────────────────────────────────────────────────────"
echo ""

if [ $FAIL_COUNT -eq 0 ]; then
    echo "✅ 온라인 서버에 Jenkins SSH 키 배포 완료!"
    if [ $SKIP_COUNT -gt 0 ]; then
        echo "⚠️  $SKIP_COUNT 대의 서버가 오프라인 상태입니다."
        echo "   해당 서버들이 켜지면 이 스크립트를 다시 실행하세요."
    fi
    echo ""
    echo "이제 Jenkins 파이프라인에서 Ansible 플레이북을 실행할 수 있습니다."
    exit 0
else
    echo "⚠️  일부 서버에 키 배포 실패 ($FAIL_COUNT 대)"
    echo "   실패한 서버들의 네트워크 연결 및 비밀번호를 확인하세요."
    exit 1
fi
