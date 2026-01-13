#!/bin/bash
# fix_containerd_harbor.sh - containerd 메인 설정 파일에 Harbor registry 추가

NODES=(
  "10.2.2.2"   # K8S-ControlPlane1
  "10.2.2.3"   # K8S-ControlPlane2
  "10.2.2.4"   # K8S-ControlPlane3
  "10.2.2.5"   # K8S-WorkerNode1
  "10.2.2.6"   # K8S-WorkerNode2
  "10.2.2.7"   # K8S-WorkerNode3
  "10.2.2.8"   # K8S-WorkerNode4
  "10.2.2.9"   # K8S-WorkerNode5
  "10.2.2.10"  # K8S-WorkerNode6
)

for NODE in "${NODES[@]}"; do
  echo "=== Configuring $NODE ==="
  
  ssh root@$NODE << 'EOF'
    # containerd 설정 백업
    cp /etc/containerd/config.toml /etc/containerd/config.toml.bak
    
    # config_path 활성화 확인 및 추가
    if ! grep -q "config_path.*certs.d" /etc/containerd/config.toml; then
      # [plugins."io.containerd.grpc.v1.cri".registry] 섹션 찾기
      if grep -q '\[plugins."io.containerd.grpc.v1.cri".registry\]' /etc/containerd/config.toml; then
        # config_path 추가
        sed -i '/\[plugins."io.containerd.grpc.v1.cri".registry\]/a \      config_path = "/etc/containerd/certs.d"' /etc/containerd/config.toml
        echo "✅ config_path added to config.toml"
      else
        # registry 섹션이 없으면 추가
        cat >> /etc/containerd/config.toml << 'CONF'

[plugins."io.containerd.grpc.v1.cri".registry]
  config_path = "/etc/containerd/certs.d"
CONF
        echo "✅ registry section added to config.toml"
      fi
    else
      echo "ℹ️  config_path already exists"
    fi
    
    # containerd 재시작
    systemctl restart containerd
    sleep 2
    
    # 상태 확인
    if systemctl is-active --quiet containerd; then
      echo "✅ $HOSTNAME configured successfully"
    else
      echo "❌ $HOSTNAME containerd failed to start"
      systemctl status containerd --no-pager
    fi
EOF
done

echo ""
echo "=== All nodes configured ==="
echo "Testing image pull..."
echo ""

# 테스트
ssh root@10.2.2.5 "crictl pull 10.2.2.40:5000/library/nginx:alpine 2>&1 | tail -5"
