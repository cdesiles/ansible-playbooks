# sys_autoupdate

Automated system updates and Podman image updates with ntfy notifications.

Supports Arch Linux and Debian/Ubuntu. Deploys a Bash script + systemd timer that runs daily to:
1. Check for distro-specific news requiring manual intervention (Arch only)
2. Apply system updates (`pacman -Syu` / `apt-get dist-upgrade`)
3. Pull latest Podman images and restart pods with updated images
4. Send push notifications via ntfy.sh at each stage

## Configuration

See [defaults/main.yml](defaults/main.yml) for all variables.

Required in host vars:

```yaml
sys_autoupdate_ntfy_topic: your-notification-topic
```

## OS support

| OS | Update command | News check |
|----|---------------|------------|
| Arch Linux | `pacman -Syu --noconfirm` | archlinux.org/news |
| Debian/Ubuntu | `apt-get dist-upgrade -y` | None (stable release) |

OS-specific commands are defined in `vars/archlinux.yml` and `vars/debian.yml`, loaded automatically via `ansible_facts['os_family']`.

## Podman image updates

When `sys_autoupdate_podman_enabled: true` (default), the script scans `podman_projects_dir` for `docker-compose.yml` files, pulls images via `podman-compose pull`, and recreates containers with `podman-compose up -d` for projects with updated images. Dangling images are pruned after each run.

The script runs as root (for package management) and uses `sudo -u {{ ansible_user }}` for Podman operations to preserve rootless isolation.

## Notifications

| Tag | Meaning |
|-----|---------|
| `white_check_mark` | System update succeeded |
| `x` | Update or pod restart failed |
| `warning` | Distro news requires manual review (Arch) |
| `whale` | Podman images updated |
