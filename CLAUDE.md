# Project Architecture & Patterns

## Limit documentation

- Only one README per role and a general project README.
- Default vars are already documented in ./roles/<role>/defaults/main.yml, no need to document them elsewhere. A link to this file from ./roles/<role>/README.md is sufficient.

## Target Audience

This repository targets **power users, developers, and homelab enthusiasts** who are comfortable with:

- Command-line interfaces and SSH
- Basic networking and Linux system administration
- Reading technical documentation and following references
- Ansible concepts (roles, playbooks, inventory)

**Documentation Philosophy:**

- Straight to the point, no hand-holding
- Minimal redundancy - references between documents preferred
- Assumes familiarity with underlying technologies
- Technical accuracy over verbosity

## Overview

This Ansible repository manages NAS/homelab infrastructure with a focus on:

- **Shared services pattern**: System-level PostgreSQL, Valkey, Nginx
- **Service isolation**: Separate databases and users per service
- **Security first**: Localhost-only access, minimal privileges, fail-fast validation
- **Modularity**: Independent service deployments

## Key Architectural Decisions

### 1. Shared Services Pattern

**Why:** Resource efficiency, easier maintenance, better isolation

**Implementation:**

- Single PostgreSQL instance serves all services
- Single Valkey instance serves all services
- Each service creates its own database/user (PostgreSQL)
- Each service gets its own ACL user (Valkey)

### 2. Multi-Layer Isolation

#### PostgreSQL Isolation

Each service:

- Gets its own database
- Gets its own user with minimal privileges
- Cannot access other services' data

**Security:**

- `NOSUPERUSER`: Cannot create other superusers
- `NOCREATEDB`: Cannot create databases
- `NOCREATEROLE`: Cannot create roles
- `priv: ALL` on own database only

#### Valkey/Redis Isolation

**Important:** Valkey ACL files do NOT support comments. The `users.acl` file must contain only ACL rules, one per line. All documentation should be in role README files, not in the ACL file itself.
Each service gets its own ACL user with:

- Unique credentials (username/password)
- Key pattern restrictions (can only access specific key prefixes)
- Command restrictions (deny dangerous commands like FLUSHDB, KEYS, CONFIG)
- Database number assignment (0-15) for additional logical separation

**Security (ACL-based):**

- Key patterns: `~immich_bull*` restricts access to matching keys only
- Command groups: `-@dangerous` denies FLUSHDB, FLUSHALL, KEYS, CONFIG, etc.
- Selective grants: `+@read +@write +@pubsub` only allows necessary operations
- Channel access: `&*` for pub/sub (job queues like BullMQ)
- Lua scripting: `+eval +evalsha` only when required (e.g., BullMQ)

**Defense-in-depth:**

1. ACL users with restricted permissions (primary)
2. Database number isolation (secondary)
3. Key pattern enforcement (tertiary)

### 3. Container-to-Host Communication

**Challenge:** Containers need to reach system PostgreSQL/Valkey

**Solution:**

- Rootless Podman with `pasta` networking and `--map-host-loopback={{ podman_gw_gateway }}`
- Inside containers, the host's loopback is reachable at `{{ podman_gw_gateway }}` (default `100.64.0.1`)
- Use `host.containers.internal` (resolves to the same address) or the literal gateway IP
- Avoids insecure `network_mode: host`

The default is configured in `/etc/containers/containers.conf` via the
`podman` role:

```ini
[network]
default_rootless_network_cmd = "pasta"
pasta_options = ["--map-host-loopback", "100.64.0.1"]
```

Note: `default_rootless_network_cmd` only affects `podman run`. `podman play
kube` defaults to a bridge network, which rootless users cannot create. Pod
services must pass the flag explicitly on the CLI:

```
ExecStart=/usr/bin/podman play kube --replace \
  --network=pasta:--map-host-loopback={{ podman_gw_gateway }} myservice.yaml
```

### 4. Nginx Reverse Proxy Pattern

**Why:** Independent deployments, zero-downtime reloads

**Implementation:**

