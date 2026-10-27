# net-config

Renders a `systemd-networkd` unit (`/etc/systemd/network/20-<name>.network`) for a
single network interface, plus an optional `.netdev` for virtual interfaces.
Called by the [`networking`](../networking/README.md) role, once per
`network_interfaces` entry, passed as `interface`. An entry that declares
neither `ipv4.address` nor `ipv4.dhcp: true` is skipped with a warning.

Variables: [networking/defaults/main.yml](../networking/defaults/main.yml)

## Requirements

- `systemd-networkd` as the network manager.
- For wireless interfaces, the link association (SSID/PSK) is out of scope —
  this role only configures the IP layer.

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
