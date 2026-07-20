#!/usr/bin/bash
check() { return 0; }
depends() { echo network-manager; return 0; }

install() {
    inst_dir /etc/NetworkManager/system-connections
    if [ -d /etc/NetworkManager/system-connections ]; then
        for f in /etc/NetworkManager/system-connections/*.nmconnection; do
            [ -f "$f" ] || continue
            inst "$f"
        done
    fi

    instmods =drivers/net/wireless

    local nm_ver
    nm_ver=${NM_VERSION:-$(NetworkManager --version)}
    inst_libdir_file "NetworkManager/$nm_ver/libnm-device-plugin-wifi.so"

    inst_multiple wpa_supplicant
    inst /usr/share/dbus-1/system-services/fi.w1.wpa_supplicant1.service
    inst /usr/share/dbus-1/system.d/wpa_supplicant.conf
    [ -f /etc/wpa_supplicant/wpa_supplicant.conf ] && inst /etc/wpa_supplicant/wpa_supplicant.conf

    if [ -f "$systemdsystemunitdir/wpa_supplicant.service" ]; then
        inst "$systemdsystemunitdir/wpa_supplicant.service"
        sed -i -e \
            '/^\[Unit\]/aDefaultDependencies=no\nConflicts=shutdown.target\nBefore=shutdown.target\nAfter=dbus.service' \
            "$initdir/$systemdsystemunitdir/wpa_supplicant.service"
        mkdir -p "$initdir/etc/systemd/system/initrd.target.wants"
        ln -sf "$systemdsystemunitdir/wpa_supplicant.service" \
            "$initdir/etc/systemd/system/initrd.target.wants/wpa_supplicant.service"
    fi

    inst_hook initqueue 10 "$moddir/wait-for-network.sh"
}
