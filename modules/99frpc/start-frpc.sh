#!/usr/bin/sh
MAX_WAIT=120
start=$(cat /proc/uptime | cut -d. -f1)

while [ ! -f /tmp/net.ready ]; do
    now=$(cat /proc/uptime | cut -d. -f1)
    elapsed=$(( now - start ))
    [ $elapsed -ge $MAX_WAIT ] && break
    sleep 1
done

if ! pgrep frpc >/dev/null 2>&1; then
    ( while true; do /etc/frpc -c /etc/frpc.toml 2>&1; sleep 1; done ) &
fi
