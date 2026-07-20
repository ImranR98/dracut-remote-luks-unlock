#!/usr/bin/sh
while [ ! -f /tmp/net.ready ]; do
    sleep 1
done

if ! pgrep frpc >/dev/null 2>&1; then
    ( while true; do /etc/frpc -c /etc/frpc.toml 2>&1; sleep 1; done ) &
fi
