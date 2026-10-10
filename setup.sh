#!/bin/bash
# setup.sh — Install dracut modules for remote LUKS unlock via WireGuard + SSH.
# Default: installs all three modules (pubexp, wifi-net, crypt-ssh) and
# configures the public-exposure tunnel. Use --module for individual installs.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "$HERE/lib/common.sh"

# === Parse flags ===
modules=""
no_rebuild=false
pubexp_conf=""
ssh_user=""

usage() {
    cat <<'EOF'
Usage: sudo bash setup.sh [options]

Full install (all modules + public-exposure tunnel):
  sudo bash setup.sh \
      --pubexp-conf /path/to/pubexp-pre0.wg \
      --user imranr

Individual modules:
  sudo bash setup.sh --module pubexp --pubexp-conf /path/to/pubexp-pre0.wg
  sudo bash setup.sh --module wifi-net
  sudo bash setup.sh --module crypt-ssh --user imranr

Shared flags:
  --no-rebuild          Skip initramfs rebuild (caller manages it)

If no --module is given and --pubexp-conf is present, all modules install
with one rebuild at the end. Otherwise prints this help.
EOF
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --module)       modules="$modules${modules:+,}$2"; shift 2 ;;
        --no-rebuild)   no_rebuild=true; shift ;;
        --pubexp-conf)  pubexp_conf="$2"; shift 2 ;;
        --user)         ssh_user="$2"; shift 2 ;;
        -h|--help)      usage ;;
        *) echo "Unknown flag: $1" >&2; usage ;;
    esac
done

# Default to full install if pubexp-conf is present and no --module specified
if [ -z "$modules" ] && [ -n "$pubexp_conf" ]; then
    modules="pubexp,wifi-net,crypt-ssh"
fi

if [ -z "$modules" ]; then
    echo "Error: specify --pubexp-conf for full install, or --module for individual modules" >&2
    usage
fi

# === Run installers ===
installed=""

for m in ${modules//,/ }; do
    echo ""
    echo "=== Installing module: $m ==="

    case "$m" in
        pubexp)
            if [ -z "$pubexp_conf" ]; then
                echo "Error: --pubexp-conf is required for pubexp module" >&2
                exit 1
            fi
            bash "$HERE/installers/pubexp.sh" \
                --pubexp-conf "$pubexp_conf" \
                --no-rebuild
            installed="$installed pubexp"
            ;;
        wifi-net)
            bash "$HERE/installers/wifi-net.sh" --no-rebuild
            installed="$installed wifi-net"
            ;;
        crypt-ssh)
            if [ -z "$ssh_user" ]; then
                echo "Error: --user is required for crypt-ssh module" >&2
                exit 1
            fi
            bash "$HERE/installers/crypt-ssh.sh" --user "$ssh_user" --no-rebuild
            installed="$installed crypt-ssh"
            ;;
        *)
            echo "Error: unknown module '$m'. Valid: pubexp, wifi-net, crypt-ssh" >&2
            exit 1
            ;;
    esac
done

echo ""
echo "=== Installed modules:$installed ==="

# Single rebuild at the end
if ! $no_rebuild; then
    rebuild_initramfs
else
    echo "Skipping rebuild (--no-rebuild)"
fi

echo ""
echo "=== Done ==="
echo "Remote LUKS unlock will be available on next boot."
