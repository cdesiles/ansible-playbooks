# Nginx Role

Installs and configures Nginx as a reverse proxy for web applications with modular vhost management.

## Features

- Modular vhost configuration via `/etc/nginx/conf.d/`
- Zero-downtime reloads
- Configurable logging backend (journald or traditional files)
- Automatic logrotate for file-based logging
- SSL/TLS configuration
- **Native ACME/Let's Encrypt support** (Nginx 1.25.0+)
- **Transparent proxy forwarding** (HTTP/HTTPS to other hosts)

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

## Transparent Proxy Forwarding

Forward TCP traffic from this Nginx instance to services on other hosts using the `stream` module (layer 4 proxy).

**Configuration:**

```yaml
nginx_forwarder:
    "blog.hello.com":
        forward_to: "my.host.lan"
        http: true # Forward port 80 (default: true)
        https: true # Forward port 443 (default: true)
```

**How it works:**

- **Stream-based TCP proxy** (layer 4, not HTTP layer 7)
- No protocol inspection - just forwards raw TCP packets
- **HTTPS passes through encrypted** - backend host handles TLS termination
- HTTP also uses stream (simpler, but no HTTP features like headers/logging)

**Use case:** Omega (gateway) forwards all traffic to Andromeda (internal server) that handles its own TLS certificates.

**Important notes:**

- Stream configs deployed to `/etc/nginx/streams.d/`
- No HTTP logging (stream doesn't understand HTTP protocol)
- No X-Forwarded-For headers (transparent TCP forwarding)
- Only ONE domain can use port 443 forwarding (TCP port limitation)

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

# List stream forwarders
ls -la /etc/nginx/streams.d/
```

## Configuration Variables

See [defaults/main.yml](defaults/main.yml) for all available variables.

## References

- [Nginx Documentation](https://nginx.org/en/docs/)
- [Nginx ACME Support](https://blog.nginx.org/blog/native-support-for-acme-protocol)
- [Nginx Stream Module](https://nginx.org/en/docs/stream/ngx_stream_core_module.html)
- [Nginx Logging](https://nginx.org/en/docs/syslog.html)
- [Nginx SSL/TLS](https://nginx.org/en/docs/http/configuring_https_servers.html)
