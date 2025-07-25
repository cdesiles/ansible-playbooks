# Networking

This role configures the networking on the target machine.

## Requirements

Roles:

- net-persist
- net-config

## Inventory Variables

| Name               | Description                                     | Required |
| ------------------ | ----------------------------------------------- | -------- |
| network.interfaces | A dictionary of network interfaces to configure | yes      |

Example:

```yaml
network:
    interfaces:
        lan0:
            mac_address: 02:a0:c9:8d:7e:b6
            ip: 192.168.1.2
            netmask: 255.255.255.0
            gateway: 192.168.1.254
            dns:
                - 1.1.1.1
                - 8.8.8.8
        lan1:
            mac_address: 0a:3f:5b:1c:d2:e4
```

## License

MIT

## Author Information

Jokester <main@jokester.fr>
