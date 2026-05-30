# Samba Server

Minimal SMB/CIFS file sharing, mirroring the design of the `nfs_server` role.

Security is assumed to come from the network (firewall + VPN). No Active
Directory, no Kerberos, no winbind. Standalone server, `tdbsam` backend.

## In a nutshell

**Supports:**

- SMB2/SMB3 over TCP (port 445) and legacy NetBIOS (port 139)
- Per-share access control (`valid_users`, `write_list`, `force_user/group`)
- Optional guest fallback (`map to guest = Bad User`)
- UFW firewall configuration
- `testparm`-validated config before reload
- Idempotent user creation via `smbpasswd`

**Limitations:**

- No Active Directory / Kerberos integration
- Samba user accounts are only **created**, never updated. To rotate a
  password, run `pdbedit -x <username>` first, then rerun the playbook.
- The matching system user (`/etc/passwd`) must already exist; this role
  does not create UNIX accounts.

## Inventory

```yaml
# Bind only to private interfaces
samba_bind_interfaces_only: true
samba_interfaces:
  - lo
  - lan0
  - 192.168.1.161

# UNIX users must exist beforehand (e.g. via the `users` role
# or manual `useradd`). This role only manages the SMB password.
samba_users:
  - username: alice
    password: "{{ vault_alice_smb_password }}"
  - username: bob
    password: "{{ vault_bob_smb_password }}"

samba_shares:
  - name: photos
    path: /mnt/andromeda/family-photos
    comment: "Family photos"
    read_only: false
    valid_users: ["alice", "bob"]
    write_list: ["alice"]
    force_user: alice
    force_group: users

  - name: public
    path: /mnt/andromeda/public
    comment: "Read-only public share"
    guest_ok: true
    read_only: true

samba_server_firewall_allowed_sources:
  - 192.168.1.0/24
  - 192.168.27.0/27
```

See [`defaults/main.yml`](./defaults/main.yml) for all variables and defaults.

## Resources

- https://wiki.archlinux.org/title/Samba
- https://wiki.samba.org/index.php/Setting_up_Samba_as_a_Standalone_Server
- `man smb.conf`, `man smbpasswd`, `man pdbedit`
