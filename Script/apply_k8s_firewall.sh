#!/bin/bash
# -------------------------------------------------------------------------
# K8s Master & Worker Node Firewall Configuration Script
# -------------------------------------------------------------------------
# Description: Applies firewalld rules for Kubernetes Master and Worker nodes.
# Targeted Nodes: PC2 (Masters), PC3 (Workers), PC6 (Workers)
# -------------------------------------------------------------------------

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSWORD="centos"

# define Target IPs
# PC2 (Masters)
MASTERS=("10.2.2.2" "10.2.2.3" "10.2.2.4")
# PC3 (Workers Tier 1)
WORKERS_TIER1=("10.2.2.5" "10.2.2.6" "10.2.2.7")
# PC6 (Workers Tier 2)
WORKERS_TIER2=("10.2.2.8" "10.2.2.9" "10.2.2.10")

# Combine all K8s nodes
ALL_NODES=("${MASTERS[@]}" "${WORKERS_TIER1[@]}" "${WORKERS_TIER2[@]}")

echo "========================================================"
echo " Applying K8s Firewall Rules to ${#ALL_NODES[@]} Nodes"
echo "========================================================"

for IP in "${ALL_NODES[@]}"; do
    echo -e "\n[Processing Node: $IP]"

    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$IP "bash -s" << 'EOF'
        # 1. 방화벽 서비스 시작 및 자동 실행 등록
        systemctl start firewalld
        systemctl enable firewalld

        # 2. [외부 통신용] 필수 포트 개방
        # - 6443: API 서버 (마스터용, 워커에 있어도 무관)
        # - 10250: Kubelet (상태 체크용)
        # - 8472/udp: Flannel VXLAN (★핵심: 노드 간 터널링)
        # - 30000-32767: NodePort (웹 브라우저 접속용)
        firewall-cmd --permanent --add-port=6443/tcp
        firewall-cmd --permanent --add-port=10250/tcp
        firewall-cmd --permanent --add-port=8472/udp
        firewall-cmd --permanent --add-port=30000-32767/tcp

        # 3. [내부 통신용] 신뢰 구간 설정 (★502 에러 해결의 열쇠)
        # - 우리 노드끼리(10.2.2.0/24)는 서로 검사하지 않음
        firewall-cmd --permanent --zone=trusted --add-source=10.2.2.0/24
        # - 파드끼리(10.244.0.0/16) 통신은 차단하지 않음
        firewall-cmd --permanent --zone=trusted --add-source=10.244.0.0/16
        # - Flannel 가상 인터페이스(flannel.1)에서 나오는 패킷은 무조건 허용
        firewall-cmd --permanent --zone=trusted --add-interface=flannel.1

        # 4. Masquerading (NAT) 활성화 (파드가 외부 인터넷 나갈 때 필요)
        firewall-cmd --permanent --add-masquerade

        # 5. 설정 저장 및 재로드
        firewall-cmd --reload

        # 6. 적용 확인 (trusted 존과 ports 확인)
        echo "   > Public Zone Ports:"
        firewall-cmd --zone=public --list-ports | sed 's/^/     /'
        echo "   > Trusted Zone Sources/Interfaces:"
        firewall-cmd --zone=trusted --list-all | grep -E "interfaces|sources" | sed 's/^/     /'
EOF

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}SUCCESS${NC}: Firewall config applied to $IP"
    else
        echo -e "${RED}FAILED${NC}: Failed to apply to $IP"
    fi
done

echo "========================================================"
echo " Completed."
echo "========================================================"
