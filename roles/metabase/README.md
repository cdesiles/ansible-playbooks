# Metabase

Business intelligence and analytics. Defaults: [`defaults/main.yml`](defaults/main.yml).

## Requirements

- `podman` role
- `postgres` role
- `nginx` role (optional, for public access)

## Usage

Set in inventory:

```yaml
metabase_postgres_password: "strongpassword"
metabase_postgres_host: "{{ podman_gw_gateway }}"
metabase_nginx_enabled: true
metabase_nginx_hostname: metabase.example.com
```
