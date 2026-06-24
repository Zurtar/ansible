#!/bin/bash
set -euo pipefail

ANSIBLE_REPO="https://github.com/Zurtar/ansible.git"
PLAYBOOK="debian-base.yml"

if [[ $EUID -ne 0 ]]; then
    echo "Run with sudo: sudo bash bootstrap.sh"
    exit 1
fi

if [[ -z "${SUDO_USER:-}" ]]; then
    echo "SUDO_USER not set — run via sudo, not directly as root"
    exit 1
fi

TARGET_HOME="/home/${SUDO_USER}"
SSH_DIR="${TARGET_HOME}/.ssh"
KEY_PATH="${SSH_DIR}/id_ed25519_github"

apt-get update -qq
apt-get install -y ansible-core git

mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"
chown "${SUDO_USER}:${SUDO_USER}" "${SSH_DIR}"

echo "Paste your GitHub deploy key, then press Ctrl+D:"
cat > "${KEY_PATH}"

if [[ ! -s "${KEY_PATH}" ]]; then
    echo "Error: no key was entered"
    exit 1
fi

chmod 600 "${KEY_PATH}"
chown "${SUDO_USER}:${SUDO_USER}" "${KEY_PATH}"

cat > "${SSH_DIR}/config" << 'EOF'
Host github.com
  IdentityFile ~/.ssh/id_ed25519_github
  StrictHostKeyChecking accept-new
EOF
chmod 644 "${SSH_DIR}/config"
chown "${SUDO_USER}:${SUDO_USER}" "${SSH_DIR}/config"

ansible-pull -U "${ANSIBLE_REPO}" "${PLAYBOOK}"
