# Chrony NTP Client/Server

Modern NTP implementation for time synchronization. Chrony is designed for systems with intermittent network connectivity and is the default NTP client on modern Linux distributions.

## Features

- Fast initial time synchronization
- Client mode: sync time from NTP pools/servers
- Server mode: serve time to local network clients
- Automatic conflict resolution with systemd-timesyncd and ntpd
- Firewall integration for server mode

## Usage

### Client-only mode (default)

Sync time from public NTP pools, don't serve time to others:

```yaml
# host_vars/example.yml
ntp_timezone: "Europe/Paris"
ntp_pools:
  - "0.fr.pool.ntp.org"
  - "1.fr.pool.ntp.org"
  - "2.fr.pool.ntp.org"
  - "3.fr.pool.ntp.org"
```

### Server mode

Serve time to local network:

```yaml
# host_vars/ntp-server.yml
ntp_timezone: "UTC"
ntp_server_enabled: true
ntp_allowed_networks:
  - 192.168.1.0/24  # Configures both chrony and firewall
  - 192.168.27.0/27
```

### Client syncing from local server

```yaml
# host_vars/client.yml
ntp_pools: []  # Don't use public pools
ntp_servers:
  - server: ntp.local.lan
    options: iburst prefer
  - server: 192.168.1.1
    options: iburst
```

## Logging

**Default: journald** - Logs to systemd journal (recommended)

```bash
# View chrony logs
journalctl -u chronyd -f
```

**Optional: File-based logging** with automatic rotation

```yaml
ntp_log_backend: file
ntp_log_measurements: true
ntp_log_statistics: true
ntp_log_tracking: true
```

## Variables

See [defaults/main.yml](defaults/main.yml) for all configuration options.

## Verification

```bash
# Check chrony status
chronyc tracking

# Show current time sources
chronyc sources

# Show detailed source stats
chronyc sourcestats
```

## Resources

- [Arch Wiki: Chrony](https://wiki.archlinux.org/title/Chrony)
- [Chrony Documentation](https://chrony.tuxfamily.org/documentation.html)
