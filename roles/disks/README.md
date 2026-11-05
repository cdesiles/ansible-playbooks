# Disks

Partitions disks, mounts filesystems, enables periodic SSD TRIM, and
optionally exposes S.M.A.R.T. disk health to Prometheus.

## Configuration

See [defaults/main.yml](defaults/main.yml).

Hosts declare `disk_partitioning` and `disk_filesystems` in their host vars.

### Partitioning

`disk_partitioning` pairs a device with a `layout_file` (an `sfdisk --dump`
capture, kept in `inventory_data/partition_layouts/`). A host without the
variable is skipped.

Applying a layout is **opt-in** (`disk_partitioning_apply: false` by default):
`sfdisk` rewrites every partition entry of the disk, so a stale or drifted
layout file would destroy the filesystems on it, including `/` and `/home`.
When the live table differs from the file, the role fails with the commands to
compare them. Set `disk_partitioning_apply: true` only when (re)partitioning a
disk whose contents may be destroyed.

`partitions` under each disk is documentation only; the role reads `device`
and `layout_file`.

### Filesystems and mounts

`disk_filesystems` declares the filesystem expected on a partition and the
fstab entry that mounts it:

```yaml
disk_filesystems:
  - name: home
    device: /dev/nvme0n1p4
    uuid: 00000000-0000-0000-0000-000000000000
    fstype: ext4
    label: home
    mountpoint: /home/user
    options: defaults,noatime
```

Behaviour:

- An empty partition is formatted with `label` applied; a partition carrying
  the expected `fstype` is mounted as-is; any other detected type fails the
  run rather than being formatted over.
- The fstab line is written inside `# BEGIN/END ANSIBLE MANAGED - <name>`
  markers, matched on the UUID. Whole-file templates are deliberately not used:
  fstab also holds root, `/boot` and swap.
- `ansible.posix.mount` with `state: mounted` also writes the fstab line, but it
  may remount the target when the desired options differ from the active ones.
  Over a live `/` or `/home` that is a foot-gun, so the role writes the fstab
  entry itself and mounts only when `findmnt` reports nothing.
- The UUID is asserted against `findmnt` after mounting, so a wrong `uuid` in
  the inventory fails instead of leaving a service writing to the root
  filesystem underneath.
- A hand-written fstab line for the same mountpoint is detected and fails the
  run: two entries for one mountpoint make `mount -a` order-dependent. Delete
  the old line once on hosts that predate `disk_filesystems`.

`passno: 2` makes the boot-time check part of `fsck`. Leave `nofail` out for
home directories: a missing home must fail loudly, not silently fall back to
the root filesystem.

### S.M.A.R.T. exporter

Gated by `smartctl_exporter_enabled`. When true, downloads and runs the
`smartctl_exporter` static binary as a root systemd service, polling `smartctl`
at `smartctl_exporter_interval` (default `30m`).

```yaml
smartctl_exporter_enabled: true
```

Pair with Prometheus:

```yaml
prometheus_scrape_configs:
  - job_name: "smartctl"
    static_configs:
      - targets: ["127.0.0.1:9633"]
        labels:
          instance: nas
```

### Temperature alerts

The `grafana` role provisions cumulative temperature thresholds: a rise fires
each newly crossed threshold (lower tiers keep firing), a fall resolves each
crossed-down threshold (ack), and the final ack fires when leaving the lowest
tier.

| Threshold | `severity` | `for` |
|-----------|-----------|-------|
| ≥48°C | warning | 10m |
| ≥50°C | warning | 10m |
| ≥52°C | warning | 10m |
| ≥54°C | high | 10m |
| ≥56°C | high | 10m |
| ≥58°C | critical | 10m |
| ≥60°C | critical | 5m |
| <20°C | warning | 10m |

Responsiveness is bounded by `smartctl_exporter_interval` (default `30m`).
