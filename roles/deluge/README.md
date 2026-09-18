# Deluge Role

Deploys [Deluge](https://deluge-torrent.org/) - a lightweight BitTorrent client with a web UI - using Podman with k8s files. The `linuxserver/deluge` image runs both `deluged` and `deluge-web`.

## Prerequisites

The `podman` role must have been applied to the host first (shared service, intentionally not declared in `meta/main.yml` to keep deluge deploys fast). Order it before `deluge` in the playbook for fresh installs.

## Role Variables

See `defaults/main.yml` for all available variables and their default values.

## First Login

The web UI listens on `http://<host>:{{ deluge_web_port }}` with the default credentials `admin` / `deluge`. **Change the password immediately** (Preferences → Interface → Password) — the role does not manage it.

Set the inbound port to `{{ deluge_torrent_port }}` under Preferences → Network, otherwise Deluge picks a random port and the mapped torrent port is useless.

## Storage

- `deluge_config_dir` - torrent state, auth and web settings. Backed up.
- `deluge_downloads_dir` - default save path for completed torrents. User data, not backed up.

## Ports

| Port                         | Protocol  | Purpose                        |
| ---------------------------- | --------- | ------------------------------ |
| `deluge_web_port` (8112)     | tcp       | Web UI                         |
| `deluge_torrent_port` (6881) | tcp + udp | Incoming peer traffic, DHT/uTP |

The thin-client daemon port (58846) is not mapped; add it to the pod manifest if a native Deluge client needs to connect.

## Nginx Reverse Proxy

Set `deluge_nginx_enabled: true` and `deluge_nginx_hostname` to expose the web UI over HTTPS. Certificates are provisioned via the shared `nginx` role's certbot tasks. If the hostname is not the apex, point a DNS record at the host first.

## Backup

The role exposes `deluge_backup_paths` (config only). Add a job in the host inventory to include it:

```yaml
backup_jobs:
    - name: deluge
      repositories: [next_s3]
      paths: "{{ deluge_backup_paths }}"
```

## Troubleshooting

```sh
systemctl --user status deluge
journalctl --user -u deluge -f
podman logs deluge
```
