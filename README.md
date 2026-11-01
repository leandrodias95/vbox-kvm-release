# vbox-kvm-release

Free `/dev/kvm` for **Docker Desktop** automatically when a **VirtualBox** VM
closes, so the two can share a KVM-capable Linux host without the recurring
`vmread/vmwrite failed` crash.

## Why

On a host with KVM, **VirtualBox (`vboxdrv`) and Docker Desktop's QEMU VM cannot
run at the same time**: when `vboxdrv` opens `/dev/kvm`, the Docker Desktop VM
can die with `kvm_intel: vmread/vmwrite failed`, and then the Docker Desktop UI
returns **HTTP 500** (its API proxy cannot reach the engine VM). Starting the
Desktop again fixes it until the next collision.

This project makes the transition automatic:

- **On VM close** (save state **or** power off), a monitor detects that
  `VirtualBoxVM` exited, **unloads the VirtualBox kernel modules**
  (`vboxnetadp`, `vboxnetflt`, `vboxdrv`), **restarts Docker Desktop**, and waits
  for the engine to answer.

It does **not** try to make both VMs run simultaneously: that is a hardware
limitation (KVM is exclusive). Use Docker with the VirtualBox VM closed; this
tool handles the rest.

## How it works

```
 VirtualBoxVM exits (save / poweroff)
        │
        ▼
 vbox-kvm-monitor.service  (user, polls the process)
        │  debounce + guard (no VM running)
        ▼
 vbox-close-cleanup.sh
        ├─ sudo -n /usr/local/sbin/vbox-unload.sh   (root: modprobe -r vbox*)
        ├─ systemctl --user restart docker-desktop
        └─ wait for `docker info`
```

Components:

| File | Purpose |
|------|---------|
| `vbox-unload.sh` | Root helper: unloads `vboxnetadp`, `vboxnetflt`, `vboxdrv` (no arguments, so it cannot be abused to unload arbitrary modules). |
| `vbox-kvm-release.sudoers` | Grants the user `NOPASSWD` for that one helper only. |
| `vbox-close-cleanup.sh` | User script: guard (no VM running) + debounce, then unload + restart Docker Desktop + wait. |
| `vbox-kvm-monitor.sh` | User monitor loop: fires the cleanup when `VirtualBoxVM` disappears. |
| `vbox-kvm-monitor.service` | systemd user unit that runs the monitor. |
| `docker-desktop-autostart.desktop` | GNOME autostart: starts Docker Desktop at login (not at boot, to avoid the GDM loop). |

## Requirements

- Linux with systemd (user services)
- VirtualBox and Docker Desktop installed
- The user in the `kvm` group (to use `/dev/kvm`)

## Install

1. Root helper and sudoers:

   ```bash
   sudo install -m 0750 -o root -g root vbox-unload.sh /usr/local/sbin/vbox-unload.sh
   sudo install -m 0440 -o root -g root vbox-kvm-release.sudoers /etc/sudoers.d/vbox-kvm-release
   sudo visudo -cf /etc/sudoers.d/vbox-kvm-release
   ```

   Edit the sudoers line if your user is not `leandro`.

2. User scripts and unit:

   ```bash
   install -m 0755 vbox-close-cleanup.sh vbox-kvm-monitor.sh ~/.local/bin/
   mkdir -p ~/.config/systemd/user
   install -m 0644 vbox-kvm-monitor.service ~/.config/systemd/user/
   systemctl --user daemon-reload
   systemctl --user enable --now vbox-kvm-monitor.service
   ```

3. Autostart of Docker Desktop at login:

   ```bash
   mkdir -p ~/.config/autostart
   install -m 0644 docker-desktop-autostart.desktop ~/.config/autostart/
   ```

4. (Optional) If you also run the native `dockerd`, disable it so there is a
   single engine:

   ```bash
   sudo systemctl disable --now docker.socket docker.service containerd.service
   ```

   This keeps `/var/lib/docker` and its images/containers untouched.

## Behaviour

- **Save state** and **power off** are treated the same: both end the
  `VirtualBoxVM` process.
- The **guard** prevents unloading `vboxdrv` while a VM is still running (which
  would corrupt it).
- The **debounce** avoids acting if the VM is reopened right away.
- **Docker Desktop is restarted** (containers with a restart policy come back).
- **After a reboot** everything is re-armed: `vboxdrv` is not loaded at boot, the
  monitor starts (lingering) or at login, and Docker Desktop starts at login.

## Notes

- If the KVM state is wedged, restarting Docker Desktop (or a reboot) recovers
  it.
- The restriction is physical: a VirtualBox VM and the Docker Desktop VM cannot
  run simultaneously on the same KVM host.

## Tested on

Ubuntu (base system), on a generic test machine.

## Author

**Leandro** — Product Engineer and founder of **Spartanus Gestão Inteligente**.

## License

MIT. See [LICENSE](LICENSE).
