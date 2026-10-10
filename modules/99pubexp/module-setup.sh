#!/usr/bin/bash
check() { return 0; }
depends() { echo network; return 0; }

install() {
    inst_multiple wg ip
    instmods wireguard
    inst "$moddir"/pubexp-pre0.wg /etc/wireguard/pubexp-pre0.wg
    inst_hook initqueue 20 "$moddir/start-pubexp.sh"
    inst_hook cleanup 05 "$moddir/stop-pubexp.sh"
}
