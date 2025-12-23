# Redis/Valkey Role

This Ansible role installs and configures Valkey (a Redis fork) for local use only. It provides a shared Redis-compatible instance that multiple services can use as a cache or message broker.

The role also performs required kernel tuning for optimal Valkey performance.

## About Valkey

Valkey is a high-performance key/value datastore and a drop-in replacement for Redis. It was created as a community-driven fork after Redis changed its license from BSD to proprietary licenses (RSALv2 and SSPLv1) in March 2024.

**Key points:**

- Valkey is 100% API-compatible with Redis
- Backed by the Linux Foundation
- Uses permissive open-source license (BSD 3-Clause)
- No code changes needed in your applications
- Same commands, same protocol, same performance

**Distribution support:**

- **Arch Linux**: Installs Valkey (redis package replaced in April 2024)
- **Debian/Ubuntu**: Installs Valkey from official repositories

## Features

- Installs Redis/Valkey
- Local-only access (localhost)
- Configurable memory limits and eviction policies
- Persistence enabled
- Systemd integration
- Automatic kernel tuning (memory overcommit, THP)
- ACL-based user authentication
- Firewall configuration (UFW)

## Requirements

- Systemd-based Linux distribution
- Root/sudo access
- `ansible.posix` collection (for sysctl module)
- `community.general` collection (for ufw module)

## Role Variables

See `defaults/main.yml` for all available variables and their default values.

### Key Configuration Requirements

#### Required Password

The `valkey_admin_password` variable must be set in your inventory (min 12 characters). The role will fail if not set.

#### ACL Users

Service users must be registered via the `valkey_acl_users` list. See the ACL Configuration Guide section below for details.

#### Container Access

Valkey binds to `127.0.0.1` by default (secure, localhost-only).

Containers can reach Valkey via Pasta's `--map-host-loopback` feature, which routes container's `127.0.0.1` to the host's `127.0.0.1`.

In docker-compose files, use:

```yaml
extra_hosts:
    - "host.containers.internal:127.0.0.1"
```

No additional bind addresses needed!

**System Requirements:** This role automatically configures kernel parameters (`vm.overcommit_memory=1`) and transparent hugepage settings

## Dependencies

None.

## Example Playbook

```yaml
---
- hosts: servers
  become: true
  roles:
      - role: valkey
      - role: immich # Will connect to system Valkey
```

### Custom Configuration with ACL Users

```yaml
---
- hosts: servers
  become: true
  roles:
      - role: valkey
        vars:
            valkey_admin_password: "{{ vault_valkey_password }}"
            valkey_maxmemory: 512mb
            valkey_maxmemory_policy: volatile-lru
            valkey_acl_users:
                - username: immich
                  password: "{{ immich_valkey_password }}"
                  keypattern: "immich_bull* immich_channel*"
                  commands: "&* -@dangerous +@read +@write +@pubsub +select +auth +ping +info +eval +evalsha"
                - username: nextcloud
                  password: "{{ nextcloud_valkey_password }}"
                  keypattern: "nextcloud*"
                  commands: "+@read +@write -@dangerous +auth +ping +info"
```

## How Services Connect

Services running on the same host can connect to Valkey at:

- **Host**: `localhost` or `127.0.0.1`
- **Port**: `6379` (default)

### From Containers

Containers need special handling to reach the host's Valkey:

**Use `host.containers.internal`:**

```yaml
REDIS_HOSTNAME: host.containers.internal
REDIS_PORT: 6379
```

This special DNS name resolves to the host machine from inside containers.

**Note:** Environment variables often still use `REDIS_*` naming for compatibility, since Valkey is API-compatible with Redis.

## Security

- **Local-only**: Valkey binds to `127.0.0.1` only (configurable for container access)
- **Protected mode**: Enabled
- **ACL authentication**: Each service gets its own user with restricted permissions
- **No remote access**: Cannot be reached from network by default

### ACL-Based Authentication

This role uses Valkey's ACL (Access Control List) system for fine-grained security. Each service gets:

- **Dedicated credentials**: Unique username and password
- **Key pattern restrictions**: Can only access specific key patterns
- **Command restrictions**: Limited to required commands only
- **Defense-in-depth**: Multiple layers of isolation

### Configuring ACL Users

