# Seerr Role

Deploys [Seerr](https://seerr.dev/) - the media request manager (successor of Overseerr/Jellyseerr) - using Podman with k8s files. Uses the official `ghcr.io/seerr-team/seerr` image.

## Prerequisites

The `podman` role must have been applied to the host first. Order it before `seerr` in the playbook for fresh installs.

## Role Variables

See `defaults/main.yml` for all available variables and their default values.

## First Login

The web UI listens on `http://<host>:{{ seerr_port }}`. Complete the setup wizard, then point Seerr at Jellyfin and the *arr services. Because Seerr runs in a container, reach the host-side services via the pasta gateway (`{{ podman_gw_gateway }}`, default `100.64.0.1`) or `host.containers.internal`, not `localhost`.

## Storage

- `seerr_config_dir` - SQLite database, users, requests and settings. Backed up.

The image runs as the unprivileged `node` user (UID/GID 1000). The pod maps the rootless pod user onto that UID via the `io.podman.annotations.userns` annotation, so the host-owned config directory is writable.

## Ports

| Port                  | Protocol | Purpose |
| --------------------- | -------- | ------- |
| `seerr_port` (5055)   | tcp      | Web UI  |

## Nginx Reverse Proxy

Set `seerr_nginx_enabled: true` and `seerr_nginx_hostname` to expose the web UI over HTTPS. Certificates are provisioned via the shared `nginx` role's certbot tasks. If the hostname is not the apex, point a DNS record at the host first.

## Backup

The role exposes `seerr_backup_paths` (config only). Add a job in the host inventory to include it:

```yaml
backup_jobs:
    - name: seerr
      repositories: [next_s3]
      paths: "{{ seerr_backup_paths }}"
```

## Troubleshooting

```sh
systemctl --user status seerr
journalctl --user -u seerr -f
podman logs seerr
```
