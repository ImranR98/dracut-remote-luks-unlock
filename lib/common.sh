#!/bin/bash
# Shared helpers for dracut-remote-luks-unlock installers.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
CACHE_DIR="$HERE/cache"
MODULES_BASE="/usr/lib/dracut/modules.d"

abort_if_root_only() {
    local path="$1" label="${2:-$path}"
    if [ ! -w "$path" ]; then
        echo "Error: cannot write to $label ($path). Use sudo or run0." >&2
        exit 1
    fi
}

rebuild_initramfs() {
    echo "=== Rebuilding initramfs ==="
    if command -v rpm-ostree >/dev/null 2>&1; then
        rpm-ostree initramfs --enable || true
        rpm-ostree initramfs || true
    else
        dracut --force
    fi
}

install_dracut_module() {
    local name="$1"
    local src="$HERE/modules/$name"
    local dest="$MODULES_BASE/$name"

    if [ ! -w "$MODULES_BASE" ]; then
        dest="/etc/dracut/modules.d/$name"
    fi

    mkdir -p "$dest"
    abort_if_root_only "$(dirname "$dest")" "dracut module directory"

    rm -rf "$dest"
    mkdir -p "$dest"
    cp "$src"/* "$dest"
    chmod +x "$dest"/*.sh 2>/dev/null || true
    echo "Installed dracut module: $name -> $dest"
}

write_dracut_config() {
    local name="$1" content="$2"
    local conf="/etc/dracut.conf.d/$name"
    printf '%s\n' "$content" > "$conf"
    echo "Installed dracut config: $conf"
}
