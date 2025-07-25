# net-persist

This role prevent the machine interface to change its name, thus to make unexpected changes to the network configuration. This rely on the mac address of the interface to map it to a static interface name.

If for some reason you might change your mac address (on a virtual machine for example), please update your inventory accordingly.

## Requirements

None

## Input variables

- `interface`:

```python
{
    'mac_address': '02:a0:c9:8d:7e:b6',
    'ip': '192.168.1.2',
    'netmask': '255.255.255.0',
    'gateway': '192.168.1.254',
    'dns': ['1.1.1.1', '8.8.8.8'],
    'name': 'lan0'
}
```

## License

MIT

## Author Information

Jokester <main@jokester.fr>
