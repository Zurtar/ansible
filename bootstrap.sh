#!/bin/bash
set -euo pipefail

ANSIBLE_REPO="https://github.com/Zurtar/ansible.git"
PLAYBOOK="debian-base.yml"

if [[ $EUID -ne 0 ]]; then
    echo "Run as root or with sudo"
    exit 1
fi

TARGET_USER="${SUDO_USER:-$(getent passwd 1000 | cut -d: -f1)}"
if [[ -z "$TARGET_USER" ]]; then
    echo "Could not determine target user — run via sudo or ensure UID 1000 exists"
    exit 1
fi

TARGET_HOME="/home/${TARGET_USER}"
SSH_DIR="${TARGET_HOME}/.ssh"
KEY_PATH="${SSH_DIR}/id_ed25519_github"

apt-get update -qq
apt-get install -y ansible-core git sudo

# Ensure user is in sudo group
if ! id -nG "$TARGET_USER" | grep -qw sudo; then
    /usr/sbin/usermod -aG sudo "$TARGET_USER"
    echo "Added $TARGET_USER to sudo group"
fi

mkdir -p "${SSH_DIR}"
chmod 700 "${SSH_DIR}"
chown "${TARGET_USER}:${TARGET_USER}" "${SSH_DIR}"

echo "Paste your GitHub deploy key, then press Ctrl+D:"
cat > "${KEY_PATH}"

if [[ ! -s "${KEY_PATH}" ]]; then
    echo "Error: no key was entered"
    exit 1
fi

chmod 600 "${KEY_PATH}"
chown "${TARGET_USER}:${TARGET_USER}" "${KEY_PATH}"

cat > "${SSH_DIR}/config" << 'EOF'
Host github.com
  IdentityFile ~/.ssh/id_ed25519_github
  StrictHostKeyChecking accept-new
EOF
chmod 644 "${SSH_DIR}/config"
chown "${TARGET_USER}:${TARGET_USER}" "${SSH_DIR}/config"

ansible-galaxy collection install ansible.posix community.general

ansible-pull -U "${ANSIBLE_REPO}" "${PLAYBOOK}"
