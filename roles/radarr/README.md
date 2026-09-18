# Radarr Role

Deploys [Radarr](https://radarr.video/) - a movie collection manager for Usenet and BitTorrent - using Podman with k8s files. The `linuxserver/radarr` image bundles Radarr and its SQLite database.

## Prerequisites

The `podman` role must have been applied to the host first. Order it before `radarr` in the playbook for fresh installs.

## Role Variables

See `defaults/main.yml` for all available variables and their default values.

## Storage

- `radarr_config_dir` - SQLite database, library and API keys. Backed up.
- `radarr_movies_dir` - movie library, mounted read-write at `/movies`. Use `/movies` as the root folder in the Radarr UI.
- `radarr_downloads_dir` - completed downloads, shared with Deluge. Mounted read-write at `/downloads`; point the download client there.

`radarr_movies_dir` lives on ZFS (`/mnt/andromeda`), `radarr_downloads_dir` under `{{ podman_projects_dir }}` - cross-filesystem imports are copies, not hardlinks.

## Ports

| Port                   | Protocol | Purpose |
| ---------------------- | -------- | ------- |
| `radarr_port` (7878)   | tcp      | Web UI  |

## Nginx Reverse Proxy

Set `radarr_nginx_enabled: true` and `radarr_nginx_hostname` to expose the web UI over HTTPS. Certificates are provisioned via the shared `nginx` role's certbot tasks. If the hostname is not the apex, point a DNS record at the host first.

## Backup

The role exposes `radarr_backup_paths` (config only). Add a job in the host inventory to include it:

```yaml
backup_jobs:
    - name: radarr
      repositories: [next_s3]
      paths: "{{ radarr_backup_paths }}"
```

## Troubleshooting

```sh
systemctl --user status radarr
journalctl --user -u radarr -f
podman logs radarr
```
