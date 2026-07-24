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

    # ---- install wireless firmware ------------------------------------------
    # instmods resolves firmware via modinfo, which lists the max API version
    # (e.g. iwlwifi-ty-a0-gf-a0-100.ucode).  The installed firmware package
    # may only contain lower versions (e.g. -89).  Without explicitly copying
    # the available firmware, the driver loads in the initramfs but fails the
    # firmware request and never recovers after pivot_root.  Walk every
    # wireless .ko that was actually included, derive a device prefix from
    # each firmware alias, and install every matching file on the host.
    local mod fw prefix
    for mod in $(find "$initdir" -path "*/drivers/net/wireless/*.ko*" -printf '%f\n' 2>/dev/null | sed 's/\.ko.*//' | sort -u); do
        for fw in $(modinfo -F firmware "$mod" 2>/dev/null); do
            prefix="${fw%.ucode}"
            prefix="${prefix%.pnvm}"
            prefix="${prefix%-[0-9]*}"
            prefix="${prefix%-c[0-9]*}"
            [ -n "$prefix" ] || continue
            for f in /lib/firmware/"${prefix}"*; do
                [ -f "$f" ] && inst "$f"
            done
        done
    done
    # ------------------------------------------------------------------------

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
