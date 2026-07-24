#!/bin/bash
# installer: frpc — downloads/caches frpc binary, installs 99frpc dracut module.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

frpc_config=""
frpc_cert=""
frpc_key=""
frpc_ca=""
frpc_version="${FRPC_VERSION:-}"
do_rebuild=true

usage() {
    cat <<EOF
Usage: $(basename "$0") --frpc-config <path> [flags]

Required:
  --frpc-config <path>   Path to frpc.toml to embed in initramfs

Optional:
  --frpc-cert <path>     Path to client TLS certificate
  --frpc-key <path>      Path to client TLS private key
  --frpc-ca <path>       Path to CA certificate
  --frpc-version <ver>   Pin frpc version (default: latest from GitHub)
  --no-rebuild           Skip initramfs rebuild (caller manages it)
EOF
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --frpc-config)  frpc_config="$2"; shift 2 ;;
        --frpc-cert)    frpc_cert="$2"; shift 2 ;;
        --frpc-key)     frpc_key="$2"; shift 2 ;;
        --frpc-ca)      frpc_ca="$2"; shift 2 ;;
        --frpc-version) frpc_version="$2"; shift 2 ;;
        --no-rebuild)   do_rebuild=false; shift ;;
        *) usage ;;
    esac
done

[ -n "$frpc_config" ] || { echo "Error: --frpc-config is required" >&2; usage; }
[ -f "$frpc_config" ] || { echo "Error: frpc config not found: $frpc_config" >&2; exit 1; }

# Determine version
if [ -z "$frpc_version" ]; then
    frpc_version=$(curl -sf https://api.github.com/repos/fatedier/frp/releases/latest | grep -oP '"tag_name":\s*"v\K[^"]+') || true
    [ -n "$frpc_version" ] || { echo "Error: could not determine latest frpc version" >&2; exit 1; }
fi

# Cache and install frpc binary
frpc_cache="$CACHE_DIR/frpc-v$frpc_version"
frpc_module_dir="$MODULES_BASE/99frpc"

if [ ! -x "$frpc_cache" ]; then
    echo "Downloading frpc v$frpc_version..."
    tmp="$(mktemp -d)"
    trap 'rm -rf "$tmp"' EXIT
    fname="frp_${frpc_version}_linux_amd64.tar.gz"
    curl -sfL "https://github.com/fatedier/frp/releases/download/v${frpc_version}/$fname" -o "$tmp/$fname"
    tar -xf "$tmp/$fname" -C "$tmp"
    mkdir -p "$CACHE_DIR"
    cp "$tmp/frp_${frpc_version}_linux_amd64/frpc" "$frpc_cache"
    chmod +x "$frpc_cache"
    rm -rf "$tmp"
    # Remove old cached versions except the current one
    find "$CACHE_DIR" -name 'frpc-v*' ! -name "frpc-v$frpc_version" -delete 2>/dev/null || true
    echo "Cached frpc v$frpc_version"
fi

# Install dracut module
install_dracut_module "99frpc"

# Copy frpc binary and config into the installed module
cp "$frpc_cache" "$frpc_module_dir/frpc"
chmod +x "$frpc_module_dir/frpc"
cp "$frpc_config" "$frpc_module_dir/frpc.toml"

# Copy TLS certs if provided
if [ -n "$frpc_ca" ] && [ -f "$frpc_ca" ]; then
    cp "$frpc_ca" "$frpc_module_dir/ca.crt"
fi
if [ -n "$frpc_cert" ] && [ -f "$frpc_cert" ]; then
    cp "$frpc_cert" "$frpc_module_dir/client.crt"
fi
if [ -n "$frpc_key" ] && [ -f "$frpc_key" ]; then
    cp "$frpc_key" "$frpc_module_dir/client.key"
fi

if $do_rebuild; then
    rebuild_initramfs
fi
