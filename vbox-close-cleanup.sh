#!/usr/bin/env bash
# vbox-close-cleanup.sh - free KVM for Docker Desktop after a VirtualBox VM closes.
set -uo pipefail

LOG="${XDG_STATE_HOME:-$HOME/.local/state}/vbox-release-kvm.log"
mkdir -p "$(dirname "$LOG")"
log() { echo "$(date -Is) $*" >> "$LOG"; }

# Guard: never unload vboxdrv while a VirtualBox VM is still running.
if [ -n "$(VBoxManage list runningvms 2>/dev/null)" ] || pgrep -f 'VirtualBoxVM' >/dev/null; then
    log "aborted: a VirtualBox VM is still running."
    exit 0
fi

sleep 10

if pgrep -f 'VirtualBoxVM' >/dev/null || [ -n "$(VBoxManage list runningvms 2>/dev/null)" ]; then
    log "aborted (re-check): VM reopened during the debounce."
    exit 0
fi

sudo -n /usr/local/sbin/vbox-unload.sh || { log "failed to unload vboxdrv."; exit 1; }
systemctl --user restart docker-desktop
log "docker-desktop restarted."

for _ in $(seq 1 30); do
    if docker info >/dev/null 2>&1; then
        log "docker info OK ($(docker version --format '{{.Server.Version}}' 2>/dev/null))."
        exit 0
    fi
    sleep 2
done

log "warning: docker info did not answer within 60s."
exit 1
