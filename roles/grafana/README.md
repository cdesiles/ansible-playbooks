# Grafana Role

Installs and configures Grafana as a system service with PostgreSQL backend.

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

## Variables

### Required Variables (Override with Ansible Vault!)

```yaml
grafana_db_password: changeme
grafana_admin_password: changeme
grafana_secret_key: changeme
```

### Server Configuration

```yaml
grafana_http_port: 3000
grafana_domain: localhost
grafana_root_url: "%(protocol)s://%(domain)s:%(http_port)s/"
```

### Database Configuration

```yaml
grafana_db_type: postgres
grafana_db_name: grafana
grafana_db_user: grafana_user
grafana_db_host: localhost
grafana_db_port: 5432
grafana_db_ssl_mode: disable
```

### Admin User

```yaml
grafana_admin_user: admin
```

### Analytics

```yaml
grafana_reporting_enabled: false
grafana_check_for_updates: false
```

### Nginx Reverse Proxy

```yaml
grafana_nginx_enabled: false
grafana_nginx_hostname: grafana.local
```

### Alerting

```yaml
grafana_alerting_enabled: false
grafana_ntfy_webhook_url: "https://ntfy.example.com/sys-alerts?template=grafana"
grafana_ntfy_token: "{{ vault_ntfy_token }}" # write access to the topic
```

`grafana_ntfy_webhook_url` and `grafana_ntfy_token` are required when
`grafana_alerting_enabled: true`. The token is rendered into the contact point
provisioning file, which is deployed `0600`.

## Example Playbook

```yaml
---
- hosts: monitoring
  roles:
      - role: grafana
        vars:
            grafana_domain: monitoring.example.com
            grafana_nginx_enabled: true
            grafana_nginx_hostname: grafana.example.com
            grafana_admin_password: !vault |
                $ANSIBLE_VAULT;1.1;AES256
                ...
            grafana_db_password: !vault |
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
CREATE USER grafana_user WITH PASSWORD 'xxx';
GRANT ALL PRIVILEGES ON DATABASE grafana TO grafana_user;
ALTER USER grafana_user NOSUPERUSER NOCREATEDB NOCREATEROLE;
```

### Service Layout

```
System Services:
├── PostgreSQL (port 5432, localhost only)
│   └── grafana database → grafana_user
└── Grafana (port 3000, localhost only)
    └── Nginx (port 80) → reverse proxy (optional)
```

## Post-Installation

### Access Grafana

**Direct access:**

```
http://localhost:3000
```

**With Nginx reverse proxy:**

```
http://grafana.local
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
sudo cat /etc/grafana/grafana.ini | grep -A 5 "\[database\]"

# Check logs
journalctl -u grafana-server -f  # Debian/Ubuntu
journalctl -u grafana -f         # Arch Linux
```

## Security Considerations

1. **Passwords:** Always use Ansible Vault for sensitive variables
2. **Database:** Grafana user has minimal privileges (no superuser, can't create databases/roles)
3. **Network:** Grafana binds to localhost by default, use Nginx for external access
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
- `rules.yaml` — disk alert rules: HDD temperature
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

- **Arch Linux:** Installs from community repository
- **Debian/Ubuntu:** Installs from official Grafana APT repository

## Troubleshooting

### Grafana won't start

```bash
# Check logs
journalctl -u grafana-server -n 50  # Debian/Ubuntu
journalctl -u grafana -n 50         # Arch Linux

# Check configuration syntax
sudo grafana-cli admin validate-config
```

### Can't connect to PostgreSQL

```bash
# Verify PostgreSQL is running
systemctl status postgresql

# Test database connection
psql -h localhost -U grafana_user -d grafana

# Check PostgreSQL logs
journalctl -u postgresql -n 50
```

### 502 Bad Gateway with Nginx

```bash
# Verify Grafana is running
systemctl status grafana-server

# Check if Grafana is listening
ss -tlnp | grep 3000

# Test direct access
curl http://localhost:3000
```

## References

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Grafana Configuration](https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/)
- [PostgreSQL Data Source](https://grafana.com/docs/grafana/latest/datasources/postgres/)
