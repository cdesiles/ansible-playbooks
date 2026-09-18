# Disks

Partitions disks, enables periodic SSD TRIM, and optionally exposes S.M.A.R.T.
disk health to Prometheus.

## Configuration

See [defaults/main.yml](defaults/main.yml).

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
          instance: andromeda
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
