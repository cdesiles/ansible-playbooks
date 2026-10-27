# Grafana Role

Installs and configures Grafana as a system service with PostgreSQL backend.

Variables: [defaults/main.yml](defaults/main.yml)

## Description

This role:

- Installs Grafana from official repositories (Arch Linux or Debian/Ubuntu)
- Creates a dedicated PostgreSQL database and user
- Configures Grafana to use PostgreSQL
- Optionally configures Nginx reverse proxy
- Optionally provisions disk alerting (temperature + capacity) to ntfy (see [Alerting](#alerting))
- Follows the shared services pattern

## Dependencies

- `postgres` role (for database backend)

## Example Playbook

```yaml
---
- hosts: monitoring
  roles:
      - role: grafana
        vars:
            grafana_domain: grafana.example.com
            grafana_nginx_enabled: true
            grafana_nginx_hostname: grafana.example.com
            grafana_admin_password: !vault |
                $ANSIBLE_VAULT;1.1;AES256
                ...
            grafana_postgres_password: !vault |
                $ANSIBLE_VAULT;1.1;AES256
                ...
            grafana_secret_key: !vault |
                $ANSIBLE_VAULT;1.1;AES256
                ...
```

## Architecture

### Database Isolation

Grafana gets its own PostgreSQL database with a dedicated user that has minimal privileges:

```sql
CREATE DATABASE grafana;
CREATE USER grafana WITH PASSWORD 'xxx';
GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana;
ALTER USER grafana NOSUPERUSER NOCREATEDB NOCREATEROLE;
```

### Service Layout

```
System Services:
├── PostgreSQL (port 5432, localhost only)
│   └── grafana database → grafana user
└── Grafana (port {{ grafana_http_port }}, all interfaces)
    └── Nginx (port 443, 80 redirects) → reverse proxy (optional)
```

## Post-Installation

### Access Grafana

**Direct access:**

```
http://localhost:{{ grafana_http_port }}
```

**With Nginx reverse proxy:**

```
https://{{ grafana_nginx_hostname }}
```

### Default Credentials

- Username: `admin` (or value of `grafana_admin_user`)
- Password: Value of `grafana_admin_password`

**Important:** Change the admin password immediately after first login!

### Verify Installation

```bash
# Check service status
systemctl status grafana-server  # Debian/Ubuntu
systemctl status grafana         # Arch Linux

# Check database connection
sudo -u postgres psql -c "\l" | grep grafana
sudo -u postgres psql -c "\du" | grep grafana

# Check configuration
sudo cat /etc/grafana/grafana.ini | grep -A 5 "\[database\]"  # Debian/Ubuntu
sudo cat /etc/grafana.ini | grep -A 5 "\[database\]"          # Arch Linux

# Check logs
journalctl -u grafana-server -f  # Debian/Ubuntu
journalctl -u grafana -f         # Arch Linux
```

## Security Considerations

1. **Passwords:** Always use Ansible Vault for sensitive variables
2. **Database:** Grafana user has minimal privileges (no superuser, can't create databases/roles)
3. **Network:** Grafana listens on all interfaces (`http_addr` is not set) and the role opens no UFW port for it; use Nginx for external access
4. **Secret Key:** Used for signing cookies and other security features - keep it secret!

## Nginx Integration

When `grafana_nginx_enabled: true`, the role:

- Deploys an Nginx vhost configuration to `/etc/nginx/conf.d/grafana.conf`
- Configures reverse proxy with WebSocket support for live updates
- Reloads Nginx gracefully

When disabled, the vhost configuration is removed.

## Alerting

When `grafana_alerting_enabled: true`, the role provisions [Grafana Unified
Alerting](https://grafana.com/docs/grafana/latest/alerting/) as code under
`{{ grafana_provisioning_path }}/alerting/`:

- `contact-points.yaml` — stock **webhook** receiver pointing at an ntfy topic,
  token sent as `Authorization: Bearer`. Deployed `0600` (secret).
- `policies.yaml` — notification policy tree (root route to that receiver).
- `rules.yaml` — disk alert rules: HDD and NVMe temperature
  (`smartctl_device_temperature{temperature_type="current"}`) and capacity
  (ZFS pools `zfs_pool_capacity_percent`; local filesystems
  `node_filesystem_avail_bytes` / `node_filesystem_size_bytes`, filtered to
  `fstype=~"ext4|xfs|btrfs"`).

No plugin, bridge or Alertmanager is involved: the webhook URL carries
`?template=grafana`, so ntfy's built-in `grafana` template renders Grafana's
webhook JSON into a `🚨`/`✅` title and message. Resolved alerts are sent
automatically (`disableResolveMessage: false`). Adding rules means adding
entries to `rules.yaml`; the receiver and policy stay generic.

> Provisioning the notification policy tree replaces the entire tree; UI edits
> to policies are overwritten on the next deploy.

### Temperature tiers

HDD and NVMe have different safe ranges, so they use separate ladders selected
by the `device` label (`nvme*` vs everything else). Cumulative thresholds, same
rise/fall semantics as capacity.

| Device | Threshold | `severity` | `for` |
|--------|-----------|-----------|-------|
| HDD | ≥48 / ≥50 / ≥52 / ≥54 / ≥56 / ≥58 / ≥60°C | warning → critical | 10m (5m at 60) |
| HDD | <20°C | warning | 10m |
| NVMe | ≥65°C | warning | 15m |
| NVMe | ≥70°C | high | 10m |
| NVMe | ≥75°C | critical | 5m |

NVMe tiers follow the 0-70°C operating spec (dashboard: orange ≥60, red ≥70°C).

### Capacity tiers

Cumulative thresholds: a rise fires each newly crossed threshold (lower tiers
keep firing), a fall acks each crossed-down threshold. ZFS capacity is emitted
hourly by the `zfs` role, so its tiers need at least an hourly `for` to see the
new value.

| Metric | Threshold | `severity` | `for` |
|--------|-----------|-----------|-------|
| `zfs_pool_capacity_percent` / filesystem used % | ≥80% | warning | 6h |
| `zfs_pool_capacity_percent` / filesystem used % | ≥90% | high | 1h |
| `zfs_pool_capacity_percent` / filesystem used % | ≥95% | critical | 15m |

ZFS datasets are excluded from the filesystem rule: they report pool-wide free
space, not per-dataset usage, so the pool metric is authoritative.

## OS Support

- **Arch Linux:** Installs from the `extra` repository
- **Debian/Ubuntu:** Installs from official Grafana APT repository

## Troubleshooting

### Grafana won't start

```bash
# Check logs
journalctl -u grafana-server -n 50  # Debian/Ubuntu
journalctl -u grafana -n 50         # Arch Linux
```

### Can't connect to PostgreSQL

```bash
# Verify PostgreSQL is running
systemctl status postgresql

# Test database connection
psql -h localhost -U grafana -d grafana

# Check PostgreSQL logs
journalctl -u postgresql -n 50
```

### 502 Bad Gateway with Nginx

```bash
# Verify Grafana is running
systemctl status grafana-server  # Debian/Ubuntu
systemctl status grafana         # Arch Linux

# Check if Grafana is listening
ss -tlnp | grep {{ grafana_http_port }}

# Test direct access
curl http://localhost:{{ grafana_http_port }}
```

## References

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Grafana Configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)
- [PostgreSQL Data Source](https://grafana.com/docs/grafana/latest/datasources/postgres/)
