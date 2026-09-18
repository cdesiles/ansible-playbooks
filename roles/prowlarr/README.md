# Prowlarr Role

Deploys [Prowlarr](https://prowlarr.com/) - an indexer manager/proxy for the *arr stack - using Podman with k8s files. The `linuxserver/prowlarr` image bundles Prowlarr and its SQLite database.

## Prerequisites

The `podman` role must have been applied to the host first (shared service, intentionally not declared in `meta/main.yml` to keep prowlarr deploys fast). Order it before `prowlarr` in the playbook for fresh installs.

## Role Variables

See `defaults/main.yml` for all available variables and their default values.

## Storage

- `prowlarr_config_dir` - SQLite database, indexer definitions and API keys. Backed up.

## Ports

| Port                     | Protocol | Purpose |
| ------------------------ | -------- | ------- |
| `prowlarr_port` (9696)   | tcp      | Web UI  |

## Nginx Reverse Proxy

Set `prowlarr_nginx_enabled: true` and `prowlarr_nginx_hostname` to expose the web UI over HTTPS. Certificates are provisioned via the shared `nginx` role's certbot tasks. If the hostname is not the apex, point a DNS record at the host first.

## Backup

The role exposes `prowlarr_backup_paths` (config only). Add a job in the host inventory to include it:

```yaml
backup_jobs:
    - name: prowlarr
      repositories: [next_s3]
      paths: "{{ prowlarr_backup_paths }}"
```

## Troubleshooting

```sh
systemctl --user status prowlarr
journalctl --user -u prowlarr -f
podman logs prowlarr
```
