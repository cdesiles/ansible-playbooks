# Nginx Role

This Ansible role installs and configures Nginx as a reverse proxy for web applications.

## Features

- Installs Nginx
- Configurable worker processes and connections
- Gzip compression support
- SSL/TLS configuration
- Modular vhost configuration via `/etc/nginx/conf.d/`
- Zero-downtime reloads
- Configurable logging backend (journald or traditional files)
- Automatic logrotate configuration for file-based logging

## Requirements

- Systemd-based Linux distribution
- Root/sudo access

## Role Variables

See `defaults/main.yml` for all available variables and their default values.

### Key Configuration

The role provides sensible defaults for worker processes, connection limits, upload sizes, compression, and SSL/TLS settings. Override as needed in your inventory.

### Logging Configuration

```yaml
# Logging backend: 'journald' (systemd journal) or 'file' (traditional logs)
nginx_log_backend: journald  # Default: journald

# Logrotate settings (only used when nginx_log_backend: file)
nginx_logrotate_rotate: 14        # Keep 14 days of logs
nginx_logrotate_frequency: daily  # daily|weekly|monthly
nginx_logrotate_compress: true    # Compress rotated logs
```

**journald backend (default):**
- Logs sent to systemd journal via syslog
- Centralized with other system logs
- Managed by systemd-journald (size limits, retention, compression)
- View with: `journalctl -u nginx`

**file backend:**
- Traditional `/var/log/nginx/*.log` files
- Automatic logrotate configuration deployed
- Useful for external log aggregation tools

## Dependencies

None.

## Example Playbook

### Basic Installation

```yaml
---
- hosts: servers
  become: true
  roles:
    - role: nginx
```

### Custom Configuration

```yaml
---
- hosts: servers
  become: true
  roles:
    - role: nginx
      vars:
        nginx_worker_processes: 4
        nginx_worker_connections: 2048
        nginx_client_max_body_size: 500M
```

## Service Management

The role creates handlers for managing nginx:

```yaml
notify: Reload nginx   # Graceful reload (zero downtime)
notify: Restart nginx  # Full restart
```

## Vhost Configuration Pattern

This role is designed to work with service-specific vhost configurations. Each service role should:

1. Deploy its vhost config to `/etc/nginx/conf.d/<service>.conf`
2. Notify the nginx reload handler
3. Use a variable to enable/disable nginx integration

### Example Service Integration

In your service role (e.g., `immich`):

**defaults/main.yml:**
```yaml
immich_nginx_enabled: false
immich_nginx_hostname: immich.example.com
```

**tasks/main.yml:**
```yaml
- name: Deploy nginx vhost for service
  ansible.builtin.template:
    src: nginx-vhost.conf.j2
    dest: /etc/nginx/conf.d/myservice.conf
    validate: nginx -t
  when: myservice_nginx_enabled
  notify: Reload nginx

- name: Remove nginx vhost when disabled
  ansible.builtin.file:
    path: /etc/nginx/conf.d/myservice.conf
    state: absent
  when: not myservice_nginx_enabled
  notify: Reload nginx
```

**templates/nginx-vhost.conf.j2:**
```nginx
server {
    listen 80;
    server_name {{ myservice_nginx_hostname }};

    location / {
        proxy_pass http://127.0.0.1:{{ myservice_port }};
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**handlers/main.yml:**
```yaml
- name: Reload nginx
  ansible.builtin.systemd:
    name: nginx
    state: reloaded
```

## Independent Deployments

This pattern allows for independent service deployments:

1. **Deploy service A** → Only touches `/etc/nginx/conf.d/serviceA.conf` → Reload nginx
2. **Deploy service B** → Only touches `/etc/nginx/conf.d/serviceB.conf` → Reload nginx
3. **No downtime** for other services during deployment

## Log Management

### Journald Backend (Default)

When `nginx_log_backend: journald`, logs are sent to systemd journal:

```bash
# View all nginx logs
journalctl -u nginx -f

# Last 100 lines
journalctl -u nginx -n 100

# Filter by priority (error, warning, info)
journalctl -u nginx -p err

# Time range
journalctl -u nginx --since "1 hour ago"

# Export to file
journalctl -u nginx > nginx-logs.txt
```

**Benefits:**
- Centralized with all system logs
- Automatic rotation/compression via systemd-journald
- Structured metadata (timestamps, priorities)
- No separate logrotate configuration needed

### File Backend

When `nginx_log_backend: file`, logs are written to:
- `/var/log/nginx/access.log` - Access logs
- `/var/log/nginx/error.log` - Error logs

```bash
# View traditional log files
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log
```

Logrotate is automatically configured to:
- Rotate daily (configurable)
- Keep 14 days (configurable)
- Compress old logs
- Reload nginx gracefully after rotation

### Switching Backends

To switch from journald to file logging:

```yaml
- hosts: servers
  roles:
    - role: nginx
      vars:
        nginx_log_backend: file
        nginx_logrotate_rotate: 30  # Keep 30 days
```

To switch back to journald:

```yaml
- hosts: servers
  roles:
    - role: nginx
      vars:
        nginx_log_backend: journald
```

The role automatically removes logrotate config when using journald.

## Configuration Validation

The role automatically validates nginx configuration before applying changes using `nginx -t`.

Manual validation:
```bash
nginx -t                    # Test configuration
nginx -t -c /path/to/conf  # Test specific config file
```

## Troubleshooting

### Check nginx status
```bash
systemctl status nginx
```

### Test configuration
```bash
nginx -t
```

### Reload configuration
```bash
systemctl reload nginx
```

### View error logs
```bash
journalctl -u nginx -n 100
# or
tail -f /var/log/nginx/error.log
```

### List loaded vhost configs
```bash
ls -la /etc/nginx/conf.d/
```

## SSL/TLS Support

For SSL support, you can:

1. **Manual certificates:** Place certs in `/etc/ssl/` and reference in vhost configs
2. **Let's Encrypt:** Use certbot or similar tools (can be added to playbook)
3. **Self-signed:** Generate with `openssl` for testing

The base nginx.conf includes SSL protocol configuration that applies to all vhosts.

## Performance Tuning

Adjust these variables based on your workload:

- `nginx_worker_processes`: Set to number of CPU cores
- `nginx_worker_connections`: Increase for high traffic (check `ulimit -n`)
- `nginx_client_max_body_size`: Increase for large file uploads

## License

MIT

## Author Information

Created for managing reverse proxy configurations in NAS/homelab environments.
