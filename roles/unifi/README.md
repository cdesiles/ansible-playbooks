# UniFi Controller

Deploys the [UniFi Network Controller](https://ui.com/) via rootless Podman using the [`jacobalberty/unifi`](https://github.com/jacobalberty/unifi-docker) image (embedded MongoDB, no external DB required).

Variables: [defaults/main.yml](defaults/main.yml)

## Firewall ports

Opened in UFW for `unifi_firewall_allowed_sources`:

| Port | Protocol | Purpose |
|---|---|---|
| 8080 | TCP | Device inform |
| 8443 | TCP | Web UI |
| 3478 | UDP | STUN |
| 10001 | UDP | AP discovery |

## AP adoption

APs on the same L2 network discover the controller automatically via port 10001/udp. For L3 adoption, configure the AP inform URL: `http://<unifi_bind_address>:8080/inform`.

