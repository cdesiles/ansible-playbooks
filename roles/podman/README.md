# Podman Role

This Ansible role installs and configures Podman for container management on NAS/homelab systems.

## Features

- Installs Podman and podman-compose
- Configures container registry search paths
- Creates shared projects directory for compose files
- Enables short image name resolution (e.g., `redis:alpine` → `docker.io/library/redis:alpine`)

## Requirements

- systemd-based Linux distribution
- Root/sudo access

## Role Variables

Available variables with defaults (see `defaults/main.yml`):

```yaml
# Base directory for docker-compose projects
podman_projects_dir: /opt/podman

# Unqualified search registries (for short image names)
podman_unqualified_search_registries:
  - docker.io
  - quay.io
  - ghcr.io

# Podman bridge network (leave empty for default dynamic assignment)
podman_subnet: ""

# Podman bridge gateway IP (used by services binding to bridge)
podman_subnet_gateway: ""

# Podman bridge interface name (if using custom network)
podman_subnet_iface: podman1
```

### Unqualified Search Registries

When you use short image names (without registry prefix), Podman searches these registries in order:

```bash
# Short name
podman pull redis:alpine

# Resolves to
docker.io/library/redis:alpine
```

**Default search order:**
1. `docker.io` - Docker Hub
2. `quay.io` - Red Hat Quay
3. `ghcr.io` - GitHub Container Registry

You can customize this list via the `podman_unqualified_search_registries` variable.

### Podman Bridge Network

By default, Podman dynamically assigns network subnets to bridge interfaces. You can document your network configuration using these variables:

**Default behavior (empty `podman_subnet`):**
- Podman manages networks automatically
- No manual configuration needed

**Explicit network documentation:**

```yaml
podman_subnet: "10.89.0.0/24"
podman_subnet_gateway: "10.89.0.1"
podman_subnet_iface: podman1
```

Use this to:
- Document your infrastructure topology
- Allow services to bind to the bridge gateway (e.g., PostgreSQL, Valkey)
- Reference in other roles that need bridge network information
- Maintain consistent network configuration across deployments

**Finding your Podman network:**

```bash
# List Podman networks
podman network ls

# Show bridge interfaces
ip addr show | grep podman

# Get specific interface IP
ip -4 addr show podman1
```

## Dependencies

None.

## Example Playbook

```yaml
---
- hosts: servers
  become: true
  roles:
    - role: podman
```

### Custom Configuration

```yaml
---
- hosts: servers
  become: true
  roles:
    - role: podman
      vars:
        podman_projects_dir: /mnt/storage/containers
        podman_unqualified_search_registries:
          - docker.io
          - ghcr.io
          - registry.gitlab.com
```

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