- Each service deploys its own vhost config to `{{ nginx_conf_dir }}/<service>.conf`
- Default `nginx_conf_dir: /etc/nginx/conf.d` (configurable in inventory)
- Services control exposure via `<service>_nginx_enabled` variable
- Nginx reloads gracefully when configs change
- **Always use `{{ nginx_conf_dir }}` variable, never hardcode paths**

### 5. OS Abstraction

**Why:** Support multiple distributions (Arch Linux, Debian/Ubuntu)

**Implementation:**

```
roles/postgres/vars/
  ├── archlinux.yml    # Arch-specific (user: postgres, package: postgresql)
  └── debian.yml       # Debian-specific (user: postgres, package: postgresql)
```

Tasks load: `with_first_found: ["{{ ansible_facts['os_family'] }}.yml", "debian.yml"]`

## Creating a New Service Role

### 1. Directory Structure

```
roles/myservice/
├── defaults/main.yml          # Variables
├── tasks/main.yml            # Main tasks
├── handlers/main.yml         # Handlers
├── templates/
│   ├── myservice.yaml.j2     # Kubernetes Pod spec (if containerized)
│   ├── myservice.service.j2  # systemd user unit (if containerized)
│   └── nginx-vhost.conf.j2   # If web-accessible
├── meta/main.yml             # Dependencies
└── README.md                 # Documentation
```

### 2. Meta Dependencies

```yaml
dependencies:
    - role: podman # If using containers
    - role: postgres # If needs database
    - role: redis # If needs cache
```

**Important:** Only include dependencies that are **always** required. Optional dependencies (like nginx for reverse proxy) should be added explicitly in playbooks, not in `meta/main.yml`.

### 3. Rootless Podman and User Systemd Services

**Architecture:** This is a single-user administrative server running rootless Podman. All containerized services:

- Run as `{{ ansible_user }}` (rootless Podman)
- Have files owned by `{{ ansible_user }}`
- Use systemd user services (not system services)
- Require lingering to start at boot without login

**Critical Implementation Details:**

1. **User Systemd Services Template:**

```jinja2
[Unit]
Description=My Service

[Service]
Type=notify
NotifyAccess=all
WorkingDirectory={{ podman_projects_dir }}/myservice
ExecStart=/usr/bin/podman kube play --replace --service-container=true --network=pasta:--map-host-loopback={{ podman_gw_gateway }} myservice.yaml
ExecStop=/usr/bin/podman kube down myservice.yaml
Restart=on-failure
RestartSec=10
TimeoutStartSec=180

[Install]
WantedBy=default.target
```

**Why `podman kube play --service-container=true`:** All containerized
services in this repo use Kubernetes Pod manifests deployed via
`podman kube play`. The `--service-container=true` flag spawns an extra
long-lived container whose lifetime mirrors the pod, so the systemd unit's
main PID stays alive and emits sd_notify. This is what makes
`Type=notify`, `Restart=on-failure`, and `systemctl --user --failed` work
correctly — without it, `kube play` exits 0 immediately and systemd stays
in `active (exited)` forever, even while containers inside the pod
crash-loop. The explicit `--network=pasta:...` flag is required because
`podman kube play` defaults to a bridge network, which rootless users
cannot create (see section 3).

**Do not use** `Type=oneshot` + `RemainAfterExit=true` for podman pods.
That pattern silently hides crash loops from systemd.

**Pod manifest must use `restartPolicy: Never` on every container.**
systemd is the single owner of the restart loop: a container exit takes the
pod down, which takes the service container down, which fails the unit,
which triggers `Restart=on-failure`. With `restartPolicy: Always` or
`OnFailure`, podman retries internally and systemd never sees the failure.

**Future direction:** see `roadmap/2026-05-29-quadlet.md` for the planned migration to
native Podman Quadlet units (`.kube` files), which removes most of this
boilerplate.

**Critical differences from system services:**

