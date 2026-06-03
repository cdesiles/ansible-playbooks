# syncthing

Installs and configures [Syncthing](https://syncthing.net/) as a system service.
Runs as a dedicated `syncthing` system user via `syncthing@syncthing.service`.

Supports Arch Linux and Debian-based distributions.

## Required variables

Set these in `inventory/host_vars/<host>.yml`:

```yaml
syncthing_gui_user: admin
syncthing_gui_password: "{{ vault_syncthing_gui_password }}"
```

`syncthing_gui_password` must be at least 12 characters. Set the actual value
in your vault file and reference it via `vault_syncthing_gui_password`.
Syncthing will bcrypt-hash the password on first start.

## Optional variables

See `defaults/main.yml` for the full list. Key options:

| Variable                    | Default                        | Description                        |
|-----------------------------|--------------------------------|------------------------------------|
| `syncthing_user`            | `syncthing`                    | OS user to run syncthing as        |
| `syncthing_home`            | `/var/lib/syncthing`           | Home directory for the system user |
| `syncthing_config_dir`      | `{{ syncthing_home }}/.config/syncthing` | Config directory      |
| `syncthing_gui_bind`        | `0.0.0.0`                      | GUI listen address                 |
| `syncthing_gui_port`        | `8384`                         | GUI listen port                    |
| `syncthing_port`            | `22000`                        | Sync protocol port (TCP)           |
| `syncthing_allowed_networks` | `[]`                          | UFW rules for GUI and sync ports   |

## Notes

- `config.xml` is written only on first run — the task is skipped on subsequent
  runs if the file already exists. Syncthing manages the file after that (device
  ID, folder config, hashed password). Re-running the playbook is safe.
- Folder and device pairing must be done via the Syncthing web UI or REST API
  after the service is running.
- The GUI binds to `0.0.0.0` by default — use `syncthing_allowed_networks` to
  restrict access via UFW to specific LAN/VPN ranges.

## Debian notes

The `syncthing` package in some Debian versions may be outdated. Consider adding
the [official APT repository](https://apt.syncthing.net/) before applying this role.
