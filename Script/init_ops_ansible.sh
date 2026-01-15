#!/bin/bash
# PC5(Ops) 서버 초기화 및 Ansible 자동 설치 스크립트

echo "[1/4] 시스템 업데이트 및 EPEL 리포지토리 설치"
sudo dnf update -y
sudo dnf install -y epel-release

echo "[2/4] Ansible 및 필수 패키지 설치"
sudo dnf install -y ansible python3-pip git vim
sudo pip3 install --upgrade pip

echo "===================================================="
echo "Ansible 설치 완료!"
ansible --version
echo "===================================================="
