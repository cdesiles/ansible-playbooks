# net-persist

This role prevent the machine interface to change its name, thus to make unexpected changes to the network configuration. This rely on the mac address of the interface to map it to a static interface name.

If for some reason you might change your mac address (on a virtual machine for example), please update your inventory accordingly.

Called by the [`networking`](../networking/README.md) role, once per
`network_interfaces` entry, passed as `interface`.

Variables: [networking/defaults/main.yml](../networking/defaults/main.yml)

## Requirements

None

## License

MIT

## Author Information

Jokester <main@jokester.fr>
