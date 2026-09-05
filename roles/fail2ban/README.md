# Fail2ban

Bans brute-force sources via UFW. Reads logs from the systemd journal (`backend = systemd`), so it works on both Arch and Debian.

## Jails

- `sshd`
- `nginx-http-auth`

## Notes

- Logs to the journal (`logtarget = STDOUT` in `fail2ban.local`) — see `journalctl -u fail2ban`.
- The systemd unit is hardened (`ProtectSystem=strict`); the drop-in lives at `/etc/systemd/system/fail2ban.service.d/override.conf` and is fully managed by the role.
- Firewall/banaction is UFW on every host; jails ban via `ufw prepend reject`.

## Variables

See [defaults/main.yml](defaults/main.yml).

## Verify

```bash
sudo fail2ban-client status
sudo fail2ban-client set sshd banip 192.0.2.1 && sudo ufw status | grep 192.0.2.1
sudo fail2ban-client set sshd unbanip 192.0.2.1
```
