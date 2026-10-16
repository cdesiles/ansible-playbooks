# net-config

Renders a `systemd-networkd` unit (`/etc/systemd/network/20-<name>.network`) for a
single network interface, plus an optional `.netdev` for virtual interfaces.
Called by the [`networking`](../networking/README.md) role, once per
`network_interfaces` entry.

## Requirements

- `systemd-networkd` as the network manager.
- For wireless interfaces, the link association (SSID/PSK) is out of scope —
  this role only configures the IP layer.

## Role variables

Passed as the `interface` variable (one `network_interfaces` entry).

| Variable                        | Description                                                                                                 |
| ------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| `interface.name`                | Interface name (e.g. `lan0`, `wlan0`).                                                                      |
| `interface.type`                | Optional. `ethernet`/`wireless` are physical (no `.netdev`); any other value is a `systemd.netdev` kind.    |
| `interface.mac_address`         | Used by [`net_persist`](../net_persist/README.md) to rename the physical NIC.                               |
| `interface.ipv4.dhcp`           | `true` to acquire the address by DHCP (`DHCP=ipv4`). Mutually exclusive with `ipv4.address`.                |
| `interface.ipv4.address`        | Static address with prefix (e.g. `192.168.1.2/24`).                                                        |
| `interface.ipv4.gateway`        | Static default gateway (static interfaces only).                                                            |
| `interface.ipv4.nameservers`    | List of DNS servers rendered as `DNS=`. Omit to accept the DHCP-provided DNS.                              |
| `interface.ipv4.metric`         | Route metric; lower is preferred. Emitted as `[Address] RouteMetric` (static) or `[DHCPv4] RouteMetric` (DHCP). |
| `interface.ipv4.broadcast`      | Optional. Segment broadcast, for tools that cannot derive it from a DHCP lease (see `playbooks/wol.yml`).  |
| `interface.ipv4.forward`        | `true` to enable IPv4 forwarding on the interface (router/NAT use).                                         |
| `interface.ipv4.masquerade`     | `true` to enable `IPMasquerade=ipv4`. Requires `forward` and `nat_out_interface`.                          |
| `interface.ipv4.nat_out_interface` | Egress interface used by the UFW NAT `POSTROUTING` rule.                                                 |

An interface entry that declares neither `ipv4.address` nor `ipv4.dhcp: true` is
skipped with a warning.

## Example playbook

```yaml
- hosts: servers
  roles:
      - role: net_config
        interface:
            name: lan0
            type: ethernet
            mac_address: 02:a0:c9:8d:7e:b6
            ipv4:
                address: 192.168.1.2/24
                gateway: 192.168.1.254
                nameservers:
                    - 1.1.1.1
                    - 8.8.8.8
```

DHCP client (e.g. a host resolved by an upstream reservation):

```yaml
- role: net_config
  interface:
      name: lan0
      type: ethernet
      mac_address: 02:a0:c9:8d:7e:b6
      ipv4:
          dhcp: true
          metric: 100
          broadcast: 192.168.2.255
```

## License

MIT

## Author Information

Jokester <main@jokester.fr>