- `WantedBy=default.target` (NOT `multi-user.target`)
- No `network-online.target` dependency (doesn't exist in user systemd)
- User services start after the system is up, so network dependencies are implicit

2. **Service File Placement:**

```yaml
- name: Get home directory for {{ ansible_user }}
  ansible.builtin.getent:
      database: passwd
      key: "{{ ansible_user }}"

- name: Set user home directory fact
  ansible.builtin.set_fact:
      user_home_dir: "{{ getent_passwd[ansible_user][4] }}"

- name: Create systemd user directory
  ansible.builtin.file:
      path: "{{ user_home_dir }}/.config/systemd/user"
      state: directory
      owner: "{{ ansible_user }}"
      group: "{{ ansible_user }}"
      mode: "0755"

- name: Deploy systemd service
  ansible.builtin.template:
      src: myservice.service.j2
      dest: "{{ user_home_dir }}/.config/systemd/user/myservice.service"
      owner: "{{ ansible_user }}"
      group: "{{ ansible_user }}"
      mode: "0644"
  notify: Reload systemd user
```

**Why getent + set_fact:** `ansible_env.HOME` is evaluated in the controller/initial context and may resolve to `/root` instead of the target user's home. Using `getent` to query `/etc/passwd` provides the correct home directory (field 4), and storing it in a fact makes subsequent references cleaner and more readable.

3. **Enable Lingering:**

```yaml
- name: Enable lingering for user {{ ansible_user }}
  ansible.builtin.command: "loginctl enable-linger {{ ansible_user }}"
  when: ansible_user != 'root'
```

Lingering ensures the user's systemd instance starts at boot and persists when the user is not logged in.

4. **Service Management:**

```yaml
- name: Enable and start service (user scope)
  ansible.builtin.command: "systemctl --user enable --now myservice.service"
  become_user: "{{ ansible_user }}"
```

**Why `podman play kube`:** Kubernetes Pod manifests are portable and let multiple containers share a network namespace without defining a Compose network. The `--network=pasta:...` CLI flag overrides the default bridge (which rootless users cannot create) and inherits the same loopback mapping configured in `containers.conf`.

### 4. Password Validation Pattern (REQUIRED)

All roles requiring passwords **must** validate them at the start of tasks:

```yaml
- name: Validate required passwords are set
  ansible.builtin.assert:
      that:
          - myservice_password is defined
          - myservice_password | length >= 12
      fail_msg: |
          myservice_password is required (min 12 chars).
          See roles/myservice/defaults/main.yml for configuration instructions.
      success_msg: "Password validation passed"
```

**Why this pattern:**

- Prevents accidental deployment with missing/weak passwords
- Fails fast with clear error message
- Directs users to defaults/main.yml for setup instructions
- Keeps error messages concise (target audience: minimal tech knowledge)

**In defaults/main.yml, passwords should be undefined:**

```yaml
# myservice_password: ""  # Intentionally undefined - role will fail if not set
```

**Never use "changeme" defaults** - always fail if password not explicitly set.

## Best Practices

### Ansible Usage

**`become: true` is redundant** - All playbooks are run with `--ask-become-pass`, so every task already runs with elevated privileges. Only use `become_user` to switch to a specific user (e.g., `become_user: postgres`).

### Security

1. **Passwords**: Always use Ansible Vault in production

    ```bash
    ansible-vault encrypt_string 'password' --name 'myservice_db_password'
    ```

2. **Bind addresses**: PostgreSQL and Redis bind to `127.0.0.1` only

3. **Database users**: Minimal privileges (NOSUPERUSER, NOCREATEDB, NOCREATEROLE)

4. **Nginx**: Only expose services that need external access

### Variable Naming

- Role-specific: `<role>_variable_name`
- Generic (cross-role): Add to `.ansible-lint` skip list

### File Permissions

- Config files: `0644`
- Secrets: `0640` or `0600`
- Directories: `0755`
- Data directories: `0750`

### Idempotency

- Use `creates:` with command/shell
- Use `changed_when: false` for read-only operations
- Use appropriate `when:` conditions

### Handlers

- Use `notify` instead of direct state changes
- Keep in `handlers/main.yml`
- Common: `Reload nginx`, `Restart PostgreSQL`, `Reload systemd`
