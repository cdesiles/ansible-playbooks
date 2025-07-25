# Disks

Ansible community support for ZFS is limited to create filesystems, volumes and snapshots. There is no support for managing zpools, so here it is.

## Inventory

Here is an example inventory file you can use with this role:

```yaml
zfs_pools:
    - name: peace
      type: raidz1
      devices:
          - ata-SOME-DISK-LABEL-1
          - ata-SOME-DISK-LABEL-2
      options:
          ashift: 12
      root: /mnt/peace
      state: present
```

And you will get raid1 zpool peace with two disks, with 12 ashift.

You can use a variety of options, see the [zpoolprops(7)](https://openzfs.github.io/openzfs-docs/man/master/7/zpoolprops.7.html) man page.

And for your zfs filesystems:

```yaml
zfs_datasets:
    - name: peace/pictures
      state: present
    - name: peace/movies
      state: present
      extra_zfs_properties:
          mountpoint: /mnt/peace/movies
          quota: 500G
```

## References

- https://docs.ansible.com/ansible/latest/collections/community/general/zfs_module.html
- https://github.com/mrlesmithjr/ansible-zfs/blob/master/tasks/manage_zfs.yml
- https://wiki.archlinux.org/title/ZFS
