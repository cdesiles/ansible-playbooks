# Fail2ban

Bans brute-force sources via UFW. Reads logs from the systemd journal (`backend = systemd`), so it works on both Arch and Debian.

## Jails

- `sshd`
- `nginx-http-auth`

## Notes

- Logs to the journal (`logtarget = STDOUT` in `fail2ban.local`) — see `journalctl -u fail2ban`.
- The systemd unit is hardened (`ProtectSystem=full`); the drop-in lives at `/etc/systemd/system/fail2ban.service.d/override.conf` and is fully managed by the role.
- Firewall/banaction is UFW on every host; jails ban via `ufw prepend deny` (DROP — no kernel `REJECT` extension needed, and it doesn't reveal the host to attackers).

## Variables

See [defaults/main.yml](defaults/main.yml).

## Prometheus exporter

Optionally exposes fail2ban metrics (`f2b_*`) for Prometheus via
[hectorjsmith/fail2ban-prometheus-exporter](https://gitlab.com/hectorjsmith/fail2ban-prometheus-exporter).

```yaml
fail2ban_exporter_enabled: true
```

Downloads the checksum-verified static binary to `/usr/local/bin` and runs it
as a hardened root systemd service (required to read the root-owned socket) on
`{{ fail2ban_exporter_listen_address }}` (default `127.0.0.1:9191`).

## Verify

```bash
sudo fail2ban-client status
sudo fail2ban-client set sshd banip 192.0.2.1 && sudo ufw status | grep 192.0.2.1
sudo fail2ban-client set sshd unbanip 192.0.2.1
```