Define ACL users in your inventory or host_vars:

```yaml
# inventory/host_vars/yourserver.yml
valkey_admin_password: "your-strong-admin-password"

valkey_acl_users:
    - username: immich
      password: "{{ immich_valkey_password }}"
      keypattern: "immich_bull* immich_channel*"
      commands: "&* -@dangerous +@read +@write +@pubsub +select +auth +ping +info +eval +evalsha"

    - username: nextcloud
      password: "{{ nextcloud_valkey_password }}"
      keypattern: "nextcloud*"
      commands: "+@read +@write -@dangerous +auth +ping +info"

    - username: gitea
      password: "{{ gitea_valkey_password }}"
      keypattern: "gitea*"
      commands: "+@read +@write -@dangerous +auth +ping +info +select"
```

### ACL Configuration Guide

**Key Pattern (`keypattern`):**

- Single pattern: `"myservice*"` - matches keys starting with `myservice`
- Multiple patterns: `"pattern1* pattern2*"` - space-separated (automatically converted to `~pattern1* ~pattern2*` in ACL file)
- All keys: `"*"` - not recommended for security

**Note:** In the inventory, specify patterns as space-separated strings. The Ansible template automatically adds the `~` prefix to each pattern when generating the ACL file.

### Kernel Tuning

The role automatically configures kernel parameters required by Valkey (see `tasks/kernel-tuning.yml`):

**1. Memory Overcommit:**

```
vm.overcommit_memory = 1
```

- Required for background saves and replication
- Configured via `/etc/sysctl.conf`
- Applied immediately and persists across reboots

**2. Transparent Huge Pages (THP):**

```
transparent_hugepage=madvise
```

- Reduces latency and memory usage issues
- Safely appended to existing GRUB kernel parameters (does not overwrite)
- Only adds parameter if `transparent_hugepage=` is not already present
- Applied at runtime immediately via `/sys/kernel/mm/transparent_hugepage/enabled`
- Persists across reboots via `/etc/default/grub`
- Automatically detects and uses `update-grub` (Debian) or `grub-mkconfig` (Arch)

These settings are required to eliminate Valkey startup warnings and ensure optimal performance.

**Note:** The role preserves existing GRUB parameters. If you have `GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"`, it will become `GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet transparent_hugepage=madvise"`.

**Commands (`commands`):**

- `&*` - Allow all pub/sub channels (required for job queues like BullMQ)
- `+allchannels` - Alternative to `&*`
- `+@read` - Allow all read commands (GET, MGET, etc.)
- `+@write` - Allow all write commands (SET, DEL, etc.)
- `+@pubsub` - Allow pub/sub commands (SUBSCRIBE, PUBLISH, etc.)
- `-@dangerous` - Deny dangerous commands (FLUSHDB, FLUSHALL, KEYS, CONFIG, etc.)
- `+commandname` - Allow specific command (e.g., `+select`, `+auth`, `+ping`)
- `-commandname` - Deny specific command

**Common Command Sets:**

| Service Type           | Recommended Commands                                                              |
| ---------------------- | --------------------------------------------------------------------------------- |
| **Simple cache**       | `+@read +@write -@dangerous +auth +ping +info`                                    |
| **Session store**      | `+@read +@write -@dangerous +auth +ping +info +select`                            |
| **Job queue (BullMQ)** | `&* -@dangerous +@read +@write +@pubsub +select +auth +ping +info +eval +evalsha` |
| **Pub/sub**            | `+@pubsub +@read +@write -@dangerous +auth +ping +info`                           |

**Security Best Practices:**

- Always include `-@dangerous` to prevent accidental data loss
- Use specific key patterns to isolate services
- Only grant `+eval` and `+evalsha` if required (job queues)
- Only grant `&*` or `+allchannels` if using pub/sub
- Use unique passwords for each service

### Setting Secure Passwords

Use Ansible Vault to encrypt all passwords:

```bash
# Admin password
ansible-vault encrypt_string 'your-strong-admin-password' --name 'valkey_admin_password'

# Service passwords
ansible-vault encrypt_string 'immich-password' --name 'immich_valkey_password'
ansible-vault encrypt_string 'nextcloud-password' --name 'nextcloud_valkey_password'
```

Add encrypted values to your inventory:

