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

The `root` key is informational only; the role does not apply it. Set the pool
root mountpoint through a `zfs_datasets` entry (`name: peace`, `mountpoint:
/mnt/peace`) as shown below.

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

## Debian/Ubuntu

The role installs `zfsutils-linux` (override with `zfs_debian_packages`) plus
`kmod`, and the headers for the running kernel
(`linux-headers-$(uname -r)`) so `zfs-dkms` can build. Set
`zfs_debian_install_headers: false` on vendor kernels that provide their own
ZFS module, or override `zfs_debian_headers_package`. It then generates
`/etc/hostid` if needed, loads the module, and enables the standard ZFS units.
On Debian, ZFS lives in `contrib`: make sure the APT sources include it
(`deb ... bookworm main contrib`) before running the role.

The DKMS build also works on Debian ARM64/ARMHF; expect the first build to take
a few minutes on NAS-class CPUs.

Vendor kernels (appliance NAS OSes such as UGOS) usually ship without matching
headers, so DKMS cannot build the module. In that case install the vendor ZFS
module first, or run a kernel for which ZFS is packaged. The role asserts
`modprobe zfs` succeeds and stops with that guidance instead of failing later at
`zpool create`.

`zrepl` is installed on Arch Linux only; use `sanoid`/`syncoid` or the zrepl
APT repository on Debian.

## Kernel upgrades (Arch)

Upgrading `linux`/`linux-lts` deletes `/usr/lib/modules/<old kernel>` while the
host keeps running that kernel until reboot. If ZFS is already loaded the role
does **not** treat this as a failure: the pools are operational, so it only
warns and asserts that a `zfs.ko` build exists for an installed kernel — the one
the next boot will use. If no build exists it stops before you reboot into a
kernel without ZFS (`dkms autoinstall` fixes that). Only when the module is not
loaded is a failing `modprobe` fatal, with the packaging guidance above.

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
