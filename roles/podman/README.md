# Podman Role

Installs and configures Podman for container management with support for Docker Compose compatibility.

## Features

- Installs Podman, podman-compose, and crun (OCI runtime)
- Configurable logging backend (journald or k8s-file)
- External network creation for service isolation
- Container registry search configuration
- Shared projects directory for compose files

## Container Logging

**journald (default):**
- Logs sent to systemd journal
- View: `journalctl CONTAINER_NAME=<name> -f`

**k8s-file:**
- Logs stored as JSON files with automatic rotation
- Configured via `podman_log_max_size` and `podman_log_max_files`

Switch via `podman_log_driver` variable.

## External Networks

Define networks in inventory for persistent, isolated container networks:

```yaml
podman_external_networks:
  - name: immich
    subnet: 172.20.0.0/16
    gateway: 172.20.0.1
```

Networks persist across container restarts and compose rebuilds.

## Hands-on Commands

```bash
# View container logs (journald)
journalctl CONTAINER_NAME=immich_server -f

# View container logs (k8s-file)
podman logs -f immich_server

# Check log driver
podman info --format '{{.Host.LogDriver}}'

# Inspect container log config
podman inspect <container> | jq '.[0].HostConfig.LogConfig'

# Test configuration
podman run --rm alpine echo "OK"

# List networks
podman network ls
```

## References

- [Podman Documentation](https://docs.podman.io/)
- [Podman Logging](https://docs.podman.io/en/latest/markdown/podman-run.1.html#log-driver-driver)
- [containers.conf(5)](https://github.com/containers/common/blob/main/docs/containers.conf.5.md)