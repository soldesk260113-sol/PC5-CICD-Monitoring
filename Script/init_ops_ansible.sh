#!/bin/bash
# PC5(Ops) 서버 초기화 및 Ansible 자동 설치 스크립트

echo "[1/4] 시스템 업데이트 및 EPEL 리포지토리 설치"
sudo dnf update -y
sudo dnf install -y epel-release

echo "[2/4] Ansible 및 필수 패키지 설치"
sudo dnf install -y ansible python3-pip git vim
sudo pip3 install --upgrade pip

echo "[3/4] Ansible 프로젝트 폴더 구조 생성"
# 논리적 아키텍처 흐름에 따른 폴더 구성 (API -> 데이터 -> Ansible 제어)
mkdir -p ~/Ansible/{playbooks,roles,group_vars,host_vars,templates}
cd ~/Ansible
mkdir -p roles/{common,docker,HAproxy,WAF,nginx,api_deploy,mysql_master_slave,db_proxy,storage_mount,k8s_base,k8s_master,monitoring}/tasks

echo "[4/4] 기본 설정 파일(ansible.cfg) 자동 생성"
cat <<EOF > ~/Ansible/ansible.cfg
[defaults]
inventory = ./inventory.ini
remote_user = root
host_key_checking = False
interpreter_python = /usr/bin/python3
EOF

echo "===================================================="
echo "Ansible 설치 및 프로젝트 초기화가 완료되었습니다!"
ansible --version
echo "===================================================="
