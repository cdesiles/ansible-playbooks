# Homelab Ansible Playbooks

This repository contains Ansible playbooks and roles I use to manage my NAS and some VMs 👨‍💻.

This project is designed for personal/familial scale maintenance, if you find this useful for your use, want to share advises or security concerns, feel free to drop me a line.

This is a good playground to learn and I encourage you to adapt these roles to your needs. While they might not be production-ready for all environments, I'm open to adapting them for [Ansible Galaxy](<(https://galaxy.ansible.com)>) if there's community interest!

## Architecture Overview

**Platform Support:** Arch Linux, Debian/Ubuntu

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
# macos
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
--ask-become-pass
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

## Q&A

### Immich crash loop: `PostgresError: must be owner of extension vector`

Immich tries to self-update the `pgvector` extension at startup, but its database user is intentionally `NOSUPERUSER`, so the `ALTER EXTENSION vector UPDATE` call fails and the microservices worker exits with code 1.

Fix it on the running host by updating the extension as the `postgres` superuser:

```sh
sudo -u postgres psql -d immich -c 'ALTER EXTENSION vector UPDATE;'
```

The Immich role also runs this automatically on subsequent playbook runs, so re-deployments after a pgvector package upgrade do not require manual intervention.