```yaml
valkey_admin_password: !vault |
    $ANSIBLE_VAULT;1.1;AES256
    ...

immich_valkey_password: !vault |
    $ANSIBLE_VAULT;1.1;AES256
    ...
```

## Service Management

```bash
# Check status
systemctl status redis        # Debian/Ubuntu
systemctl status valkey       # Arch Linux

# Restart service
systemctl restart redis       # Debian/Ubuntu
systemctl restart valkey      # Arch Linux

# View logs
journalctl -u redis -f        # Debian/Ubuntu
journalctl -u valkey -f       # Arch Linux

# Connect to CLI (both systems have redis-cli compatibility)
redis-cli                     # Works on both
valkey-cli                    # Also available on Arch Linux
```

## Persistence

Valkey is configured with RDB persistence:

- Save after 900 seconds if at least 1 key changed
- Save after 300 seconds if at least 10 keys changed
- Save after 60 seconds if at least 10000 keys changed

Data is stored in `{{ valkey_dir }}` (default: `/var/lib/valkey`)

## Memory Management

When `valkey_maxmemory` is reached, Valkey will behave based on `valkey_maxmemory_policy`:

- `noeviction`: Return errors when memory limit is reached (default, recommended for BullMQ/job queues)
- `allkeys-lru`: Evict least recently used keys (good for pure caching)
- `volatile-lru`: Evict LRU keys with TTL set
- `allkeys-random`: Evict random keys
- `volatile-random`: Evict random keys with TTL

**Important for Immich and BullMQ:**
Services using BullMQ for job queues (like Immich) require `noeviction` policy. Evicting job queue data can cause:

- Lost background tasks
- Failed job processing
- Data corruption

Only use eviction policies (`allkeys-lru`, etc.) for pure caching use cases where data loss is acceptable.

## Monitoring

Check Valkey info (authenticate as admin):

```bash
redis-cli
AUTH default <valkey_admin_password>
INFO
INFO memory
INFO stats
```

Check connected clients:

```bash
redis-cli
AUTH default <valkey_admin_password>
CLIENT LIST
```

View ACL configuration:

```bash
redis-cli
AUTH default <valkey_admin_password>
ACL LIST                    # List all users
ACL GETUSER immich          # View specific user permissions
ACL GETUSER default         # View admin user
ACL CAT                     # List all command categories
```

Check generated ACL file:

```bash
cat /etc/valkey/users.acl
# Example output:
# user default on >password ~* &* +@all
# user immich on >password ~immich_bull* ~immich_channel* &* -@dangerous +@read ...
# Note: Multiple patterns appear as separate ~pattern entries
```

## Troubleshooting

### Check if Valkey is running

```bash
systemctl status valkey         # Arch Linux
systemctl status valkey-server  # Debian/Ubuntu
```

### Test admin connection

```bash
# With authentication (default user)
redis-cli
AUTH default <valkey_admin_password>
PING
# Should return: PONG
```

### Test service user connection

```bash
# Test Immich user
redis-cli
AUTH immich <immich_valkey_password>
SELECT 0
PING
# Should return: PONG

# Try restricted command (should fail)
FLUSHDB
# Should return: (error) NOPERM This user has no permissions to run the 'flushdb' command
```

### View ACL configuration

```bash
# Check ACL file
cat /etc/valkey/users.acl

# Check runtime ACL
redis-cli
AUTH default <valkey_admin_password>
ACL LIST
ACL GETUSER immich
```

### Debug permission issues

```bash
# Monitor all commands (useful for debugging)
redis-cli
AUTH default <valkey_admin_password>
MONITOR
# In another terminal, run your application
# You'll see all commands being executed
```

### View configuration

```bash
redis-cli
AUTH default <valkey_admin_password>
CONFIG GET "*"
```

### Check memory usage

```bash
redis-cli
AUTH default <valkey_admin_password>
INFO memory
```

### Common ACL Errors

**"NOAUTH Authentication required"**

- Client didn't authenticate
- Service needs to set `REDIS_USERNAME` and `REDIS_PASSWORD`

**"WRONGPASS invalid username-password pair"**

- Incorrect username or password
- Verify ACL user exists: `ACL GETUSER username`
- Check password in inventory matches service configuration

**"NOPERM No permissions to run the 'command' command"**

