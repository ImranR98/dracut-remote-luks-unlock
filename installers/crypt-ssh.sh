#!/bin/bash
# installer: crypt-ssh — installs dracut-crypt-ssh package, SSH keys, and config.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

ssh_user=""
do_rebuild=true

usage() {
    cat <<EOF
Usage: $(basename "$0") --user <username> [--no-rebuild]

Install and configure dracut-crypt-ssh with ed25519 keys.

Required:
  --user <username>   User whose authorized_keys to copy into initramfs

Optional:
  --no-rebuild        Skip initramfs rebuild (caller manages it)
EOF
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --user)        ssh_user="$2"; shift 2 ;;
        --no-rebuild)  do_rebuild=false; shift ;;
        *) usage ;;
    esac
done

[ -n "$ssh_user" ] || { echo "Error: --user is required" >&2; usage; }

# Install dracut-crypt-ssh package
if command -v rpm-ostree >/dev/null 2>&1; then
    local fedora_ver
    fedora_ver=$(rpm -E %fedora)
    wget -nv "https://copr.fedorainfracloud.org/coprs/uriesk/dracut-crypt-ssh/repo/fedora-${fedora_ver}/uriesk-dracut-crypt-ssh-fedora-${fedora_ver}.repo" \
        -O /etc/yum.repos.d/dracut-crypt-ssh.repo || true
    rpm-ostree initramfs --enable || true
    rpm-ostree refresh-md || true
    if ! rpm-ostree status | grep -q dracut-crypt-ssh; then
        rpm-ostree install --apply-live --assumeyes dracut-crypt-ssh || true
    fi
else
    dnf copr enable uriesk/dracut-crypt-ssh -y
    dnf install dracut-crypt-ssh -y
fi

# Add rd.neednet=1 to kernel cmdline if not present
if command -v rpm-ostree >/dev/null 2>&1; then
    if ! rpm-ostree kargs | grep -q neednet; then
        rpm-ostree kargs --append "rd.neednet=1 ip=dhcp" || true
    fi
else
    if ! grep -q "rd.neednet=1" /proc/cmdline 2>/dev/null; then
        grubby --update-kernel=ALL --args="rd.neednet=1 ip=dhcp" || true
    fi
fi

# Generate ed25519 SSH host key
mkdir -p /etc/dracut-crypt-ssh-keys
if [ ! -f /etc/dracut-crypt-ssh-keys/ssh_dracut_ed25519_key ]; then
    ssh-keygen -t ed25519 -m PEM -f /etc/dracut-crypt-ssh-keys/ssh_dracut_ed25519_key -N "" \
        || { echo "Error: failed to generate ed25519 key" >&2; exit 1; }
fi

# Copy user's authorized_keys
mkdir -p /etc/.ssh
if [ -f "/home/$ssh_user/.ssh/authorized_keys" ]; then
    cp "/home/$ssh_user/.ssh/authorized_keys" /etc/.ssh/
fi

# Install pre-configured crypt-ssh.conf
cp "$HERE/../modules/99crypt-ssh/crypt-ssh.conf" /etc/dracut.conf.d/crypt-ssh.conf

if $do_rebuild; then
    rebuild_initramfs
fi
