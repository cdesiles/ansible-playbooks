# ntfy - Simple Notification Service

Deploys [ntfy](https://ntfy.sh/) - a simple HTTP-based pub-sub notification service.

## Security Model

**Secure by default:**
- `auth-default-access: deny-all` - No anonymous access
- `enable-signup: false` - No public registration
- `enable-login: true` - Authentication required
- `enable-reservations: true` - Only authenticated users can reserve topics

All notifications require authentication to send or receive.

## Configuration

### Required Variables

Set in inventory or vault:

```yaml
ntfy_admin_password: "your-secure-password-here"  # Min 12 chars
```

### Optional Variables

See [defaults/main.yml](defaults/main.yml) for all configuration options.

Key settings:

```yaml
ntfy_version: latest
ntfy_port: 8080
ntfy_base_url: http://localhost:8080
ntfy_admin_user: admin

# Nginx reverse proxy
ntfy_nginx_enabled: false
ntfy_nginx_hostname: ntfy.nas.local
```

## Usage

### Managing Users

List users:
```bash
podman exec ntfy ntfy user list
```

Add user:
```bash
podman exec ntfy ntfy user add <username>
```

Change password:
```bash
podman exec -i ntfy ntfy user change-pass <username>
```

Remove user:
```bash
podman exec ntfy ntfy user remove <username>
```

### Managing Topic Access

Grant access to topic:
```bash
podman exec ntfy ntfy access <username> <topic> <permission>
```

Permissions: `read-write`, `read-only`, `write-only`, `deny`

Example:
```bash
# Allow user to publish and subscribe to "alerts" topic
podman exec ntfy ntfy access alice alerts read-write

# Allow user to only publish to "monitoring" topic
podman exec ntfy ntfy access bob monitoring write-only
```

List access control:
```bash
podman exec ntfy ntfy access
```

### Publishing Notifications

Using curl with authentication:
```bash
curl -u admin:password -d "Backup completed" http://localhost:8080/backups
```

Using ntfy CLI:
```bash
ntfy publish --token <access-token> ntfy.nas.local mytopic "Hello World"
```

### Subscribing to Notifications

Web UI: https://ntfy.nas.local (if nginx enabled)

CLI:
```bash
ntfy subscribe --token <access-token> ntfy.nas.local mytopic
```

Mobile apps available for iOS and Android.

## Architecture

- **Container**: Podman-based deployment
- **Storage**: Persistent cache and user database
- **Networking**: Localhost binding by default
- **Reverse Proxy**: Optional nginx with HTTPS

## File Locations

- Configuration: `{{ podman_projects_dir }}/ntfy/server.yml`
- User database: `{{ ntfy_data_dir }}/user.db`
- Cache database: `{{ ntfy_cache_dir }}/cache.db`
- Attachments: `{{ ntfy_cache_dir }}/attachments/`

## Dependencies

- podman
- nginx (if `ntfy_nginx_enabled: true`)
