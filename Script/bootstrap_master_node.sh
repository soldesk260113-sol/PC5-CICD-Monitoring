#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════
# Ansible Control Node 초기화 스크립트 (Bootstrap)
# ═══════════════════════════════════════════════════════════════════════════
# 용도: VM이 초기화된 상태에서 한 번에 Jenkins 및 Ansible 환경 구축
# 실행:
#   cd /root/Antigravity/Ansible/Script
#   ./bootstrap_master_node.sh
# ═══════════════════════════════════════════════════════════════════════════

# set -e  # 오류 발생 시 중단

echo "═══════════════════════════════════════════════════════════════════════════"
echo "🚀 Ansible Control Node 부트스트랩 시작"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 1. 필수 패키지 설치
echo "[1/5] 필수 패키지 설치 (git, ansible, sshpass)..."
if ! command -v ansible &> /dev/null; then
    echo "  → Ansible 설치 중..."
    sudo dnf install -y ansible-core python3-pip sshpass git
else
    echo "  → Ansible 이미 설치됨"
fi

# sshpass 확인
if ! command -v sshpass &> /dev/null; then
    echo "  → sshpass 설치 중..."
    sudo dnf install -y sshpass
fi
echo "✅ 패키지 준비 완료"
echo ""

# 2. VM SSH 키 생성 및 배포
echo "[2/5] VM SSH 키 배포 (Control Node → Managed Nodes)..."
echo "  → vm_distribute_ssh_ansible.sh 실행"
bash "$SCRIPT_DIR/vm_distribute_ssh_ansible.sh"
echo "✅ VM SSH 키 배포 완료"
echo ""

# 3. 인벤토리 연결 테스트
echo "[3/5] 인벤토리 연결 테스트..."
cd "$PROJECT_ROOT"
if ansible -i inventory.ini all -m ping > /dev/null 2>&1; then
    echo "✅ 모든 서버 연결 성공"
else
    echo "⚠️  일부 서버 연결 실패 (무시하고 진행 - Jenkins가 처리 가능)"
fi
echo ""

# 4. Jenkins 및 CI/CD 도구 배포
echo "[4/5] Jenkins 및 CI/CD 도구 배포..."
echo "  → playbooks/05_deploy_cicd.yml 실행"
ansible-playbook -i inventory.ini playbooks/05_deploy_cicd.yml

echo "✅ Jenkins 배포 완료"
echo ""

# 5. 최종 확인
echo "[5/5] 최종 상태 확인..."
if docker ps | grep -q jenkins; then
    echo "✅ Jenkins 컨테이너 실행 중"
else
    echo "❌ Jenkins 컨테이너가 실행되지 않았습니다."
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════════"
echo "🎉 부트스트랩 완료!"
echo "═══════════════════════════════════════════════════════════════════════════"
echo "이제 다음 URL에서 Jenkins에 접속할 수 있습니다:"
echo "👉 http://10.2.2.40:8080"
echo ""
