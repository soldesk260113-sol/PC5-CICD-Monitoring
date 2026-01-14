#!/bin/bash
set -e
rm -rf /tmp/manual_build
git clone http://admin:admin123@10.2.2.40:3001/admin/myapp-source.git /tmp/manual_build
cd /tmp/manual_build
git checkout main
git pull origin main
docker build -t 10.2.2.40:5000/library/my-web:manual-v6 .
docker login 10.2.2.40:5000 -u admin -p Admin123
docker push 10.2.2.40:5000/library/my-web:manual-v6
echo "Build and Push Successful: manual-v6"