- Command not allowed in ACL
- Check ACL: `ACL GETUSER username`
- Add required command to `commands:` in inventory

**"NOPERM No permissions to access a key"**

- Key doesn't match allowed patterns
- Check key pattern: `ACL GETUSER username`
- Verify service is using correct key prefix

**"NOPERM No permissions to access a channel"**

- Pub/sub channel not allowed
- Add `&*` or `+allchannels` to ACL commands
- Required for BullMQ and other job queues

## Performance Tuning

For high-traffic services, consider:

```yaml
valkey_maxmemory: 1gb # Increase memory limit
valkey_maxmemory_policy: noeviction # No eviction (for job queues)
# Or for pure caching:
# valkey_maxmemory_policy: allkeys-lru  # LRU eviction
```

**Kernel Tuning (automatically configured):**
The role automatically sets optimal kernel parameters:

- Memory overcommit enabled (`vm.overcommit_memory=1`)
- Transparent Huge Pages set to `madvise`

To verify kernel settings:

```bash
# Check memory overcommit
sysctl vm.overcommit_memory
# Should show: vm.overcommit_memory = 1

# Check THP status
cat /sys/kernel/mm/transparent_hugepage/enabled
# Should show: always [madvise] never
```

## License

MIT

## Author Information

Created for managing shared Valkey instances in NAS/homelab environments.

## Multi-Layer Isolation Strategy

This role implements **defense-in-depth** with three isolation layers:

### 1. ACL Users (Primary Isolation)

Each service gets its own user with restricted permissions:

- Unique credentials
- Key pattern restrictions
- Command restrictions

### 2. Database Numbers (Secondary Isolation)

Valkey provides 16 logical databases (0-15) for additional isolation:

| Service   | Database | Key Pattern                      | ACL User    |
| --------- | -------- | -------------------------------- | ----------- |
| Immich    | 0        | `immich_bull*` `immich_channel*` | `immich`    |
| Nextcloud | 1        | `nextcloud*`                     | `nextcloud` |
| Gitea     | 2        | `gitea*`                         | `gitea`     |
| Grafana   | 3        | `grafana*`                       | `grafana`   |
| Custom    | 4-15     | Custom                           | Custom      |

### 3. Key Prefixes (Tertiary Isolation)

Services use unique key prefixes enforced by ACL patterns.

### Testing Isolation

```bash
# Test as Immich user (database 0)
redis-cli
AUTH immich <immich_valkey_password>
SELECT 0
SET immich_bull_test "data"
# Success

# Try to access other service's keys (should fail)
GET nextcloud_test
# Success (key doesn't exist, not a permission error)
# But ACL prevents SET on non-matching patterns:
SET nextcloud_test "data"
# Error: NOPERM No permissions to access a key

# Try dangerous command (should fail)
FLUSHDB
# Error: NOPERM This user has no permissions to run the 'flushdb' command
```

### Complete Example Configuration

```yaml
# inventory/host_vars/myserver.yml
valkey_admin_password: "{{ vault_valkey_admin_password }}"

valkey_acl_users:
    # Immich - Photo management (needs BullMQ job queue)
    - username: immich
      password: "{{ vault_immich_valkey_password }}"
      keypattern: "immich_bull* immich_channel*"
      commands: "&* -@dangerous +@read +@write +@pubsub +select +auth +ping +info +eval +evalsha"

    # Nextcloud - Simple caching
    - username: nextcloud
      password: "{{ vault_nextcloud_valkey_password }}"
      keypattern: "nextcloud*"
      commands: "+@read +@write -@dangerous +auth +ping +info +select"

    # Gitea - Session store
    - username: gitea
      password: "{{ vault_gitea_valkey_password }}"
      keypattern: "gitea*"
      commands: "+@read +@write -@dangerous +auth +ping +info +select"

# Service variables
immich_valkey_db: 0
nextcloud_valkey_db: 1
gitea_valkey_db: 2
```

### Best Practices

- **ACL first**: Always use ACL users with key pattern restrictions
- **Database numbers**: Use for additional logical separation
- **Key prefixes**: Enforce via ACL patterns, not trust
- **Document**: Keep a table of service assignments
- **Testing**: Reserve database 15 for testing/debugging
- **Monitor**: Use `MONITOR` to verify services stay within their patterns
