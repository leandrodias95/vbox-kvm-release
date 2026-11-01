#!/usr/bin/env bash
# vbox-unload.sh - unload the VirtualBox kernel modules to free /dev/kvm.
# Intentionally takes NO arguments: it can only unload the VirtualBox modules,
# never arbitrary modules (avoids a privilege-escalation path via sudoers).
set -euo pipefail

modprobe -r vboxnetadp 2>/dev/null || true
modprobe -r vboxnetflt 2>/dev/null || true
modprobe -r vboxdrv     2>/dev/null || true

if lsmod | grep -q '^vboxdrv'; then
    echo "WARNING: vboxdrv still loaded (in use). Abort if a VM is running." >&2
    exit 1
fi
echo "vboxdrv unloaded."
