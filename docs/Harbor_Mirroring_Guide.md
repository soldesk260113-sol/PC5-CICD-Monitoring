# ⚓ Harbor → Docker Hub 자동 미러링 가이드

사내 Harbor에 이미지를 Push하면, 자동으로 Docker Hub로 복제(Replication)되도록 설정하는 가이드입니다.

### 💡 요약 (Architecture)
사용자 (`docker push`) ▶ Harbor (저장 & 이벤트 감지) ▶ Docker Hub (자동 업로드)

---
## 1. 사전 준비 (Prerequisites)
- [ ] **Harbor 관리자 권한 계정** (기본: `admin`)
- [ ] **Docker Hub 계정 정보** (ID / Password)
  - 📢 **권장**: 2FA => **Access Token**을 발급받아 사용.
  - [Docker Hub Access Token 발급 방법]
  (https://docs.docker.com/security/for-developers/access-tokens/)

---

## 2. 상세 설정 단계

### Step 1. Docker Hub 레지스트리 등록 (Endpoint)
Harbor가 Docker Hub에 접속할 수 있도록 자격 증명을 등록합니다.

1. Harbor 관리자 페이지 접속: [http://10.2.2.40:5000](http://10.2.2.40:5000)
2. 메뉴 이동: `Administration` > `Registries` > `+ New Endpoint`
3. 아래 표를 참고하여 정보 입력

| 필드명 | 입력값 | 비고 |
| :--- | :--- | :--- |
| **Provider** | `Docker Hub` | 목록에서 선택 |
| **Name** | `dockerhub-public` | 식별하기 쉬운 이름 지정 |
| **Endpoint URL** | `https://hub.docker.com` | 기본값 유지 |
| **Access ID** | `본인_DockerHub_ID` | Docker Hub 사용자 ID |
| **Access Secret** | `Password` or `Token` | 비밀번호 또는 액세스 토큰 |

4. `Test Connection` 클릭 → **Success** 확인 후 `OK` 저장

### Step 2. 복제 규칙 생성 (Replication Rule)
이미지가 들어오면 자동으로 외부로 전송하는 규칙을 생성합니다.

1. 메뉴 이동: `Administration` > `Replications` > `+ New Replication Rule`
2. 설정 상세
   - **Name**: `to-dockerhub-auto` (임의 지정)
   - **Replication mode**: `Push-based`
     - *설명*: Harbor의 이미지를 외부(Docker Hub)로 밀어내는 방식
   - **Source Resource Filter**:
     - `Name`: `backend/**` (특정 프로젝트만 하려면 입력, 전체는 공란)
   - **Destination Registry**: 앞서 등록한 `dockerhub-public` 선택
   - **Destination Namespace**: `DockerHub_ID` 또는 `Organization명`
     - ⚠️ **주의**: 이곳을 비워두면 경로 불일치 권한 오류가 발생합니다. 타겟 네임스페이스를 정확히 입력하세요.
   - **Trigger Mode**: `Event Based` ✅
     - *핵심*: 반드시 체크해야 이미지가 업로드되는 즉시 작동합니다.
3. `Save` 버튼 클릭하여 저장

---

## 3. 동작 테스트 (Verification)
터미널에서 이미지를 Harbor로 푸시하여 실제로 넘어가는지 확인합니다.

1. **로컬 이미지를 Harbor 경로로 태깅**
   ```bash
   # 형식: docker tag <로컬이미지> <HARBOR_URL>/<PROJECT>/<이미지명>:<태그>
   # 예시:
   docker tag my-app:v1 10.2.2.40:5000/library/my-app:v1
   ```

2. **Harbor로 푸시**
   ```bash
   docker push 10.2.2.40:5000/library/my-app:v1
   ```

3. **결과 확인**
   1. **Harbor UI**: 해당 Rule의 `Executions` 탭에서 상태가 `Succeeded`인지 확인
   2. **Docker Hub**: 웹사이트 접속 시 해당 리포지토리에 이미지가 생성되었는지 확인

---

## 🚀 수동 강제 전송 (Manual Replication)
자동 전송 외에, 기존 이미지를 즉시 전송하고 싶을 때 사용합니다.

1. **메뉴 이동**: Harbor 관리자 페이지 > `Administration` > `Replications`
2. **규칙 선택**: 아까 만든 규칙(`to-dockerhub-auto`)의 왼쪽 라디오 버튼(○) 클릭
3. **실행**: 상단 메뉴의 `Replicate` 버튼 클릭
4. **확인**: 팝업창이 뜨면 `Replicate`를 다시 눌러 실행

---

## ℹ️ 참고 사항
> **공개 범위**: Docker Hub에 올라간 이미지는 기본 정책에 따라 Public일 수 있습니다. 보안이 중요하다면 Docker Hub 리포지토리 설정을 Private으로 변경.
>
> **전송 지연**: Harbor 업로드가 100% 완료된 후 전송이 시작되므로, 
Docker Hub 반영까지 약간의 딜레이가 발생 가능.
