# Homelab Ansible Playbooks

This repository contains Ansible playbooks and roles I use to manage my NAS and some VMs 👨‍💻.

This project is designed for personal/familial scale maintenance, if you find this useful for your use, want to share advises or security concerns, feel free to drop me a line.

This is a good playground to learn and I encourage you to adapt these roles to your needs. While they might not be production-ready for all environments, I'm open to adapting them for [Ansible Galaxy](<(https://galaxy.ansible.com)>) if there's community interest!

## Architecture Overview

**Platform Support:** Arch Linux, Debian/Ubuntu, Darwin (partial)

**Core Design:**

- A unique system administrator (`{{ ansible_user }}`)
- Security hardened sshd
- Shared services pattern: Single PostgreSQL and Valkey (Redis) instances serve all services
- Rootless Podman: Containers run as `{{ ansible_user }}` (daemonless, `sudo podman ps` shows nothing)
- User systemd services: `systemctl --user status <service>` with lingering enabled
- Nginx reverse proxy for web services
- IP Freebind when available (e.g. unbound does not wait for wireguard to be up to start resolving DNS)

**Available Services:**

| Service     | Description                                              |
| ----------- | -------------------------------------------------------- |
| dns         | Unbound caching DNS + Pi-hole ad blocking + VPN resolver |
| nfs         | Network file system server                               |
| zfs         | ZFS installation and management                          |
| uptime-kuma | Uptime monitoring                                        |
| ntfy        | Notification server                                      |
| gitea       | Git server                                               |
| immich      | Photo management                                         |
| static-web  | Static website hosting                                   |
| vpn         | WireGuard server                                         |

And more.

## Port Reservation Rules

Reserved ports that **must not** be used as role defaults:

| Port(s) | Protocol | Reserved for |
| --- | --- | --- |
| 80 | tcp | Nginx |
| 443 | tcp | Nginx |
| 3000-3009 | tcp | Testing |
| 4430 | tcp | Testing |
| 8080 | tcp | Testing |

When adding a new role, pick a default port outside these ranges.

## Requirements

Ansible `>=2.15`

Base tools:

```sh
# linux
apt-get install ansible ansible-lint ansible-galaxy
pacman -Syu ansible ansible-lint ansible-galaxy
# darwin
brew install ansible ansible-lint ansible-galaxy
# windows
choco install ansible ansible-lint ansible-galaxy
```

Other roles:

```sh
ansible-galaxy collection install -r requirements.yml
```

## Usage

If you have a password on your ssh key `--ask-pass` is recommended, `--ask-become-pass` is always asked in these roles, as most tasks require elevated privileges. These are dropped time to time when the default user privilege is enough.

```sh
ansible-playbook -i inventory/hosts.yml playbook.yml \
--ask-pass \
--ask-become-pass \
--ask-vault-pass
```

You can also call you ssh agent to unlock your key prior to simplify your calls:

```sh
ssh-add ~/.ssh/my_key
# unlock it
ansible-playbook -i inventory/hosts.yml playbook.yml \
--ask-become-pass
```

## Bootstrapping a new host

For fresh hosts (only `root` available, no admin user yet):

```sh
ansible-playbook playbooks/bootstrap.yml -l <hostname> --ask-pass
```

This installs Python and sudo, creates `{{ ansible_user }}` with sudo rights, and copies your local `~/.ssh/id_ed25519.pub`. Supports Arch Linux and Debian/Ubuntu.

To use a different SSH key:

```sh
ansible-playbook playbooks/bootstrap.yml -l <hostname> --ask-pass \
  --extra-vars 'bootstrap_ssh_public_key="ssh-ed25519 AAAA..."'
```

Then set a password for the new user (required for sudo `--ask-become-pass`):

```sh
ssh root@<hostname> passwd jambon
```

After that, run the host playbook normally:

```sh
ansible-playbook playbooks/<hostname>.yml --ask-become-pass
```

## Developping

Linting:

```sh
ansible-lint
npx prettier --write .
```

## Contributing

### Role Types

| Type | Examples | Structure |
| --- | --- | --- |
| Containerized web service | immich, gitea, ntfy, uptime_kuma | `defaults/`, `tasks/`, `handlers/`, `templates/{<svc>.yaml.j2, <svc>.service.j2, nginx-vhost.conf.j2}`, `meta/` |
| Shared database (host-level) | postgres, valkey | Single instance, per-app isolated creds, binds `127.0.0.1`, per-app users `NOSUPERUSER,NOCREATEDB,NOCREATEROLE` |
| Native system service | grafana, prometheus, nginx | Like DB services, may include an nginx vhost |

