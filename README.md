# Homelab Ansible Playbooks

This repository contains Ansible playbooks and roles I use to manage my NAS and some VMs 👨‍💻.

This project is designed for personal/familial scale maintenance, if you find this useful for your use, want to share advises or security concerns, feel free to drop me a line.

This is a good playground to learn and I encourage you to adapt these roles to your needs. While they might not be production-ready for all environments, I'm open to adapting them for [Ansible Galaxy](<(https://galaxy.ansible.com)>) if there's community interest!

## Requirements

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

You can also unlock your key system wide to simplify your calls:

```sh
ssh-add ~/.ssh/my_key
# unlock it
ansible-playbook -i inventory/hosts.yml playbook.yml \
--ask-become-pass
```

## Target devices configuration

Requirements:

- sshd up and running
- public key copied:

```sh
ssh-copy-id -i ~/.ssh/id_rsa.pub username@remote_host
```

- python3 installed (`pacman -Syu python3`)

## Developping

Linting:

```sh
ansible-lint
npx prettier --write .
```
