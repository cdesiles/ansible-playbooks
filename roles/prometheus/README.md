# Prometheus Role

Installs and configures Prometheus monitoring system as a native system service.

## Supported Distributions

- Arch Linux
- Debian/Ubuntu

## Features

- Native system installation (no containers)
- Configurable scrape targets and intervals
- Optional Nginx reverse proxy with SSL
- Retention policy configuration
- Alert manager integration support
- Rule files support

## Configuration

See [defaults/main.yml](defaults/main.yml) for all available variables.

### Basic Configuration

```yaml
prometheus_scrape_interval: 15s
prometheus_retention_time: 15d
prometheus_web_listen_address: "127.0.0.1:9090"
```

### Scrape Targets

```yaml
prometheus_scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
```

### Nginx Reverse Proxy

```yaml
prometheus_nginx_enabled: true
prometheus_nginx_server_name: prometheus.example.com
prometheus_nginx_ssl_certificate: /path/to/cert.pem
prometheus_nginx_ssl_certificate_key: /path/to/key.pem
```

## Usage

```yaml
- hosts: monitoring
  roles:
    - prometheus
```

With custom configuration:

```yaml
- hosts: monitoring
  vars:
    prometheus_retention_time: 30d
    prometheus_scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      - job_name: 'node_exporter'
        static_configs:
          - targets: ['localhost:9100']
  roles:
    - prometheus
```

## Architecture

- **Installation**: Native package from distribution repositories
- **Service**: System systemd service
- **Configuration**: `/etc/prometheus/prometheus.yml`
- **Data**: `/var/lib/prometheus`
- **Listen**: `127.0.0.1:9090` (localhost only by default)

## Security

- Binds to localhost by default
- Optional SSL-enabled reverse proxy via Nginx
- Data directory restricted to prometheus user (mode 0750)
