# OpenCode Role

Two independent modes, usable on different hosts:

- **Server** (`opencode_server_enabled`): installs `opencode` (Arch `extra`), runs `opencode web|serve` as a user systemd service (`{{ ansible_user }}`, lingering), opens `opencode_port` in UFW for `opencode_firewall_allowed_sources`.
- **Reverse proxy** (`opencode_nginx_enabled`): nginx vhost forwarding `opencode_nginx_hostname` to `opencode_nginx_upstream` (may be another host), optional Let's Encrypt.

`web` and `serve` expose the same API on the same port; `web` adds the browser UI. Both are protected by HTTP basic auth (`OPENCODE_SERVER_USERNAME` / `OPENCODE_SERVER_PASSWORD`, rendered to `~/.config/opencode/server.env`, `0600`).

The service runs with `{{ ansible_user }}`'s full privileges (shell, files): only expose it behind auth + TLS.

## Prerequisites

- Server: `sshd` role (installs/enables UFW).
- Proxy: `nginx` role; public DNS record pointing at the proxy before enabling `opencode_nginx_letsencrypt`.

## Example

```yaml
# pinwheel (server)
opencode_server_enabled: true
opencode_server_password: "{{ vault_pinwheel_opencode_server_password }}"
opencode_firewall_allowed_sources:
    - { src: "192.168.2.1/32", comment: "OpenCode from andromeda" }

# andromeda (proxy)
opencode_nginx_enabled: true
opencode_nginx_hostname: oc.example.org
opencode_nginx_letsencrypt: true
opencode_nginx_upstream: "http://192.168.2.14:4096"
```

## Usage

```bash
opencode attach https://oc.example.org   # CLI/TUI client
systemctl --user status opencode
journalctl --user -u opencode -f
```

Provider credentials (`opencode auth login`) are stored per user on the server host and are not managed here.

## Configuration Variables

See [defaults/main.yml](defaults/main.yml).
