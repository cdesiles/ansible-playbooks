# dhcpd

ISC DHCP server role for Arch Linux and Debian/Ubuntu.

## Requirements

- `dhcpd_interface` must be defined in inventory

## Configuration

See [defaults/main.yml](defaults/main.yml) for all available variables.

## Example

```yaml
dhcpd_interface: "lan0"
dhcpd_subnet: "192.168.1.0"
dhcpd_range_start: "192.168.1.20"
dhcpd_range_end: "192.168.1.200"
dhcpd_gateway: "192.168.1.1"
dhcpd_dns_servers:
  - "192.168.1.2"
dhcpd_domain_name: "home.lan"

dhcpd_reservations:
  - hostname: printer
    mac: "aa:bb:cc:dd:ee:ff"
    ip: "192.168.1.10"
```
