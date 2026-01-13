#!/usr/bin/env python3
"""
Antigravity 인프라 상태 모니터링 API
- 브릿지 네트워크: 직접 ping 체크
- 호스트온리 네트워크: 직접 ping 또는 SSH 경유 ping 체크
"""

from http.server import HTTPServer, BaseHTTPRequestHandler
import subprocess
import json
import threading
import time

# =============================================================================
# 서버 목록 설정
# =============================================================================

# 브릿지 네트워크 서버 (직접 ping)
BRIDGE_SERVERS = {
    # PC1 - 보안 게이트웨이
    "SECURE": {"ip": "172.16.6.61", "role": "보안 게이트웨이", "tier": "pc1"},
    # PC2 - 웹 티어
    "WEB1": {"ip": "172.16.6.62", "role": "웹서버 (HA1)", "tier": "pc2"},
    "WEB2": {"ip": "172.16.6.69", "role": "웹서버 (HA2)", "tier": "pc2"},
    "LB": {"ip": "172.16.6.107", "role": "로드밸런서", "tier": "pc2"},
    # PC3 - API 티어
    "API1": {"ip": "172.16.6.63", "role": "API 서버 (HA1)", "tier": "pc3"},
    "API2": {"ip": "172.16.6.67", "role": "API 서버 (HA2)", "tier": "pc3"},
    # PC4 - DB 게이트웨이
    "Proxy1": {"ip": "172.16.6.64", "role": "DB 프록시", "tier": "pc4"},
    # PC5 - 운영 게이트웨이
    "CI-OPS": {"ip": "172.16.6.65", "role": "CI/CD & Ansible", "tier": "pc5"},
    # PC6 - K8s 게이트웨이
    "K8S-Master": {"ip": "172.16.6.66", "role": "K8s 마스터", "tier": "pc6"},
}

# 호스트온리 - 직접 ping (이 서버가 해당 네트워크에 연결됨)
HOSTONLY_DIRECT = {
    # PC5 내부망 (10.2.5.x) - CI-OPS에서 직접 접근 가능
    "Monitoring": {"ip": "10.2.5.10", "role": "모니터링", "tier": "pc5", "gateway": "CI-OPS"},
    "DRserver-OPS": {"ip": "10.2.5.20", "role": "DR 서버", "tier": "pc5", "gateway": "CI-OPS"},
}

# 호스트온리 - SSH 경유 ping 필요 (게이트웨이를 통해서만 접근 가능)
HOSTONLY_SSH = {
    # PC1 내부망 (10.2.1.x) - SECURE 경유
    "WAF": {"ip": "10.2.1.10", "role": "웹방화벽", "tier": "pc1", "gateway": "SECURE"},
    "DNS": {"ip": "10.2.1.53", "role": "DNS 서버", "tier": "pc1", "gateway": "SECURE"},
    # PC4 내부망 (192.168.10.x) - Proxy1 경유
    "DB-A": {"ip": "192.168.10.20", "role": "DB 액티브", "tier": "pc4", "gateway": "Proxy1"},
    "DB-S": {"ip": "192.168.10.30", "role": "DB 스탠바이", "tier": "pc4", "gateway": "Proxy1"},
    "DB-B": {"ip": "192.168.10.40", "role": "DB 백업", "tier": "pc4", "gateway": "Proxy1"},
    # PC6 내부망 (10.2.6.x) - K8S-Master 경유
    "K8S-SubNode": {"ip": "10.2.6.10", "role": "K8s 워커", "tier": "pc6", "gateway": "K8S-Master"},
    "DRserver-K8S": {"ip": "10.2.6.20", "role": "DR 서버", "tier": "pc6", "gateway": "K8S-Master"},
}

# 상태 캐시 (백그라운드 스레드에서 업데이트)
status_cache = {}
cache_lock = threading.Lock()

# =============================================================================
# 상태 체크 함수
# =============================================================================

def ping_direct(ip: str, timeout: int = 1) -> bool:
    """서버에 직접 ping을 보내 상태를 확인한다."""
    try:
        result = subprocess.run(
            ["ping", "-c", "1", "-W", str(timeout), ip],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=timeout + 1
        )
        return result.returncode == 0
    except Exception:
        return False


