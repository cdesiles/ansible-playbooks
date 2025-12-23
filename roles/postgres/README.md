# PostgreSQL Role

Installs and configures PostgreSQL as a shared database service for multiple applications with isolated databases and users.

## Features

- Shared PostgreSQL instance (system service)
- Per-service database isolation
- Per-service user privileges (minimal permissions)
- Container access support (via Podman gateway)
- Configurable logging backend (journald or files)
- Performance tuning presets

## Architecture Pattern

**Decentralized database management:**

- PostgreSQL role: Installs and configures the server
- Service roles: Create their own databases/users (e.g., immich, nextcloud)
- Isolation: Each service user can only access their own database

See `CLAUDE.md` for detailed architecture documentation.

## Container Access

For containers to reach PostgreSQL:

PostgreSQL binds to `127.0.0.1` by default (secure, localhost-only).

Containers can reach PostgreSQL via Pasta's `--map-host-loopback` feature, which routes container's `127.0.0.1` to the host's `127.0.0.1`.

In docker-compose files, use:

```yaml
extra_hosts:
    - "postgres.local:127.0.0.1"
```

No additional bind addresses or firewall rules needed!

## Logging Backends

**journald (default):**

- Logs via stderr → systemd journal
- View: `journalctl -u postgresql -f`

**file:**

- Logs to data directory or `/var/log/postgresql/`
- Automatic logrotate configuration

Switch via `postgres_log_backend` variable.

## Hands-on Commands

```bash
# Connect to PostgreSQL
sudo -u postgres psql

# List databases
sudo -u postgres psql -c '\l'

# List users and permissions
sudo -u postgres psql -c '\du'

# Test connection
psql -h localhost -U myservice_user -d myservice_db

# View logs (journald)
journalctl -u postgresql -f
journalctl -u postgresql -p err

# View logs (file - Arch)
tail -f /var/lib/postgres/data/log/postgresql-*.log

# View logs (file - Debian)
tail -f /var/log/postgresql/postgresql-*.log

# Check listen addresses
sudo -u postgres psql -c "SHOW listen_addresses;"

# Performance settings
sudo -u postgres psql -c "SHOW shared_buffers;"
sudo -u postgres psql -c "SHOW effective_cache_size;"
```

## References

- [PostgreSQL Documentation](https://www.postgresql.org/docs/current/)
- [PostgreSQL Logging](https://www.postgresql.org/docs/current/runtime-config-logging.html)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Tuning_Your_PostgreSQL_Server)
- [pg_hba.conf Documentation](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html)
