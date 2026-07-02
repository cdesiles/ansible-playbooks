# UniFi Controller

Deploys the [UniFi Network Controller](https://ui.com/) via rootless Podman using the [`jacobalberty/unifi`](https://github.com/jacobalberty/unifi-docker) image (embedded MongoDB, no external DB required).

## Configuration

See [defaults/main.yml](defaults/main.yml) for all variables.

### Required variables (inventory)

| Variable | Description | Example |
|---|---|---|
| `unifi_bind_address` | LAN IP for AP communication | `192.168.2.1` |

### Optional variables

| Variable | Description | Default |
|---|---|---|
| `unifi_admin_address` | Bind address for web UI (8443) | `unifi_bind_address` |

Set `unifi_admin_address` to a WireGuard IP to restrict admin access to VPN only while keeping AP ports on the LAN.

```yaml
# Example: LAN for APs, VPN-only admin
unifi_bind_address: 192.168.2.1     # lan1 — APs reach this
unifi_admin_address: 192.168.20.4   # wg0 — admin via VPN only
```

## Firewall ports

On `unifi_bind_address` (LAN):

| Port | Protocol | Purpose |
|---|---|---|
| 8080 | TCP | Device inform |
| 3478 | UDP | STUN |
| 10001 | UDP | AP discovery |

On `unifi_admin_address` (defaults to `unifi_bind_address`):

| Port | Protocol | Purpose |
|---|---|---|
| 8443 | TCP | Web UI |

## AP adoption

APs on the same L2 network discover the controller automatically via port 10001/udp. For L3 adoption, configure the AP inform URL: `http://<unifi_bind_address>:8080/inform`.

