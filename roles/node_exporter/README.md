# node_exporter — Prometheus exporter for host metrics

Exposes machine metrics (CPU, memory, disk, filesystem, network) for Prometheus.

## Supported distributions

- Arch Linux (package `prometheus-node-exporter`, extra repo)
- Debian/Ubuntu (package `prometheus-node-exporter`)

## Configuration

See [defaults/main.yml](defaults/main.yml).

Optional:

```yaml
node_exporter_listen_address: "127.0.0.1:9100"
```

Keep localhost-only — Prometheus scrapes it locally on the same host. To add
collectors (e.g. `--collector.systemd`, `--collector.textfile.directory`), extend
`node_exporter_listen_address` or override the args in host_vars.

## Pairing with Prometheus

```yaml
prometheus_scrape_configs:
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
```

## Operations

```bash
systemctl status prometheus-node-exporter
curl -s http://127.0.0.1:9100/metrics | head
journalctl -u prometheus-node-exporter -f
```

## Dependencies

None. Standalone exporter.
