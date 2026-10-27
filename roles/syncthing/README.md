# syncthing

Installs and configures [Syncthing](https://syncthing.net/) as a system service.
Runs as a dedicated `syncthing` system user via `syncthing@syncthing.service`.

Supports Arch Linux and Debian-based distributions.

Variables: [defaults/main.yml](defaults/main.yml)

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
