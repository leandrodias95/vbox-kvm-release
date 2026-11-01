#!/usr/bin/env bash
# vbox-kvm-monitor.sh - watch VirtualBoxVM; when it exits, run the cleanup.
PREV=0
while true; do
    if pgrep -f 'VirtualBoxVM' >/dev/null; then
        PREV=1
    elif [ "$PREV" -eq 1 ]; then
        "$HOME/.local/bin/vbox-close-cleanup.sh"
        PREV=0
    fi
    sleep 3
done
