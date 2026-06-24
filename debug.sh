#!/bin/bash
# Post-provision diagnostic script

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

pass() { echo -e "  ${GREEN}✓${RESET} $1"; }
fail() { echo -e "  ${RED}✗${RESET} $1"; }
warn() { echo -e "  ${YELLOW}!${RESET} $1"; }
header() { echo -e "\n${BOLD}=== $1 ===${RESET}"; }

TARGET_USER="sigil"

# ── System ────────────────────────────────────────────────────────────────────
header "System"
echo "  Hostname:  $(hostname)"
echo "  OS:        $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
echo "  Kernel:    $(uname -r)"
echo "  Uptime:    $(uptime -p)"
echo "  Disk:      $(df -h / | awk 'NR==2 {print $3 " used / " $2 " total (" $5 ")"}')"

# ── Locale & Timezone ─────────────────────────────────────────────────────────
header "Locale & Timezone"
LANG_VAL=$(grep '^LANG=' /etc/default/locale 2>/dev/null | cut -d= -f2 | tr -d '"')
TZ_VAL=$(timedatectl show --property=Timezone --value 2>/dev/null)

[[ "$LANG_VAL" == "en_CA.UTF-8" ]] \
    && pass "Locale: $LANG_VAL" \
    || fail "Locale: ${LANG_VAL:-not set} (expected en_CA.UTF-8)"
[[ "$TZ_VAL" == "America/Toronto" ]] \
    && pass "Timezone: $TZ_VAL" \
    || fail "Timezone: ${TZ_VAL:-not set} (expected America/Toronto)"
locale -a 2>/dev/null | grep -qi "en_CA.utf" \
    && pass "en_CA.UTF-8 generated" \
    || fail "en_CA.UTF-8 not generated"

# ── Apt Sources ───────────────────────────────────────────────────────────────
header "Apt Sources"
grep -rh "forky" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | grep -q "forky" \
    && pass "Forky sources present" || fail "Forky sources not found"
grep -rh "bookworm\|bullseye\|buster" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | grep -q . \
    && fail "Old release sources still present" || pass "No stale release sources"

# ── Packages ──────────────────────────────────────────────────────────────────
header "Packages"
EXPECTED=(curl git vim tmux bat btop htop jq nala fastfetch cowsay tree docker-ce ansible-core localepurge)
for pkg in "${EXPECTED[@]}"; do
    dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" && pass "$pkg" || fail "$pkg not installed"
done

# ── Services ──────────────────────────────────────────────────────────────────
header "Services"
for svc in ssh cron docker; do
    systemctl is-active  --quiet "$svc" && pass "$svc running" || fail "$svc not running"
    systemctl is-enabled --quiet "$svc" 2>/dev/null && pass "$svc enabled" || warn "$svc not enabled"
done

# ── User & Groups ─────────────────────────────────────────────────────────────
header "User & Groups"
id "$TARGET_USER" &>/dev/null \
    && pass "User $TARGET_USER exists" || fail "User $TARGET_USER missing"
id -nG "$TARGET_USER" 2>/dev/null | grep -qw sudo \
    && pass "$TARGET_USER in sudo group"   || fail "$TARGET_USER not in sudo group"
id -nG "$TARGET_USER" 2>/dev/null | grep -qw docker \
    && pass "$TARGET_USER in docker group" || fail "$TARGET_USER not in docker group"

# ── Dotfiles ──────────────────────────────────────────────────────────────────
header "Dotfiles"
DOTFILES_DIR="/home/${TARGET_USER}/repos/dotfiles"
[[ -d "$DOTFILES_DIR" ]] \
    && pass "Dotfiles repo cloned" || fail "Dotfiles repo missing at $DOTFILES_DIR"

EXPECTED_LINKS=(.profile .bash_aliases .vimrc .gitconfig .tmux.conf .inputrc)
for f in "${EXPECTED_LINKS[@]}"; do
    target="/home/${TARGET_USER}/$f"
    if [[ -L "$target" ]]; then
        pass "$f → $(readlink "$target")"
    elif [[ -e "$target" ]]; then
        warn "$f exists but is not a symlink"
    else
        fail "$f missing"
    fi
done

[[ -d "/home/${TARGET_USER}/.tmux/plugins/tpm" ]] \
    && pass "TPM installed" || fail "TPM missing"

# ── Docker ────────────────────────────────────────────────────────────────────
header "Docker"
if systemctl is-active --quiet docker; then
    docker info --format '  Version:   {{.ServerVersion}}' 2>/dev/null
    echo "  Containers running: $(docker ps -q 2>/dev/null | wc -l)"
    [[ -d /opt/docker ]] && pass "/opt/docker exists" || fail "/opt/docker missing"
else
    warn "Docker not running, skipping"
fi

# ── Ansible Pull ──────────────────────────────────────────────────────────────
header "Ansible Pull"
PULL_DIR=$(find /root/.ansible/pull -maxdepth 1 -mindepth 1 -type d 2>/dev/null | head -1)
if [[ -n "$PULL_DIR" ]]; then
    pass "Repo cloned at $PULL_DIR"
    echo "  Commit: $(git -C "$PULL_DIR" rev-parse --short HEAD 2>/dev/null)"
else
    fail "No ansible-pull checkout found"
fi

if [[ -f /var/log/cloud-init-output.log ]]; then
    RECAP=$(grep -A2 "PLAY RECAP" /var/log/cloud-init-output.log | tail -3)
    [[ -n "$RECAP" ]] && echo "$RECAP" | sed 's/^/  /' || warn "No PLAY RECAP in cloud-init log"
fi

echo ""
