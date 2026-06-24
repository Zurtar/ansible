#!/bin/bash
set -euo pipefail

ANSIBLE_REPO="https://github.com/Zurtar/ansible.git"
PLAYBOOK="debian-base.yml"
TARGET_USER="${SUDO_USER:-sigil}"
TARGET_HOME="/home/${TARGET_USER}"
SSH_DIR="${TARGET_HOME}/.ssh"
KEY_PATH="${SSH_DIR}/id_ed25519_github"

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo bash bootstrap.sh"
    exit 1
fi

apt-get update -qq
apt-get install -y ansible-core git

mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"
chown "${TARGET_USER}:${TARGET_USER}" "${SSH_DIR}"

echo "Paste your GitHub deploy key, then press Ctrl+D:"
cat > "${KEY_PATH}"
chmod 600 "${KEY_PATH}"
chown "${TARGET_USER}:${TARGET_USER}" "${KEY_PATH}"

cat > "${SSH_DIR}/config" << 'EOF'
Host github.com
  IdentityFile ~/.ssh/id_ed25519_github
  StrictHostKeyChecking accept-new
EOF
chmod 644 "${SSH_DIR}/config"
chown "${TARGET_USER}:${TARGET_USER}" "${SSH_DIR}/config"

ansible-pull -U "${ANSIBLE_REPO}" "${PLAYBOOK}"
