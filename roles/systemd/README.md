# Systemd Role

Manages systemd-journald configuration for efficient log management and storage control.

## Overview

This role configures systemd's journal daemon (`systemd-journald`) to control log storage, retention, and rotation. It's designed to prevent excessive disk usage from system logs while maintaining sufficient logging for troubleshooting.

## Hands-on commands

```bash
# Disk usage
sudo journalctl --disk-usage

# Current configuration
systemctl show systemd-journald

# Verify configuration
sudo journalctl --verify

# Manual cleanup by time
sudo journalctl --vacuum-time=2weeks

# Manual cleanup by size
sudo journalctl --vacuum-size=500M

# Manual cleanup by file count
sudo journalctl --vacuum-files=10
```

## References

- [journald.conf(5) man page](https://www.freedesktop.org/software/systemd/man/journald.conf.html)
- [systemd-journald.service(8)](https://www.freedesktop.org/software/systemd/man/systemd-journald.service.html)
- [journalctl(1) man page](https://www.freedesktop.org/software/systemd/man/journalctl.html)
- [Arch Wiki: systemd/Journal](https://wiki.archlinux.org/title/Systemd/Journal)
