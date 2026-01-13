#!/bin/bash
# configure_all_k8s_nodes.sh
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
    # containerd 설정 디렉토리 생성
    mkdir -p /etc/containerd/certs.d/10.2.2.40:5000
    
    # Harbor registry 설정
    cat > /etc/containerd/certs.d/10.2.2.40:5000/hosts.toml << 'TOML'
server = "http://10.2.2.40:5000"

[host."http://10.2.2.40:5000"]
  capabilities = ["pull", "resolve", "push"]
  skip_verify = true
TOML
    
    # containerd 재시작
    systemctl restart containerd
    
    echo "✅ $HOSTNAME configured"
EOF
done

echo "=== All nodes configured ==="