Container service task order: password validation → DB/Valkey setup → project dir → config files → kube YAML → getent home → systemd user dir → service unit → lingering → enable/start → nginx vhost.

### Required Patterns

**Password validation** (any role needing secrets):

```yaml
- name: Validate required passwords are set
  ansible.builtin.assert:
    that:
      - myservice_password is defined
      - myservice_password | length >= 12
    fail_msg: |-
      myservice_password is required (min 12 chars).
      See roles/myservice/defaults/main.yml.
```

Leave passwords undefined in `defaults/main.yml` (`# myservice_password: ""  # Intentionally undefined`).

**User home directory** — resolve via `getent`, not `ansible_env.HOME`:

```yaml
- ansible.builtin.getent: { database: passwd, key: "{{ ansible_user }}" }
- ansible.builtin.set_fact:
    user_home_dir: "{{ ansible_facts['getent_passwd'][ansible_user][4] }}"
```

**Systemd user service** — rootless, `Type=notify`, `--service-container=true`, `restartPolicy: Never` in the pod manifest:

```ini
[Service]
Type=notify
NotifyAccess=all
WorkingDirectory={{ podman_projects_dir }}/myservice
ExecStart=/usr/bin/podman kube play --replace --service-container=true --network=pasta:--map-host-loopback={{ podman_gw_gateway }} myservice.yaml
ExecStop=/usr/bin/podman kube down myservice.yaml
Restart=on-failure
[Install]
WantedBy=default.target
```

Containers reach host `127.0.0.1` services at `{{ podman_gw_gateway }}` (default `100.64.0.1`). Pasta is configured globally in `roles/podman/templates/containers.conf.j2`.

**PostgreSQL for apps** — `community.postgresql.postgresql_user` (with `NOSUPERUSER,NOCREATEDB,NOCREATEROLE`) → `postgresql_db` (owned by the app user) → `postgresql_privs` (`ALL` on schema `public`), all as `become_user: "{{ postgres_admin_user }}"`.

**Valkey ACL user** — define `myservice_valkey_acl` in defaults and add it to the `valkey_acl_users` list in inventory:

```yaml
myservice_valkey_acl:
  username: "{{ myservice_valkey_user }}"
  password: "{{ myservice_valkey_password }}"
  keypattern: "myservice_*"
  commands: "&* -@dangerous +@read +@write +@pubsub +select +auth +ping +info"
```

**Nginx vhost** — deploy to `{{ nginx_conf_dir | default('/etc/nginx/conf.d') }}/myservice.conf`, gated by `myservice_nginx_enabled`, `notify: Reload nginx`; remove with `state: absent` when disabled.

**OS-specific variables** — `vars/archlinux.yml` / `vars/debian.yml`, loaded with:

```yaml
- ansible.builtin.include_vars: "{{ item }}"
  with_first_found:
    - "{{ ansible_facts['os_family'] }}.yml"
    - debian.yml
```

### Conventions

- **Meta deps**: only always-required (`podman`, `postgres`). Never optional (nginx uses a `*_nginx_enabled` flag).
- **Naming**: variables `snake_case`, tasks/handlers Capitalized, files `kebab-case`.
- **Idempotency**: `changed_when: false` for reads, `creates:` for commands that produce files, `set -o pipefail` in shell.
- **Permissions**: config `0644`, secrets `0600`/`0640`, dirs `0755`, data `0750`, systemd units `0644`.
- **Ports**: pick a default outside the reserved ranges above.

## Q&A

### Immich crash loop: `PostgresError: must be owner of extension vector`

Immich tries to self-update the `pgvector` extension at startup, but its database user is intentionally `NOSUPERUSER`, so the `ALTER EXTENSION vector UPDATE` call fails and the microservices worker exits with code 1.

Fix it on the running host by updating the extension as the `postgres` superuser:

```sh
sudo -u postgres psql -d immich -c 'ALTER EXTENSION vector UPDATE;'
```

The Immich role also runs this automatically on subsequent playbook runs, so re-deployments after a pgvector package upgrade do not require manual intervention.
