# nut_exporter — Prometheus exporter for NUT

Scrapes a local `upsd` and exposes UPS metrics for Prometheus.

## Supported distributions

- Arch Linux (AUR package `prometheus-nut-exporter`, installed via `paru`)

Debian/Ubuntu is not packaged upstream — add it on demand.

## Configuration

See [defaults/main.yml](defaults/main.yml).

Required:

```yaml
nut_exporter_nut_password: "<same as nut_monitor_password>"
```

Optional:

```yaml
nut_exporter_listen_address: "127.0.0.1:9199"
nut_exporter_nut_server: "127.0.0.1:3493"
nut_exporter_nut_user: monitor
```

## Pairing with Prometheus

Typical scrape config (target uses the multi-target pattern: the exporter
queries a remote upsd specified in the URL parameters):

```yaml
prometheus_scrape_configs:
  - job_name: 'nut'
    metrics_path: /nut
    static_configs:
      - targets: ['eaton@localhost']  # ups@host syntax
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: 127.0.0.1:9199
```

## Operations

```bash
systemctl status prometheus-nut-exporter
curl -s 'http://127.0.0.1:9199/nut?target=localhost&ups=eaton' | head
journalctl -u prometheus-nut-exporter -f
```

## Dependencies

Requires the [`nut`](../nut/README.md) role (or any other running upsd) on the
same host.
