#!/usr/bin/sh
# Wait for the network, then bring up the public-exposure tunnel interface
# (pubexp-pre0) with the embedded WireGuard config. Addressed separately here
# because wg setconf does not understand Address/MTU/wg-quick keys.
MAX_WAIT=120
start=$(cat /proc/uptime | cut -d. -f1)

while [ ! -f /tmp/net.ready ]; do
    now=$(cat /proc/uptime | cut -d. -f1)
    elapsed=$(( now - start ))
    [ $elapsed -ge $MAX_WAIT ] && break
    sleep 1
done

IF=pubexp-pre0
ip link show "$IF" >/dev/null 2>&1 || ip link add "$IF" type wireguard
wg setconf "$IF" /etc/wireguard/pubexp-pre0.wg
ip addr replace 10.99.0.4/32 dev "$IF"
ip link set mtu 1280 up dev "$IF"
ip route replace 10.99.0.1/32 dev "$IF"
