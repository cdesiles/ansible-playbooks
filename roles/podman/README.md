# Podman Role

Installs and configures Podman for container management with support for Docker Compose compatibility.

## Features

- Installs Podman, podman-compose, and crun (OCI runtime)
- Configurable logging backend (journald or k8s-file)
- Container registry search configuration
- Shared projects directory for Kubernetes YAML files

## Container Logging

**journald (default):**

- Logs sent to systemd journal
- View: `journalctl CONTAINER_NAME=<name> -f`

**k8s-file:**

- Logs stored as JSON files with automatic rotation
- Configured via `podman_log_max_size` and `podman_log_max_files`

Switch via `podman_log_driver` variable.

## Container names

Single-container pods run `podman kube play --no-pod-prefix` and name their container after the pod: `podman exec jellyfin`, `podman logs ntfy`. Multi-container pods (immich, matrix, qfieldcloud) keep podman's `<pod>-<container>` names (`immich-server`): `kube play` registers the short YAML names as network aliases, which qfieldcloud's workers rely on. `podman pod logs <pod>` works for both.

The role asserts podman ≥ 5.7.0 on the SQLite database backend: older versions lack the flag, and BoltDB rejects a container named like its pod.

## Hands-on Commands

```bash
# View container logs (journald)
journalctl CONTAINER_NAME=immich-server -f

# View container logs (k8s-file)
podman logs -f immich-server

# Check log driver
podman info --format '{{.Host.LogDriver}}'

# Inspect container log config
podman inspect <container> | jq '.[0].HostConfig.LogConfig'

# Test configuration
podman run --rm alpine echo "OK"

# Play Kubernetes YAML
podman play kube --replace /path/to/pod.yaml

# Stop pod
podman play kube --down /path/to/pod.yaml

# List pods
podman pod ls
```

## References

- [Podman Documentation](https://docs.podman.io/)
- [Podman Logging](https://docs.podman.io/en/latest/markdown/podman-run.1.html#log-driver-driver)
- [containers.conf(5)](https://github.com/containers/common/blob/main/docs/containers.conf.5.md)
