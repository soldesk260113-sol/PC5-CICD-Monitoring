pipeline {
    agent any

    parameters {
        choice(name: 'PLAYBOOK', choices: ['site.yml', 'playbooks/00_network_provisioning.yml', 'playbooks/01_common_setup.yml', 'playbooks/02_k8s_install.yml', 'playbooks/03_deploy_monitoring.yml', 'playbooks/04_deploy_db.yml', 'playbooks/05_deploy_cicd.yml', 'playbooks/05_configure_jenkins_ssh.yml', 'playbooks/06_deploy_registry.yml', 'playbooks/07_deploy_argocd.yml', 'playbooks/07_deploy_argocd_apps.yml', 'playbooks/07_reset_argocd_apps.yml', 'playbooks/08_deploy_security.yml'], description: 'Select the playbook to run')
        string(name: 'LIMIT', defaultValue: 'all', description: 'Target hosts limit (e.g. !DB_Servers, PC1, etc). Default: all')
        booleanParam(name: 'DRY_RUN', defaultValue: false, description: 'Run in check mode (dry-run)?')
    }

    environment {
        ANSIBLE_FORCE_COLOR = 'true'
        ANSIBLE_HOST_KEY_CHECKING = 'False'
    }

    stages {
        stage('Checkout') {
            steps {
                git url: 'http://10.2.2.40:3001/admin/All-Ansible.git', branch: 'main'
            }
        }

        stage('Dry Run (Simulation)') {
            steps {
                script {
                    echo "📦 Ansible 필수 모듈 설치 중..."
                    sh "ansible-galaxy collection install -r requirements.yml"
                    
                    echo "🔍 변경사항을 시뮬레이션 합니다 (Dry Run)..."
                    sh "ansible-playbook -i inventory.ini ${params.PLAYBOOK} -l \"${params.LIMIT}\" --check"
                }
            }
        }

        stage('Human Approval') {
            when {
                expression { return params.DRY_RUN == false }
            }
            steps {
                script {
                    // 웹훅으로 자동 실행되었을 때도 여기서 멈춰서 사람의 승인을 기다립니다.
                    input message: "Dry Run 결과를 확인하셨나요? '${params.PLAYBOOK}'를 실제로 배포하시겠습니까?", ok: "🚀 배포 승인 (Deploy)"
                }
            }
        }

        stage('Deploy (Apply)') {
            when {
                expression { return params.DRY_RUN == false }
            }
            steps {
                script {
                    echo "🚀 실제 배포를 시작합니다..."
                    sh "ansible-playbook -i inventory.ini ${params.PLAYBOOK} -l \"${params.LIMIT}\""
                }
            }
        }
    }
}
