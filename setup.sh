#!/bin/bash
# setup.sh — Install dracut modules for remote LUKS unlock via FRP + SSH.
# Default: installs all three modules (frpc, wifi-net, crypt-ssh) and
# configures FRP preboot with mTLS. Use --module for individual installs.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "$HERE/lib/common.sh"

# === Parse flags ===
modules=""
no_rebuild=false
frpc_config=""
frpc_cert=""
frpc_key=""
frpc_ca=""
frpc_version=""
ssh_user=""

usage() {
    cat <<'EOF'
Usage: sudo bash setup.sh [options]

Full install (all modules + FRP preboot with mTLS):
  sudo bash setup.sh \
      --frpc-config /path/to/frpc.toml \
      --frpc-cert   /path/to/client.crt \
      --frpc-key    /path/to/client.key \
      --frpc-ca     /path/to/ca.crt \
      --user imranr

Individual modules:
  sudo bash setup.sh --module frpc --frpc-config /path/to/frpc.toml
  sudo bash setup.sh --module wifi-net
  sudo bash setup.sh --module crypt-ssh --user imranr

Shared flags:
  --no-rebuild          Skip initramfs rebuild (caller manages it)
  --frpc-version <ver>  Pin frpc version (default: latest)

If no --module is given and --frpc-config is present, all modules install
with one rebuild at the end. Otherwise prints this help.
EOF
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --module)        modules="$modules${modules:+,}$2"; shift 2 ;;
        --no-rebuild)    no_rebuild=true; shift ;;
        --frpc-config)   frpc_config="$2"; shift 2 ;;
        --frpc-cert)     frpc_cert="$2"; shift 2 ;;
        --frpc-key)      frpc_key="$2"; shift 2 ;;
        --frpc-ca)       frpc_ca="$2"; shift 2 ;;
        --frpc-version)  frpc_version="$2"; shift 2 ;;
        --user)          ssh_user="$2"; shift 2 ;;
        -h|--help)       usage ;;
        *) echo "Unknown flag: $1" >&2; usage ;;
    esac
done

# Default to full install if frpc-config is present and no --module specified
if [ -z "$modules" ] && [ -n "$frpc_config" ]; then
    modules="frpc,wifi-net,crypt-ssh"
fi

if [ -z "$modules" ]; then
    echo "Error: specify --frpc-config for full install, or --module for individual modules" >&2
    usage
fi

# === Run installers ===
export FRPC_VERSION="${frpc_version:-}"
installed=""

for m in ${modules//,/ }; do
    echo ""
    echo "=== Installing module: $m ==="

    case "$m" in
        frpc)
            if [ -z "$frpc_config" ]; then
                echo "Error: --frpc-config is required for frpc module" >&2
                exit 1
            fi
            bash "$HERE/installers/frpc.sh" \
                --frpc-config "$frpc_config" \
                ${frpc_cert:+--frpc-cert "$frpc_cert"} \
                ${frpc_key:+--frpc-key "$frpc_key"} \
                ${frpc_ca:+--frpc-ca "$frpc_ca"} \
                --no-rebuild
            installed="$installed frpc"
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
            echo "Error: unknown module '$m'. Valid: frpc, wifi-net, crypt-ssh" >&2
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
