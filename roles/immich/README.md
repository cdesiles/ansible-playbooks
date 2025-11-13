# Immich Role

This Ansible role deploys [Immich](https://immich.app/) - a high performance self-hosted photo and video management solution - using Podman with docker-compose files.

## Requirements

- Podman installed on the target system (handled by the `podman` role dependency)
- Podman compose support (`podman compose` command available)
- Sufficient disk space for photos/videos at the upload location

## Role Variables

See `defaults/main.yml` for all available variables and their default values.

### Key Configuration Requirements

#### Required Passwords

Both passwords must be set in your inventory (min 12 characters):
- `immich_postgres_password` - PostgreSQL database password
- `immich_valkey_password` - Valkey/Redis password

#### Valkey ACL Configuration

**Important:** Immich requires a dedicated Valkey ACL user with specific permissions. This role provides the ACL configuration, but you must register it with the Valkey role.

**Required Setup in Inventory:**

Add the Immich user to your `valkey_acl_users` list in your inventory or host_vars:

```yaml
# inventory/host_vars/yourserver.yml or group_vars/all.yml
valkey_acl_users:
  - username: immich
    password: "{{ immich_valkey_password }}"
    keypattern: "immich_bull* immich_channel*"
    commands: "&* -@dangerous +@read +@write +@pubsub +select +auth +ping +info +eval +evalsha"
```

**ACL Breakdown:**
- `keypattern: "immich_bull* immich_channel*"` - Restricts access to BullMQ keys used by Immich
- `&*` - Allow all pub/sub channels (required for BullMQ job queues)
- `-@dangerous` - Deny dangerous commands (FLUSHDB, FLUSHALL, KEYS, etc.)
- `+@read +@write` - Allow read/write command groups
- `+@pubsub` - Allow pub/sub commands (SUBSCRIBE, PUBLISH, etc.)
- `+select` - Allow SELECT command (database switching)
- `+auth +ping +info` - Connection management commands
- `+eval +evalsha` - Lua scripting (required by BullMQ for atomic operations)

**Based on:** [Immich GitHub Discussion #19727](https://github.com/immich-app/immich/discussions/19727#discussioncomment-13668749)

**Security Benefits:**
- Immich cannot access keys from other services
- Cannot execute admin commands (FLUSHDB, CONFIG, etc.)
- Cannot view all keys (KEYS command denied)
- Defense-in-depth with ACL + key patterns + database numbers

#### External Network Configuration

Immich requires a dedicated external network to be defined in your inventory. Add this to your `host_vars` or `group_vars`:

```yaml
podman_external_networks:
  - name: immich
    subnet: 172.20.0.0/16
    gateway: 172.20.0.1
```

**How it works:**
1. Define the Immich network in `podman_external_networks` list in your inventory
2. The `podman` role (a dependency) creates the external network before Immich deployment
3. The Immich docker-compose file references this external network
4. The network persists across container restarts and compose stack rebuilds

## Dependencies

This role depends on:
- `podman` - Container runtime
- `postgres` - PostgreSQL database
- `valkey` - Redis-compatible cache (formerly Redis)

**Note:** The Valkey role must be configured with the Immich ACL user (see Valkey Configuration section above) before running this role.

## Example Playbook

```yaml
---
- hosts: servers
  become: true
  roles:
    - role: podman
    - role: immich
      vars:
        immich_postgres_password: "your-secure-postgres-password"
        immich_valkey_password: "your-secure-valkey-password"
        immich_upload_location: /mnt/storage/immich/upload
        immich_timezone: America/New_York
```

**Complete Example with Valkey ACL:**

In `inventory/host_vars/yourserver.yml`:

```yaml
# Podman external networks
podman_external_networks:
  - name: immich
    subnet: 172.20.0.0/16
    gateway: 172.20.0.1

# Valkey admin password
valkey_admin_password: "your-valkey-admin-password"

# Valkey ACL users - register all service users here
valkey_acl_users:
  - username: immich
    password: "{{ immich_valkey_password }}"
    keypattern: "immich_bull* immich_channel*"
    commands: "&* -@dangerous +@read +@write +@pubsub +select +auth +ping +info +eval +evalsha"
  # Add other services here as needed

# Immich passwords
immich_postgres_password: "your-secure-postgres-password"
immich_valkey_password: "your-secure-valkey-password"
```

In your playbook:

```yaml
---
- hosts: servers
  become: true
  roles:
    - role: valkey    # Must run first to create ACL users
    - role: postgres
    - role: podman
    - role: immich
```

## Architecture

The role deploys Immich using Podman containers that connect to shared system services:

**Immich Containers:**
1. **immich-server** - Main application server (exposed on configured port)
2. **immich-machine-learning** - ML service for facial recognition and object detection

**Shared System Services:**
3. **PostgreSQL** - Database with vector extensions (from `postgres` role)
4. **Valkey** - Redis-compatible cache (from `valkey` role)

### Container Networking

Both Immich containers run on a **dedicated external Podman network** with its own CIDR block. The network is created by the `podman` role as an external network, referenced in the compose file:

```yaml
networks:
  immich:
    external: true
    name: immich
```

The actual network configuration (subnet: `172.20.0.0/16`, gateway: `172.20.0.1`) is handled by the podman role based on the `immich_network_*` variables.

This provides:
- **Network isolation**: Separate subnet (defined in inventory, e.g., `172.20.0.0/16`) from other containers
- **Network persistence**: Network survives compose stack rebuilds and container recreation
- **Named bridge**: Explicit interface naming for the network
- **Container-to-container communication**: The server reaches the ML container via service name (`immich-machine-learning:3003`) using Docker/Podman internal DNS
- **Container-to-host communication**: Both containers can reach PostgreSQL and Valkey on the host via `host.containers.internal:{{ podman_subnet_gateway }}`

**Key Points:**
- The network must be defined in your inventory via `podman_external_networks`
- The network is created by the `podman` role before Immich deployment (via role dependency)
- The Immich network has its own gateway (e.g., `172.20.0.1` as defined in inventory)
- `extra_hosts` maps `host.containers.internal` to the **Podman default bridge gateway** (e.g., `10.88.0.1`), not the Immich network gateway
- This allows containers to route to the host machine for PostgreSQL/Valkey access

**Checking the network:**
```bash
# List all Podman networks
podman network ls

# Inspect the Immich network
podman network inspect immich
```

### Data Isolation

The role implements proper data isolation for both database backends:

- **PostgreSQL**: Immich gets its own database (`immich`) and dedicated user (`immich`) with restricted privileges (NOSUPERUSER, NOCREATEDB, NOCREATEROLE)
- **Valkey**: Immich uses a dedicated ACL user (`immich`) with:
  - Dedicated password (independent from `valkey_admin_password`)
  - Key pattern restriction (`immich_bull*` and `immich_channel*` only)
  - Command restrictions (no admin/dangerous operations like FLUSHDB, CONFIG)
  - Database number isolation (uses DB 0 by default, configurable)
  - Pub/sub channel access for BullMQ job queues

**Security Benefits:**
- Each service has unique credentials
- Compromised service cannot access other services' data
- Cannot accidentally delete all data (FLUSHDB/FLUSHALL denied)
- Cannot view keys from other services (KEYS command denied)
- Defense-in-depth: ACL + key patterns + command restrictions + database numbers

The compose file is deployed to `{{ podman_projects_dir }}/immich/docker-compose.yml` and managed via a systemd service.

## Post-Installation

After deployment:

1. Access Immich at `http://<host-ip>:2283`
2. Create an admin account on first login
3. Configure mobile/desktop apps to point to your server

## Management

The role creates a systemd service for managing the compose stack:

```bash
# Check status
systemctl status immich

# Stop Immich
systemctl stop immich

# Start Immich
systemctl start immich

# Restart Immich
systemctl restart immich

# View logs for all containers
cd /opt/podman/immich && podman compose logs -f

# View logs for specific service
cd /opt/podman/immich && podman compose logs -f immich-server
```

### Manual Management

You can also manage containers directly with podman compose:

```bash
cd /opt/podman/immich

# Start services
podman compose up -d

# Stop services
podman compose down

# Pull latest images
podman compose pull

# Recreate containers
podman compose up -d --force-recreate
```

## Updating Immich

To update to a newer version:

1. Update the `immich_version` variable in your playbook or inventory
2. Re-run the Ansible playbook
3. The systemd service will restart with the new version

Or manually:

```bash
cd /opt/podman/immich
podman compose pull
systemctl restart immich
```

## Storage

- **Upload location**: Stores all photos, videos, and thumbnails
- **Database location**: PostgreSQL data (not suitable for network shares)
- **Model cache**: ML models for facial recognition

Ensure adequate disk space and regular backups of these directories.

## Files Deployed

- `{{ podman_projects_dir }}/immich/docker-compose.yml` - Compose definition
- `/etc/systemd/system/immich.service` - Systemd service unit

## Security Considerations

- **Set strong passwords** for both `immich_postgres_password` and `immich_valkey_password` (min 12 chars)
- **Use Ansible Vault** to encrypt passwords in production:
  ```bash
  ansible-vault encrypt_string 'your-password' --name 'immich_postgres_password'
  ansible-vault encrypt_string 'your-password' --name 'immich_valkey_password'
  ```
- **Configure Valkey ACL** properly (see Valkey Configuration section) - do not use `+@all`
- Consider using a reverse proxy (nginx/traefik) for HTTPS
- Restrict access via firewall rules if needed
- Keep Immich updated by changing `immich_version` and redeploying

## Troubleshooting

### Check service status
```bash
systemctl status immich
```

### View compose file
```bash
cat /opt/podman/immich/docker-compose.yml
```

### Check container status
```bash
cd /opt/podman/immich
podman compose ps
```

### View logs
```bash
cd /opt/podman/immich
podman compose logs
```

### Valkey ACL Issues

**Error: "NOPERM No permissions to access a channel"**
- The Valkey ACL is missing channel permissions
- Ensure `&*` or `+allchannels` is in the ACL commands
- Verify ACL is properly loaded: `valkey-cli ACL LIST`

**Error: "NOAUTH Authentication required"**
- Check `immich_valkey_password` is set correctly
- Verify the password matches in both inventory ACL config and immich vars

**Error: "WRONGPASS invalid username-password pair"**
- Ensure the Immich user is registered in `valkey_acl_users`
- Check the Valkey ACL file was deployed: `cat /etc/valkey/users.acl`
- Restart Valkey to reload ACL: `systemctl restart valkey`

**Verify Valkey ACL Configuration:**
```bash
# Connect as admin
valkey-cli
AUTH default <valkey_admin_password>

# List all ACL users
ACL LIST

# Check specific user
ACL GETUSER immich

# Monitor commands (useful for debugging permissions)
MONITOR
```

**Test Immich user credentials:**
```bash
valkey-cli
AUTH immich <immich_valkey_password>
SELECT 0
PING
# Should return PONG

# Try a restricted command (should fail)
FLUSHDB
# Should return: (error) NOPERM
```

## License

MIT

## Author Information

Created for deploying Immich on NAS systems using Podman and docker-compose.
