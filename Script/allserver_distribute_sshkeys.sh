#!/bin/bash
# -------------------------------------------------------------------------
# [PC5 -> 전체 서버] SSH 키 자동 배포 스크립트
# 작성 기준: 제공된 네트워크 설계 요약 (PC1 ~ PC6)
# -------------------------------------------------------------------------

# 1. sshpass 설치 확인 (없으면 설치)
if ! command -v sshpass &> /dev/null; then
    echo "[1/4] sshpass 설치 중..."
    sudo dnf install -y sshpass
else
    echo "[1/4] sshpass 이미 설치됨."
fi

# 2. SSH 키 생성 (없을 경우에만)
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "[2/4] SSH 키 쌍 생성 중..."
    ssh-keygen -t rsa -b 2048 -N "" -f ~/.ssh/id_rsa
else
    echo "[2/4] 기존 SSH 키를 사용합니다."
fi

# -------------------------------------------------------------------------
# 3. 배포 대상 서버 리스트 (내부 IP 기준)
# -------------------------------------------------------------------------
# root 비밀번호 (환경에 맞게 수정 필요)
PASSWORD="ansible"

SERVERS=(
    # [PC1] Network Boundary
    "10.2.1.1"  # FW (Internal)
    "10.2.1.2"  # WAF (Eth0)

    # [PC2] K8S Control Plane
    "10.2.2.2"  # CP1
    "10.2.2.3"  # CP2
    "10.2.2.4"  # CP3

    # [PC3] K8S Worker Nodes (Set A)
    "10.2.2.5"  # Worker1
    "10.2.2.6"  # Worker2
    "10.2.2.7"  # Worker3

    # [PC6] K8S Worker Nodes (Set B)
    "10.2.2.8"  # Worker4
    "10.2.2.9"  # Worker5
    "10.2.2.10" # Worker6

    # [PC4] DB & Storage
    "10.2.2.20" # DB Proxy 1
    "10.2.2.21" # DB Proxy 2
    "10.2.3.2"  # DB Active (DMZ-2, 라우팅 확인 필요)
    "10.2.3.3"  # DB Standby
    "10.2.3.4"  # DB Backup
    "10.2.3.20" # etcd_1
    "10.2.3.21" # etcd_2
    "10.2.3.22" # etcd_3
    "10.2.2.30" # Storage

    # [PC5] Ops (Self 제외, 타 VM)
    "10.2.2.40" # CICD
    "10.2.2.50" # Monitoring1
    "10.2.2.51" # Monitoring2
    "10.2.2.60" # DNS

)

echo "[3/4] 키 배포 시작 (총 ${#SERVERS[@]}대 대상)..."
echo "----------------------------------------------------"

# 4. 루프: 접속 테스트 및 키 복사
for ip in "${SERVERS[@]}"; do
    # 핑 테스트나 포트 확인 대신, ssh 접속 시도 시 타임아웃을 짧게 주어 확인
    # -o ConnectTimeout=3 : 3초 안에 응답 없으면 실패 처리
    # -o StrictHostKeyChecking=no : 지문 확인 무시
    
    # Bash 배열로 옵션 관리 (Quoting 문제 해결)
    SSH_OPTS=("-o" "StrictHostKeyChecking=no" "-o" "UserKnownHostsFile=/dev/null" "-o" "ConnectTimeout=10")
    
    if [[ "$ip" == 10.2.3.* ]]; then
        # ProxyCommand 자체를 하나의 인자로 정확히 전달
        SSH_OPTS+=("-o" "ProxyCommand=ssh -o StrictHostKeyChecking=no -W %h:%p -q root@10.2.2.20")
    fi

    host_entry_root="root@$ip"
    host_entry_ansible="ansible@$ip"

    # [Fix] Pre-read key content to avoid passing file paths to ssh-copy-id (which fails on read-only FS)
    PUB_KEY_CONTENT=$(cat ~/.ssh/id_rsa.pub)

    # 1. Root Key Distribution (Direct SSH)
    sshpass -p "$PASSWORD" ssh "${SSH_OPTS[@]}" "$host_entry_root" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qF \"$PUB_KEY_CONTENT\" ~/.ssh/authorized_keys 2>/dev/null || echo \"$PUB_KEY_CONTENT\" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && restorecon -R -v ~/.ssh 2>/dev/null || true"
    res_root=$?

    # 2. Ansible User Key Distribution (Direct SSH)
    sshpass -p "$PASSWORD" ssh "${SSH_OPTS[@]}" "$host_entry_ansible" "mkdir -p ~/.ssh && chmod 700 ~/.ssh && grep -qF \"$PUB_KEY_CONTENT\" ~/.ssh/authorized_keys 2>/dev/null || echo \"$PUB_KEY_CONTENT\" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && restorecon -R -v ~/.ssh 2>/dev/null || true"
    res_ansible=$?
    
    # 3. Verify Passwordless Login (Critical)
    ssh "${SSH_OPTS[@]}" -o PasswordAuthentication=no -o PubkeyAuthentication=yes "$host_entry_ansible" "exit 0" &>/dev/null
    res_verify=$?

    # 실행 결과 확인
    if [ $res_verify -eq 0 ]; then
        echo -e "✅ [성공] $ip : 키 배포 및 무암호 접속 확인 완료."
    elif [ $res_root -eq 0 ] || [ $res_ansible -eq 0 ]; then
        echo -e "⚠️ [경고] $ip : 키는 배포되었으나 무암호 접속 실패 (SELinux/권한 문제 가능성)."
    else
        echo -e "❌ [실패] $ip : 접속 불가 (Timeout 또는 인증 실패)"
    fi
done

echo "----------------------------------------------------"
echo "[4/4] 작업 종료."
