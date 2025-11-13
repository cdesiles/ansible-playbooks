# Podman Role

This Ansible role installs and configures Podman for container management on NAS/homelab systems.

## Features

- Installs Podman and podman-compose
- Configures container registry search paths
- Creates shared projects directory for compose files
- Enables short image name resolution (e.g., `redis:alpine` → `docker.io/library/redis:alpine`)
- Creates external networks for services (e.g., dedicated Immich network)

## Requirements

- systemd-based Linux distribution
- Root/sudo access

## Role Variables

See `defaults/main.yml` for all available variables and their default values.

### Key Configuration

#### Unqualified Search Registries

When you use short image names (without registry prefix), Podman searches configured registries in order (e.g., `redis:alpine` → `docker.io/library/redis:alpine`).

Customize via the `podman_unqualified_search_registries` variable.


#### External Networks

The role can create external Podman networks for services that need dedicated network isolation. Define the `podman_external_networks` list in your inventory. Networks persist across container restarts and compose stack rebuilds. See `defaults/main.yml` for configuration details.

## Dependencies

- `containers.podman` collection (installed via `requirements.yml`)

## Example Playbook

```yaml
---
- hosts: servers
  become: true
  roles:
    - role: podman
```

### Custom Configuration

See `defaults/main.yml` for all available variables. Override in your inventory as needed.

## Files Deployed

- `/etc/containers/registries.conf` - Registry configuration
- `{{ podman_projects_dir }}` - Projects directory (default: `/opt/podman`)

## Usage

### Running Containers

```bash
# Using short names (works after role deployment)
podman run -d redis:alpine

# Using fully qualified names (always works)
podman run -d docker.io/library/redis:alpine
```

### Docker Compose

Services using `podman-compose` should store their compose files in subdirectories:

```
/opt/podman/
├── immich/
│   └── docker-compose.yml
├── nextcloud/
│   └── docker-compose.yml
└── gitea/
    └── docker-compose.yml
```

## Troubleshooting

### Short names not resolving

Check the registries configuration:
```bash
cat /etc/containers/registries.conf
```

Test search order:
```bash
podman search redis --limit 3
```

### Permission denied

Ensure the user is in the appropriate groups (handled by Podman package):
```bash
# Check groups
groups $USER

# May need to log out and back in after installation
```

## License

MIT

## Author Information

Created for managing containerized services in NAS/homelab environments.
