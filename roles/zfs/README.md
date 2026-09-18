# ZFS

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

## Prometheus metrics

The role deploys an hourly systemd timer (`zfs-metrics.timer`) running
`/usr/local/bin/zfs-metrics.sh`, which writes pool and dataset capacity to
node_exporter's textfile collector directory (`zfs_metrics_dir`). The
`node_exporter` role must be deployed on the host; the script exits silently
otherwise.

| Metric | Labels | Description |
| --- | --- | --- |
| `zfs_pool_size_bytes` | `pool` | Total pool size |
| `zfs_pool_alloc_bytes` | `pool` | Allocated bytes |
| `zfs_pool_free_bytes` | `pool` | Free bytes |
| `zfs_pool_capacity_percent` | `pool` | Used capacity |
| `zfs_dataset_used_bytes` | `dataset` | Used bytes (incl. snapshots and children) |
| `zfs_dataset_refer_bytes` | `dataset` | Own referenced bytes |
| `zfs_dataset_quota_bytes` | `dataset` | Quota (0 = none) |

These feed the **ZFS - Pools & Datasets** Grafana dashboard. node_exporter's
built-in `--collector.zfs` exposes ARC, I/O and pool state only, not capacity.

`zfs_pool_capacity_percent` also drives Grafana capacity alerts (80/90/95%
tiers) to ntfy, provisioned by the `grafana` role — see `roles/grafana/README.md`.

Tunables (`defaults/main.yml`): `zfs_metrics_enabled`, `zfs_metrics_dir`,
`zfs_metrics_script_path`, `zfs_metrics_interval`.

## References

- https://docs.ansible.com/ansible/latest/collections/community/general/zfs_module.html
- https://github.com/mrlesmithjr/ansible-zfs/blob/master/tasks/manage_zfs.yml
- https://wiki.archlinux.org/title/ZFS
