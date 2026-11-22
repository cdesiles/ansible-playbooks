# sys_autoupdate

Automated system updates and Podman image updates with ntfy notifications.

Supports Arch Linux and Debian/Ubuntu. Deploys a Bash script + systemd timer that runs daily to:
1. Check for distro-specific news requiring manual intervention (Arch only)
2. Apply system updates (`pacman -Syu` / `apt-get dist-upgrade` or `upgrade`)
3. Pull latest Podman images and restart pods with updated images
4. Send push notifications via ntfy.sh at each stage

Variables: [defaults/main.yml](defaults/main.yml)

The ntfy server, topic and token are rendered to `sys_autoupdate_env_path` (`0600`, `no_log`) and sourced by the script, so the token never lands in the world-readable script or in `--diff` output.

## OS support

| OS | Update command | News check |
|----|---------------|------------|
| Arch Linux | `pacman -Syu --noconfirm` | archlinux.org/news |
| Debian/Ubuntu | `apt-get dist-upgrade -y` (or `upgrade`, see below) | None (stable release) |

OS-specific commands are defined in `vars/archlinux.yml` and `vars/debian.yml`, loaded automatically via `ansible_facts['os_family']`.

## Debian/Ubuntu

- **Conffiles:** dpkg runs with `--force-confdef --force-confold`: locally modified conffiles (Ansible- or vendor-managed) are kept, untouched ones take the package version. Without them dpkg prompts, hits EOF on stdin and leaves the package half-configured.
- **`upgrade` vs `dist-upgrade`** (`sys_autoupdate_apt_upgrade_command`): `upgrade` never installs nor removes a package, so changes that need it stay kept back. Raspberry Pi kernels ship as a new versioned package behind `linux-image-rpi-*`, so `upgrade` leaves the kernel to whoever owns it. Use it on appliances that pin their kernel ([moOde](../moode/README.md#debian-package-updates)).
- **Required holds** (`sys_autoupdate_required_holds`): checked at the start of the run and again right before the upgrade; the run is skipped, with a `warning` notification, while any listed package is not on hold. Use it when another tool owns holds and lifts them temporarily (moOde's in-place updater restores its holds only when it succeeds).

## Excluding packages from auto-update

Set `sys_autoupdate_ignore_packages` to a list of package names to hold back. Useful when running out-of-tree kernel modules (ZFS DKMS, Nvidia, VirtualBox) that must stay in lockstep with the kernel.

```yaml
# Arch with ZFS DKMS
sys_autoupdate_ignore_packages:
  - linux
  - linux-headers
  - zfs-dkms
  - zfs-utils
```

Translation per OS:

- **Arch:** passed as `pacman --ignore=pkg1,pkg2` on each run. Held packages are also filtered out of the pending-update detection.
- **Debian/Ubuntu:** reconciled via `apt-mark hold` at role-apply time. Holds added by this role are not automatically released when removed from the list — run `sudo apt-mark unhold <package>` to release them manually.

**Warning:** when holding the kernel, also hold matching headers and any DKMS modules together. Holding the kernel while letting `zfs-dkms` advance can break the DKMS build on next boot.

## Podman image updates

When `sys_autoupdate_podman_enabled: true` (default), the script scans `podman_projects_dir` for `docker-compose.yml` files, pulls images via `podman-compose pull`, and recreates containers with `podman-compose up -d` for projects with updated images. Dangling images are pruned after each run.

The script runs as root (for package management) and uses `sudo -u {{ ansible_user }}` for Podman operations to preserve rootless isolation.

## Notifications

| Tag | Meaning |
|-----|---------|
| `white_check_mark` | System update succeeded |
| `x` | Update or pod restart failed (the body carries the last lines of output) |
| `warning` | Distro news requires manual review (Arch), or required holds missing, run skipped (Debian) |
| `whale` | Podman images updated |
| `arrows_counterclockwise` | Running kernel older than installed — reboot pending (notified weekly, `sys_autoupdate_reboot_notify_weekday`) |
