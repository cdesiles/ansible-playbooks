# Immich Role

This Ansible role deploys [Immich](https://immich.app/) - a high performance self-hosted photo and video management solution - using Podman with k8s files.

## Role Variables

See `defaults/main.yml` for all available variables and their default values.

### Required Passwords

Both passwords must be set in your inventory (min 12 characters):

- `immich_postgres_password` - PostgreSQL database password
- `immich_valkey_password` - Valkey/Redis password

## External Libraries

Mount host paths read-only into the server container via `immich_external_libraries`,
then add the in-container `mount_path` in the Immich UI
(Administration → External Libraries). The `{{ ansible_user }}` running the rootless
pod must have read access on the host path.

## Troubleshooting

### Valkey ACL Issues

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

**Going further:** [Immich GitHub Discussion #19727](https://github.com/immich-app/immich/discussions/19727#discussioncomment-13668749)
