#!/usr/bin/sh
MAX_WAIT=90
start=$(cat /proc/uptime | cut -d. -f1)

while true; do
    [ -f /tmp/net.ready ] && return 0
    now=$(cat /proc/uptime | cut -d. -f1)
    elapsed=$(( now - start ))
    [ $elapsed -ge $MAX_WAIT ] && break

    for iface in /sys/class/net/*; do
        [ -d "$iface" ] || continue
        name=${iface##*/}
        [ "$name" = "lo" ] && continue
        if ip -4 addr show "$name" 2>/dev/null | grep -q "inet "; then
            > /tmp/net.ready
            return 0
        fi
    done
    sleep 2
done

> /tmp/net.ready
return 0
