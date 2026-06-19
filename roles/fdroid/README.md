# fdroid - F-Droid Custom APK Repository

Deploys an [F-Droid](https://f-droid.org/) repository server using [austozi/fdroidserver](https://github.com/austozi/docker-fdroidserver) to host custom APKs for family devices.

## Configuration

### Required Variables

Set in inventory or vault:

```yaml
fdroid_keystore_password: "your-secure-password-here"  # Min 12 chars
```

### Optional Variables

See [defaults/main.yml](defaults/main.yml) for all configuration options.

Key settings:

```yaml
fdroid_version: "26.2.1"
fdroid_port: 8070
fdroid_repo_url: "https://apk.jokester.fr/repo"
fdroid_repo_name: "F-Droid Repository"
fdroid_repo_description: "Custom APK repository"
fdroid_update_interval: "12h"

# Nginx reverse proxy
fdroid_nginx_enabled: false
fdroid_nginx_hostname: apk.nas.local
```

## Usage

### Adding APKs

```bash
scp my-app.apk jokester@andromeda:/opt/podman/fdroid/data/repo/
```

The container automatically re-runs `fdroid update` every `fdroid_update_interval` (default: 12h) to regenerate the signed index.

To trigger an immediate update:

```bash
ssh jokester@andromeda "podman exec fdroid-server fdroid update -c"
```

### F-Droid Client Setup

On family phones, open F-Droid and add a new repository:

- **Repository URL:** `https://apk.jokester.fr/repo`
- Accept the fingerprint on first connection

### Keystore Backup

The signing keystore at `{{ podman_projects_dir }}/fdroid/data/keystore.p12` is critical. If lost, all clients must re-add the repository. Back it up.

## Architecture

- **Container**: `austozi/fdroidserver` (Apache + fdroidserver + Android build-tools)
- **Storage**: Persistent data directory for keystore, config, metadata, and APKs
- **Networking**: Localhost binding, nginx reverse proxy for HTTPS
- **Index updates**: Automatic on configurable interval

## Dependencies

- podman
- nginx (if `fdroid_nginx_enabled: true`)
