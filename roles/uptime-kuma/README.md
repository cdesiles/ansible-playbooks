# uptime-kuma - Self-Hosted Monitoring Tool

Deploys [Uptime Kuma](https://uptime.kuma.pet/) - a self-hosted monitoring and status page application.

## Features

- Website monitoring (HTTP/HTTPS)
- TCP port monitoring
- Ping monitoring
- DNS monitoring
- Status pages
- Notifications (Email, Discord, Slack, ntfy, etc.)
- Multi-language support
- Dark mode

## Configuration

### Optional Variables

See [defaults/main.yml](defaults/main.yml) for all configuration options.

Key settings:

```yaml
uptime_kuma_version: "2"
uptime_kuma_port: 3001
uptime_kuma_data_dir: "{{ podman_projects_dir }}/uptime-kuma/data"

# Nginx reverse proxy
uptime_kuma_nginx_enabled: false
uptime_kuma_nginx_hostname: uptime.nas.local
```

## Storage Requirements

**CRITICAL:** Uptime Kuma uses SQLite and requires local storage with POSIX file lock support.

- ✅ **Supported:** Local filesystem, Docker volumes
- ❌ **NOT Supported:** NFS, network filesystems (will cause database corruption)

## First-Time Setup

1. Access the web UI: `https://uptime.nas.local` (if nginx enabled) or `http://localhost:3001`
2. Create admin account on first visit
3. No default credentials - account is created during initial setup

## Usage

### Adding Monitors

Web UI → Add New Monitor:
- **Monitor Type:** HTTP(s), TCP Port, Ping, DNS, etc.
- **Friendly Name:** Display name
- **URL/Host:** Target to monitor
- **Heartbeat Interval:** Check frequency (seconds)
- **Retries:** Before marking as down
- **Notifications:** Select notification endpoints

### Notification Endpoints

Web UI → Settings → Notifications:
- Email (SMTP)
- Discord, Slack, Telegram
- ntfy (recommended for local notifications)
- Webhooks
- 50+ integrations available

### Status Pages

Create public or password-protected status pages showing monitor health.

Web UI → Status Pages → New Status Page

## Integration with ntfy

If you deployed the `ntfy` role:

1. Settings → Notifications → Add
2. Type: ntfy
3. ntfy Server URL: `https://ntfy.jokester.fr`
4. Topic: `uptime-alerts`
5. Username: `admin`
6. Password: Your ntfy admin password
7. Test notification

## File Locations

- Data directory: `{{ uptime_kuma_data_dir }}`
- SQLite database: `{{ uptime_kuma_data_dir }}/kuma.db`

## Dependencies

- podman
- nginx (if `uptime_kuma_nginx_enabled: true`)

## Sources

- [Install Uptime Kuma using Docker](https://uptimekuma.org/install-uptime-kuma-docker/)
- [Uptime Kuma GitHub Wiki](https://github.com/louislam/uptime-kuma/wiki)
