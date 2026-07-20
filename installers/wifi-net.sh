#!/bin/bash
# installer: wifi-net — installs 99wifi-net dracut module and config.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

do_rebuild=true

usage() {
    cat <<EOF
Usage: $(basename "$0") [--no-rebuild]

Install the 99wifi-net dracut module for WiFi + Ethernet in initramfs.

Optional:
  --no-rebuild   Skip initramfs rebuild (caller manages it)
EOF
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --no-rebuild) do_rebuild=false; shift ;;
        *) usage ;;
    esac
done

install_dracut_module "99wifi-net"
write_dracut_config "wifi-net.conf" 'add_dracutmodules+=" network-manager "'

if $do_rebuild; then
    rebuild_initramfs
fi
