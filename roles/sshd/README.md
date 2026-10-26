# SSH server

Installs and hardens OpenSSH, manages `authorized_keys`, and optionally owns the
firewall (UFW).

## Firewall

Set `sshd_ufw_enabled: false` to leave the firewall to the platform (e.g. a
vendor NAS OS); the role then installs no UFW package and creates no rules.
`ssh_allowed_networks` is still the rule set used when the flag is true.

## Authorized keys

`sshd_authorized_keys` (list, default empty) installs public keys for every user
in `ssh_users` **before** the hardened `sshd_config` is written. Empty leaves
`authorized_keys` untouched, which keeps hosts whose keys are provisioned out of
band working unchanged.

When the list is non-empty, the role asserts that each user ends up with a
`~/.ssh/authorized_keys` before switching to `AuthenticationMethods publickey`,
so a key-less account cannot be locked out. Keys are added, never removed:
pre-existing keys keep working, which is what makes a key rotation safe.

```yaml
sshd_authorized_keys:
  - "{{ bootstrap_ssh_public_key }}"
```

## Configuration file

The rendered `sshd_config` replaces the distribution file and deliberately does
**not** include `/etc/ssh/sshd_config.d/*.conf`, so vendor or imager drop-ins
cannot weaken the hardening. Overrides belong in this role's template or in host
vars. The file is validated with `sshd -t -f` before being installed.

Settings that matter in practice:

- `AuthenticationMethods publickey`, `PermitRootLogin no`, `AllowUsers {{ ssh_users }}`
- Idle sessions are disconnected after ~10 min: `ClientAliveInterval 300` ×
  `ClientAliveCountMax 2`
- No agent/TCP/X11 forwarding, `PermitUserEnvironment no`, `StrictModes yes`

## Enable authorized_keys fallback

When you encrypt your home data, you cannot allow hardened remote SSH connection.
To make this still possible, here is the trick: a fallback authorized_key file: /etc/ssh/authorized_keys/myuser

Simply enable this setting to get this working:

```
ssh_authorized_keys_fallback_enabled: true
```

And you're set.