def ping_via_ssh(gateway_ip: str, target_ip: str, timeout: int = 5) -> bool:
    """게이트웨이에 SSH 접속 후 내부 서버에 ping을 보낸다."""
    try:
        ssh_cmd = [
            "ssh",
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            "-o", "ConnectTimeout=3",
            "-o", "BatchMode=yes",
            f"root@{gateway_ip}",
            f"ping -c 1 -W 1 {target_ip}"
        ]
        result = subprocess.run(
            ssh_cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            timeout=timeout
        )
        return result.returncode == 0
    except Exception:
        return False


def update_status_cache():
    """백그라운드에서 주기적으로 서버 상태를 업데이트한다."""
    while True:
        new_status = {}
        gateway_status = {}
        
        # 1. 브릿지 네트워크 서버 체크 (직접 ping)
        for name, info in BRIDGE_SERVERS.items():
            is_alive = ping_direct(info["ip"])
            gateway_status[name] = is_alive
            new_status[name] = {
                "ip": info["ip"],
                "role": info["role"],
                "tier": info["tier"],
                "network": "bridge",
                "status": "active" if is_alive else "offline",
            }
        
        # 2. 호스트온리 - 직접 ping (PC5 내부망)
        for name, info in HOSTONLY_DIRECT.items():
            is_alive = ping_direct(info["ip"])
            new_status[name] = {
                "ip": info["ip"],
                "role": info["role"],
                "tier": info["tier"],
                "network": "hostonly",
                "gateway": info["gateway"],
                "status": "active" if is_alive else "offline",
            }
        
        # 3. 호스트온리 - SSH 경유 ping (PC4, PC6 내부망)
        for name, info in HOSTONLY_SSH.items():
            gateway_name = info["gateway"]
            gateway_ip = BRIDGE_SERVERS.get(gateway_name, {}).get("ip")
            
            if not gateway_status.get(gateway_name, False):
                status = "gateway-down"
            else:
                is_alive = ping_via_ssh(gateway_ip, info["ip"])
                status = "active" if is_alive else "offline"
            
            new_status[name] = {
                "ip": info["ip"],
                "role": info["role"],
                "tier": info["tier"],
                "network": "hostonly",
                "gateway": gateway_name,
                "status": status,
            }
        
        with cache_lock:
            global status_cache
            status_cache = new_status
        
        time.sleep(5)

# =============================================================================
# HTTP API 핸들러
# =============================================================================

class StatusHandler(BaseHTTPRequestHandler):
    """상태 API 요청을 처리하는 핸들러"""
    
    def do_GET(self):
        if self.path == "/api/status":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            
            with cache_lock:
                active = sum(1 for s in status_cache.values() if s["status"] == "active")
                offline = sum(1 for s in status_cache.values() if s["status"] in ["offline", "gateway-down"])
                
                response = json.dumps({
                    "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
                    "servers": status_cache,
                    "summary": {
                        "total": len(status_cache),
                        "active": active,
                        "offline": offline,
                    }
                })
            
            self.wfile.write(response.encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        print(f"[API] {args[0]}")

# =============================================================================
# 메인 함수
# =============================================================================

def main():
    total = len(BRIDGE_SERVERS) + len(HOSTONLY_DIRECT) + len(HOSTONLY_SSH)
    print(f"🚀 Antigravity 상태 API 시작 (총 {total}대)")
    print(f"   브릿지: {len(BRIDGE_SERVERS)}대 | 내부망(직접): {len(HOSTONLY_DIRECT)}대 | 내부망(SSH): {len(HOSTONLY_SSH)}대")
    
    # 백그라운드 상태 업데이터 시작
    updater = threading.Thread(target=update_status_cache, daemon=True)
    updater.start()
    
    print("⏳ 초기 상태 확인 중...")
    time.sleep(5)
    
    # HTTP 서버 시작
    server = HTTPServer(("0.0.0.0", 8081), StatusHandler)
    print("✅ API 서버 실행 중: http://0.0.0.0:8081/api/status")
    
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n👋 서버 종료")
        server.shutdown()


if __name__ == "__main__":
    main()
