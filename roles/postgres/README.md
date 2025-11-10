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

## How to Use from Service Roles

### Pattern for Service Roles

When creating a service role that needs PostgreSQL:

**1. Add postgres as a dependency** (`meta/main.yml`):
```yaml
dependencies:
  - role: postgres
```

**2. Define database variables** (`defaults/main.yml`):
```yaml
myservice_db_name: myservice
myservice_db_user: myservice_user
myservice_db_password: changeme  # Use Ansible Vault in production!
myservice_db_host: localhost
myservice_db_port: 5432
```

**3. Create database and user** (`tasks/main.yml`):
```yaml
- name: Create PostgreSQL database for myservice
  community.postgresql.postgresql_db:
    name: "{{ myservice_db_name }}"
    state: present
  become: true
  become_user: "{{ postgres_admin_user }}"

- name: Create PostgreSQL user for myservice
  community.postgresql.postgresql_user:
    name: "{{ myservice_db_user }}"
    password: "{{ myservice_db_password }}"
    db: "{{ myservice_db_name }}"
    priv: ALL
    state: present
  become: true
  become_user: "{{ postgres_admin_user }}"

- name: Ensure user has no superuser privileges
  community.postgresql.postgresql_user:
    name: "{{ myservice_db_user }}"
    role_attr_flags: NOSUPERUSER,NOCREATEDB,NOCREATEROLE
    state: present
  become: true
  become_user: "{{ postgres_admin_user }}"
```

**Note:** `postgres_admin_user` is provided by the postgres role and defaults to `postgres`.

**4. Configure your service** to connect to:
```
Host: localhost
Port: 5432
Database: myservice
User: myservice_user
Password: changeme
```

### Real Example: Immich

See `roles/immich/` for a complete working example of using this pattern.

## Connection Methods

### From Containers

If your service runs in a container (Docker/Podman), you need to:

**Option 1: Use host network mode**
```yaml
network_mode: host
```
Then connect to `localhost:5432`

**Option 2: Use host.containers.internal (Podman/Docker)**
```yaml
DB_HOSTNAME: host.containers.internal
DB_PORT: 5432
```

**Option 3: Bridge with firewall (less secure)**
Bind postgres to `0.0.0.0` and use container gateway IP.

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

### 4. Local-Only Access

PostgreSQL is configured to listen on `localhost` only:
- No remote connections allowed
- Services must run on the same host

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
psql -h localhost -U immich -d immich
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
