#!/bin/bash
# installer: pubexp — installs the 99pubexp dracut module (WireGuard preboot client).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

pubexp_conf=""
do_rebuild=true

usage() {
    cat <<EOF
Usage: $(basename "$0") --pubexp-conf <path> [--no-rebuild]

Required:
  --pubexp-conf <path>   WireGuard config (wg setconf format) to embed

Optional:
  --no-rebuild           Skip initramfs rebuild (caller manages it)
EOF
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --pubexp-conf) pubexp_conf="$2"; shift 2 ;;
        --no-rebuild)  do_rebuild=false; shift ;;
        *) usage ;;
    esac
done

[ -n "$pubexp_conf" ] || { echo "Error: --pubexp-conf is required" >&2; usage; }
[ -f "$pubexp_conf" ] || { echo "Error: conf not found: $pubexp_conf" >&2; exit 1; }

install_dracut_module "99pubexp"
write_dracut_config "pubexp.conf" 'add_dracutmodules+=" pubexp "'
cp "$pubexp_conf" "$MODULES_BASE/99pubexp/pubexp-pre0.wg"
chmod 600 "$MODULES_BASE/99pubexp/pubexp-pre0.wg"

if $do_rebuild; then
    rebuild_initramfs
fi
