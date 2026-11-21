# fdroid - F-Droid Custom APK Repository

Deploys an [F-Droid](https://f-droid.org/) repository server to host custom APKs for family devices, with the [cdesiles/fdroidserver](https://github.com/cdesiles/fdroidserver) image.

Variables: [defaults/main.yml](defaults/main.yml)

## Usage

### Adding APKs

```bash
scp my-app.apk <user>@<host>:/opt/podman/fdroid/data/repo/
```

The container re-runs `fdroid update -c` every `fdroid_update_interval`: new APKs get their metadata and the index is signed again.

To trigger an immediate update:

```bash
ssh <user>@<host> "podman exec fdroid fdroid update -c"
```

### F-Droid Client Setup

On family phones, open F-Droid and add a new repository:

- **Repository URL:** `https://apk.jokester.fr/repo`
- Accept the fingerprint on first connection

### Keystore Backup

The signing keystore at `{{ podman_projects_dir }}/fdroid/data/keystore.p12` is critical. If lost, all clients must re-add the repository. Back it up.

### Releases

The image's CI publishes `ghcr.io/cdesiles/fdroidserver:<fdroidserver version>-<build>` on every commit to `main`. Pin the tag to deploy as `fdroid_version` in the host inventory, then run the playbook: every run pulls the pinned tag and restarts the pod when the image changed.

## Architecture

- **Image**: `ghcr.io/cdesiles/fdroidserver` (~360 MB). Its default command serves `repo/`, mounted read-only, with busybox httpd and runs `fdroid update -c` every `fdroid_update_interval`
- **Storage**: Persistent data directory for keystore, config, metadata, and APKs
- **Networking**: host port `fdroid_port` on all interfaces (no `hostIP`), no UFW rule opened; nginx reverse proxy for HTTPS
- **Index updates**: Automatic on configurable interval

## Dependencies

- podman
- nginx (if `fdroid_nginx_enabled: true`)
