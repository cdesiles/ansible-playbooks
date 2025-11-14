# Nginx Role

Installs and configures Nginx as a reverse proxy for web applications with modular vhost management.

## Features

- Modular vhost configuration via `/etc/nginx/conf.d/`
- Zero-downtime reloads
- Configurable logging backend (journald or traditional files)
- Automatic logrotate for file-based logging
- SSL/TLS configuration

## Service Integration Pattern

Each service role should deploy its own vhost config:

**In service role tasks:**
```yaml
- name: Deploy nginx vhost
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

## Logging Backends

**journald (default):**
- Logs sent to systemd journal via syslog
- View: `journalctl -u nginx -f`

**file:**
- Traditional `/var/log/nginx/*.log` files
- Automatic logrotate configuration

Switch via `nginx_log_backend` variable.

## Hands-on Commands

```bash
# Test configuration
nginx -t

# Reload (zero downtime)
systemctl reload nginx

# View logs (journald)
journalctl -u nginx -f
journalctl -u nginx -n 100
journalctl -u nginx -p err

# View logs (file)
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# List loaded vhosts
ls -la /etc/nginx/conf.d/
```

## References

- [Nginx Documentation](https://nginx.org/en/docs/)
- [Nginx Logging](https://nginx.org/en/docs/syslog.html)
- [Nginx SSL/TLS](https://nginx.org/en/docs/http/configuring_https_servers.html)