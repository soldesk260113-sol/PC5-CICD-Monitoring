# ═══════════════════════════════════════════════════════════════════════════
# Root 계정으로 Ansible 실행 설정 가이드
# ═══════════════════════════════════════════════════════════════════════════

## 변경 사항

### 1. group_vars/all.yml 수정
```yaml
# SSH 연결 설정 (root 계정 사용)
ansible_user: root
ansible_ssh_private_key_file: ~/.ssh/id_rsa
ansible_python_interpreter: /usr/bin/python3
# ansible_become_password는 제거 (root는 sudo 불필요)
```

### 2. SSH 키 배포
root 계정으로 배포하려면 root 계정의 SSH 키를 모든 서버의 root 계정에 배포해야 합니다.

**VM에서:**
```bash
cd /root/Antigravity/Ansible/Script
sudo ./vm_distribute_ssh_root.sh
```

**Jenkins에서:**
```bash
cd /root/Antigravity/Ansible/Script
./jenkins_distribute_ssh_root.sh
```

### 3. 프록시 설정 수정
10.2.3.x 서브넷 접속 시 프록시 사용자도 root로 변경:

**group_vars/DB_Servers.yml:**
```yaml
ansible_ssh_common_args: '-o ProxyCommand="ssh -W %h:%p -q root@10.2.2.20"'
```

**group_vars/ETCD_Cluster.yml:**
```yaml
ansible_ssh_common_args: '-o ProxyCommand="ssh -W %h:%p -q root@10.2.2.20"'
```

## ⚠️ 주의사항

1. **보안 위험**
   - Root 직접 접속은 보안상 권장되지 않음
   - 프로덕션 환경에서는 ansible 계정 사용 권장

2. **플레이북 호환성**
   - 일부 플레이북에서 `become: yes`가 있어도 root로 실행됨
   - 대부분 문제없지만, 일부 권한 관련 작업에서 예상치 못한 동작 가능

3. **감사 로그**
   - Root로 실행하면 누가 무엇을 했는지 추적 어려움
   - ansible 계정 사용 시 sudo 로그로 추적 가능

## 🎯 권장 사항

**현재 설정 유지 (ansible 계정)를 권장합니다:**
- ✅ 보안 모범 사례
- ✅ 감사 추적 가능
- ✅ 대부분의 Ansible 플레이북과 호환
- ✅ 이미 모든 설정 완료됨

**Root 계정은 다음 경우에만 사용:**
- 테스트 환경
- 빠른 프로토타이핑
- ansible 계정 설정이 불가능한 경우
