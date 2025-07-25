# NFS Server

This configuration is meant to be simple. We do not use a keberos server, nor fine-grained user ACLs here. I try not to mess up with ZFS options either.

Security is only guaranteed by the network (and firewal). Security is based on the IP address of the client, so I suggest to use a VPN if you want to avoid ARP poisoning on your LAN.

## In a nutshell

**Supports:**

- NFSv4 (TCP/UDP)
- UFW firewal configuration
- Reload service and exportfs on configuration change

**Limitations:**

- Access control limited to the IP address of the client (unsecure)

## Inventory

Example of `nfs_shares` you can declare:

```yaml
nfs_shares:
    - dir: "/srv/nfs/photos"
      clients:
          - host: "192.168.1.100" # privileged user with write a access
            options: "rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000,insecure"
          - host: "192.168.1.0/24" # readonly access for other lan clients
            options: "ro,sync,no_subtree_check"
```

> Note: to make the share accessible from MacOS, you might use the `insecure` option (allowing to bind port numbers > 1024).

## Ressources

- https://wiki.archlinux.org/title/NFS
- https://www.fkylewright.com/wordpress/2023/06/functional-automount-of-network-shares-in-macos/
