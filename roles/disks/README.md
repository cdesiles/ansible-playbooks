# Disks

Partitions disks, enables periodic SSD TRIM, and optionally exposes S.M.A.R.T.
disk health to Prometheus.

## Configuration

See [defaults/main.yml](defaults/main.yml).

### S.M.A.R.T. exporter

Gated by `smartctl_exporter_enabled`. When true, downloads and runs the
`smartctl_exporter` static binary as a root systemd service, polling `smartctl`
at `smartctl_exporter_interval` (default `1h`).

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
          instance: andromeda
```
