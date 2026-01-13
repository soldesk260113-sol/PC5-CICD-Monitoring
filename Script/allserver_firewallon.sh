#!/bin/bash
# -------------------------------------------------------------------------
# [PC5 -> 전체 인프라] Firewalld 활성화 및 자동 시작 설정
# -------------------------------------------------------------------------

# 색상 변수
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# root 비밀번호
PASSWORD="centos"

# 대상 서버 리스트 (내부 IP 기준)
SERVERS=(
    # [PC1]
    "10.2.1.1" "10.2.1.2" "10.2.1.3"
    # [PC2]
    "10.2.2.2" "10.2.2.3" "10.2.2.4"
    # [PC3]
    "10.2.2.5" "10.2.2.6" "10.2.2.7"
    # [PC6]
    "10.2.2.8" "10.2.2.9" "10.2.2.10"
    # [PC4]
    "10.2.2.20" "10.2.2.21" "10.2.2.22" "10.2.2.30"
    "10.2.3.2" "10.2.3.3" "10.2.3.4" # (라우팅 안되어 있으면 실패함)
    # [PC5] (자기 자신 제외, 주변 서버)
    "10.2.2.50" "10.2.2.60"
)

echo "========================================================"
echo " Firewalld 서비스 활성화 및 자동 시작 설정 (enable --now)"
echo "========================================================"

for ip in "${SERVERS[@]}"; do
    echo -n ">> Processing $ip ... "
    
    # 1. Firewalld 켜기 및 자동 시작 설정
    # systemctl enable --now firewalld : 지금 즉시 켜고(Start), 재부팅 시 자동 실행(Enable) 설정
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 root@$ip \
    "systemctl enable --now firewalld" > /dev/null 2>&1
    
    # 2. 상태 확인
    sshpass -p "$PASSWORD" ssh -o StrictHostKeyChecking=no root@$ip "systemctl is-active firewalld" > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[성공]${NC} Firewalld Running & Enabled"
    else
        echo -e "${RED}[실패]${NC} 접속 불가 또는 서비스 실행 실패"
    fi
done

echo "========================================================"
echo " 작업 완료. (주의: K8s 및 DB 포트 오픈 필요)"
echo "========================================================"
