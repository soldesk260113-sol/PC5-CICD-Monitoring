#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Antigravity Ansible Bootstrap Script
# ═══════════════════════════════════════════════════════════════════════════
# 설명:
# 1. SSH 키 생성 및 모든 서버에 Root 키 배포 (sshpass 사용)
# 2. Ansible Bootstrap Playbook 실행 (root 권한 -> ansible 계정 생성)
# 3. 인벤토리 및 기본 접속 설정 검증
# ═══════════════════════════════════════════════════════════════════════════

set -e

# 색상 변수
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}[Step 1] SSH 키 배포 (Root Access 확보)${NC}"
echo "--------------------------------------------------------"
if [ -f "./allserver_distribute_sshkeys.sh" ]; then
    ./allserver_distribute_sshkeys.sh
else
    echo "Error: ./allserver_distribute_sshkeys.sh not found!"
    exit 1
fi

echo -e "\n${BLUE}[Step 2] Ansible Bootstrap Playbook 실행 (Ansible User 생성)${NC}"
echo "--------------------------------------------------------"
# 주의: group_vars/all.yml의 ansible_user 변수 우선순위를 덮어쓰기 위해 -e "ansible_user=root" 필수
cd ..
ansible-playbook -i inventory.ini playbooks/00_bootstrap_ansible_user.yml -e "ansible_user=root"

echo -e "\n${GREEN}✅ Bootstrap Complete!${NC}"
echo "이제 'ansible' 계정으로 모든 서버를 관리할 수 있습니다."
echo "메인 플레이북 실행: ansible-playbook site.yml"
