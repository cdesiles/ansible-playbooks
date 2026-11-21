# WireGuard

Installs WireGuard and manages `wg-quick` tunnels from `wireguard_tunnels`
(see `defaults/main.yml` for the full schema).

- **Linux** — server (`server_mode: true`) or client. Server mode enables
  masquerade + UFW rules; tunnels are managed by `wg-quick@<iface>.service`.
- **macOS (Darwin)** — client only, via Homebrew `wireguard-tools` +
  `wireguard-go`. No systemd/UFW/sysctl: the config is rendered to
  `{{ wireguard_config_base_path }}` (`/etc/wireguard`) and brought up with
  `wg-quick`.
- **DNS** — wg-quick only touches `/etc/resolv.conf` when a tunnel defines
  `dns:`. Set `wireguard_manage_dns: false` on minimal hosts that have no
  `resolvconf`/`systemd-resolved` and do not need DNS over the tunnel; the role
  then skips installing the resolver shim.

## Verify

```sh
sudo wg show                      # Linux
sudo /opt/homebrew/bin/wg show    # macOS (or add /opt/homebrew/bin to sudo secure_path)
```
