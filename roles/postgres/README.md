# PostgreSQL Role

This Ansible role installs and configures PostgreSQL for local use only. It provides a shared PostgreSQL instance that multiple services can use with isolated databases and users.

## Features

- Installs PostgreSQL
- Local-only access (localhost)
- Configurable performance settings
- Each service manages its own database/user (see below)

## Requirements

- Systemd-based Linux distribution
- Root/sudo access
- Python `psycopg2` package (for database operations from service roles)

## Role Variables

Available variables with defaults (see `defaults/main.yml`):

```yaml
# PostgreSQL admin user
postgres_admin_user: postgres

# PostgreSQL admin password (REQUIRED - must be set explicitly)
# postgres_admin_password: ""  # Intentionally undefined

# PostgreSQL data directory
postgres_data_dir: /var/lib/postgres/data

# Network configuration
postgres_listen_addresses: 127.0.0.1  # For container access: "127.0.0.1,{{ podman_subnet_gateway }}"
postgres_port: 5432

# Firewall configuration
postgres_firewall_allowed_sources:
  - 127.0.0.0/8  # Localhost
  - "{{ podman_subnet | default('10.88.0.0/16') }}"  # Podman bridge network

# Performance tuning
postgres_shared_buffers: 256MB
postgres_effective_cache_size: 1GB
postgres_maintenance_work_mem: 64MB
postgres_work_mem: 4MB
postgres_max_connections: 100
```

## Dependencies

None.

## Example Playbook

```yaml
---
- hosts: servers
  become: true
  roles:
    - role: postgres
    - role: immich  # Will create its own database
    - role: nextcloud  # Will create its own database
```

## Database Isolation Strategy

This role follows a **decentralized database management** pattern:

### 1. PostgreSQL Role Responsibility
- Install and configure PostgreSQL
- Manage global performance settings
- Ensure the service is running

### 2. Service Role Responsibility
Each service role (immich, nextcloud, etc.) manages its own:
- Database creation
- User creation
- Password management
- Schema migrations

### 3. Security & Isolation

**Database Isolation:**
- Each service gets its own database
- Example: `immich`, `nextcloud`, `gitea`

**User Isolation:**
- Each service gets its own PostgreSQL user
- Users can only access their own database
- Example: `immich` → `immich` database only

**Authentication:**
- Each user has a unique password
- Passwords stored in service role variables (use Ansible Vault for production)

## Connection Methods

### From Containers

If your service runs in a container (Docker/Podman), you need to configure PostgreSQL to listen on the Podman bridge gateway:

**Step 1: Configure PostgreSQL in inventory**
```yaml
# inventory/host_vars/yourserver.yml
postgres_listen_addresses: "127.0.0.1,{{ podman_subnet_gateway }}"
postgres_firewall_allowed_sources:
  - 127.0.0.0/8
  - "{{ podman_subnet }}"
```

**Step 2: Use host.containers.internal in containers**
```yaml
# docker-compose.yml
services:
  myservice:
    extra_hosts:
      - "host.containers.internal:host-gateway"
    environment:
      DB_HOSTNAME: host.containers.internal
      DB_PORT: 5432
```

**What this does:**
- PostgreSQL listens on `127.0.0.1` (localhost) and `10.88.0.1` (Podman gateway)
- UFW firewall allows connections from localhost and Podman subnet
- `pg_hba.conf` automatically configured to allow Podman subnet
- `host.containers.internal` resolves to the gateway IP inside containers

### From System Services

Services running directly on the host can connect to `localhost:5432` without any special configuration.

## Security Best Practices

### 1. Use Ansible Vault for Passwords

```bash
# Create encrypted variables
ansible-vault encrypt_string 'my_secure_password' --name 'immich_db_password'
```

Add to your inventory or vars:
```yaml
immich_db_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          ...encrypted...
```

### 2. Unique Passwords per Service

Never reuse passwords between services:
```yaml
immich_db_password: unique_password_1
nextcloud_db_password: unique_password_2
gitea_db_password: unique_password_3
```

### 3. Minimal Privileges

The pattern above ensures users have:
- ✅ Access to their database only
- ❌ No superuser privileges
- ❌ Cannot create databases
- ❌ Cannot create roles
- ❌ Cannot access other databases

### 4. Controlled Access

PostgreSQL default configuration:
- Listens on `localhost` only by default
- To allow container access, set `postgres_listen_addresses` to include Podman gateway
- UFW firewall rules automatically configured for allowed sources
- `pg_hba.conf` automatically configured for Podman subnet when enabled
- No remote network access by default

## Troubleshooting

### Check PostgreSQL status
```bash
systemctl status postgresql
```

### Connect to PostgreSQL
```bash
sudo -u postgres psql
```

### List databases
```sql
\l
```

### List users and permissions
```sql
\du
```

### Test connection from service
```bash
# From localhost
psql -h localhost -U immich -d immich

# From Podman gateway (if configured)
psql -h 10.88.0.1 -U immich -d immich

# Check listen addresses
sudo -u postgres psql -c "SHOW listen_addresses;"

# Check firewall rules
sudo ufw status | grep 5432

# Check pg_hba.conf
sudo grep -v "^#" /var/lib/postgres/data/pg_hba.conf | grep -v "^$"
```

### View logs
```bash
journalctl -u postgresql -f
```

## Performance Tuning

Adjust variables based on your hardware:

**For systems with 4GB RAM:**
```yaml
postgres_shared_buffers: 1GB
postgres_effective_cache_size: 3GB
```

**For systems with 16GB RAM:**
```yaml
postgres_shared_buffers: 4GB
postgres_effective_cache_size: 12GB
```

**Rule of thumb:**
- `shared_buffers`: 25% of total RAM
- `effective_cache_size`: 50-75% of total RAM

## Backup Recommendations

Consider implementing:
1. **pg_dump** for logical backups
2. **WAL archiving** for point-in-time recovery
3. **Automated backup scripts** via cron

Example backup script for a service:
```bash
pg_dump -h localhost -U immich immich > /backup/immich_$(date +%Y%m%d).sql
```

## License

MIT

## Author Information

Created for managing shared PostgreSQL instances in NAS/homelab environments.
