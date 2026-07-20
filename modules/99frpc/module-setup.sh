#!/usr/bin/bash
check() { return 0; }
depends() { echo network; return 0; }

install() {
    inst "$moddir"/frpc /etc/frpc
    inst "$moddir"/frpc.toml /etc/frpc.toml

    if [ -f "$moddir"/ca.crt ]; then
        inst "$moddir"/ca.crt /etc/frp/ca.crt
    fi
    if [ -f "$moddir"/client.crt ]; then
        inst "$moddir"/client.crt /etc/frp/client.crt
    fi
    if [ -f "$moddir"/client.key ]; then
        inst "$moddir"/client.key /etc/frp/client.key
    fi

    inst_hook initqueue 20 "$moddir/start-frpc.sh"
    inst_hook cleanup 05 "$moddir/stop-frpc.sh"
}
