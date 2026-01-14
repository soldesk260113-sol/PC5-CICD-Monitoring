# 🐙 ArgoCD 설정 및 사용 가이드

## 1. ArgoCD 설치 (Provisioning)
Ansible Playbook을 통해 이미 설치가 완료되어 있을 수 있습니다. 확인 방법은 다음과 같습니다.

### 설치 확인 (K8S Master에서)
```bash
kubectl get ns argocd
kubectl get svc -n argocd argocd-server
```

### 설치가 안 되어 있다면?
Ansible Playbook 실행:
```bash
ansible-playbook /root/Antigravity/Ansible/playbooks/07_deploy_argocd.yml
```

---

## 2. ArgoCD 접속 정보
### Admin 계정 비밀번호 확인
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

### 웹 UI 접속
- **주소**: `https://172.16.6.61:<NodePort>` (포트 포워딩됨)
- 또는 `https://10.2.2.2:<NodePort>` (내부)
- `NodePort` 확인: `kubectl get svc -n argocd argocd-server -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}'`

---

## 3. 애플리케이션 연동 (GitOps)
이미 `argocd_apps.yaml` 파일을 통해 4개의 애플리케이션(`map-api`, `energy-api`, `kma-api`, `my-web`) 설정이 준비되어 있습니다.

### 애플리케이션 등록
```bash
# 4개의 앱(App of Apps) 일괄 등록
kubectl apply -f /root/Antigravity/Ansible/argocd_apps.yaml
```

### 설정 내역 (참고)
- **Source**: Gitea (`http://10.2.2.40:3001/admin/myapp-helm.git`)
- **Destination**: Kubernetes (`production` 네임스페이스)
- **Sync Policy**: Automated (자동 동기화, Self-Heal 활성화)

---

## 4. 문제 해결 (Troubleshooting)
### Gitea 연결 실패 (TLS/Auth)
ArgoCD가 Gitea(HTTP)에 접근할 때 인증 문제가 발생할 수 있습니다. Repository를 Private으로 설정했다면 ArgoCD에 Credential을 등록해야 합니다.

**Credential 등록 방법 (CLI)**:
```bash
argocd repo add http://10.2.2.40:3001/admin/myapp-helm.git --username admin --password <Gitea암호>
```
(또는 ArgoCD 웹 UI: `Settings` > `Repositories` > `Connect Repo`에서 등록)

### Sync 실패시
1. `kubectl get app -n argocd` 명령어로 상태 확인
2. ArgoCD UI에서 `Sync Status` 및 `Events` 로그 확인
