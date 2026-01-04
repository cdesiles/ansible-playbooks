# net-config

This role configures a network interface.

## Requirements

None

## Example Playbook

```yaml
- hosts: servers
  roles:
      - role: net-config
        interface:
            name: lan0
            mac_address: 02:a0:c9:8d:7e:b6
            address: 192.168.1.2/24
            gateway: 192.168.1.254
            nameservers:
                - 1.1.1.1
                - 8.8.8.8
```

## License

MIT

## Author Information

Jokester <main@jokester.fr>
