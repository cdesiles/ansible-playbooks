# node_exporter — Prometheus exporter for host metrics

Exposes machine metrics (CPU, memory, disk, filesystem, network) for Prometheus.

Variables: [defaults/main.yml](defaults/main.yml)

## Supported distributions

- Arch Linux (package `prometheus-node-exporter`, extra repo)
- Debian/Ubuntu (package `prometheus-node-exporter`)

## Collectors

Enabled by default through `node_exporter_collectors` (override per host):

- `--collector.zfs` — ZFS pool/dataset metrics. Drop it where ZFS is absent
  (`node_exporter_collectors: [systemd]` on a Raspberry Pi), otherwise the only
  effect is a dead collector in the logs.
- `--collector.systemd` — unit state (`node_systemd_unit_state`), restart
  counts (`node_systemd_restart_count_total`) and timer trigger times
  (`node_systemd_timer_last_trigger_seconds` / `..._next_trigger_seconds`).
  Powers the systemd dashboard (failed units, timers that stopped firing).
- `--collector.textfile.directory={{ node_exporter_textfile_dir }}` — re-exposes
  `*.prom` files dropped into that directory. The backup role writes
  `backup_*` metrics there; other cron/timer jobs can do the same.

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
