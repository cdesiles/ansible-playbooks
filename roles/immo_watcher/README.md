# immo_watcher - Real-Estate Alert Watcher

Deploys getitfirst's `immo-watcher` image, pulled from this repository's registry, as a rootless Podman pod: it reads the watcher's mailbox over IMAP every 2 minutes, judges the listings in the websites' alert emails and publishes them to ntfy (`immo`, its own problems on `sys-alerts`). It listens on no port and only connects out, to the mailbox and to ntfy.

Variables: [defaults/main.yml](defaults/main.yml)

## Prerequisites

- The `podman` role applied to the host first.
- The `docker_registry` role deployed, and its hostname reachable from the host itself: `curl -sI https://<registry>/v2/` answers `401`. The host's own public name may not loop back through the router; if it doesn't, the host must resolve it locally.
- The image pushed by getitfirst as `<registry>/immo-watcher:<version>`, for the host's platform: `linux/amd64` on x86_64 (getitfirst cross-builds from the arm64 laptop), or multi-arch. A wrong-architecture image restarts in a loop with `exec format error`.

## Releases

1. getitfirst builds and pushes `<registry>/immo-watcher:<version>`.
2. Bump `immo_watcher_version` in the host inventory.
3. `ansible-playbook playbooks/<host>.yml --tags immo_watcher`.

Like the other roles, every run pulls the pinned tag and restarts the pod when the image changed. The read-only registry account lands in `{{ podman_projects_dir }}/immo-watcher/auth.json` (`0600`), used by that pull and by the unit's `kube play` should it have to pull again at start (an image pruned while the pod was down).

## First deployment

1. On the ntfy host, once. The ntfy role only manages its admin:

    ```sh
    podman exec -it ntfy ntfy user add immo-watcher            # any long password: the token is used
    podman exec ntfy ntfy access immo-watcher immo write-only
    podman exec ntfy ntfy access immo-watcher sys-alerts write-only
    podman exec ntfy ntfy access <phone-user> immo read-only   # the user the phone's ntfy app signs in with
    podman exec ntfy ntfy token add immo-watcher               # prints tk_…
    ```

2. Into the host's vault, pasting each value then Ctrl-D (the mailbox app password is `IMAP_PASSWORD` in `getitfirst/immo-watcher/.env`):

    ```sh
    ansible-vault encrypt_string --stdin-name vault_immo_watcher_ntfy_token
    ansible-vault encrypt_string --stdin-name vault_immo_watcher_imap_password
    ```

3. In the host inventory:

    ```yaml
    immo_watcher_version: "0.1.0"
    immo_watcher_imap_user: "<the watcher's mailbox>"
    immo_watcher_imap_password: "{{ vault_immo_watcher_imap_password }}"
    immo_watcher_ntfy_token: "{{ vault_immo_watcher_ntfy_token }}"
    immo_watcher_registry_username: ci-reader # a registry_users entry with actions [read]
    immo_watcher_registry_password: "{{ vault_registry_ci_reader_password }}"
    ```

4. The playbook, as in [Releases](#releases). Read [First start](#first-start) before.
5. Check:

    ```sh
    systemctl --user status immo-watcher
    journalctl --user -u immo-watcher               # the first pass, then "Sent N notifications"
    podman exec immo-watcher immo-watcher health    # OK: the last pass was N s ago
    ```

    The pod resolves `ntfy.jokester.fr` through the host's resolver: "Sent N notifications" in the log is what proves the path from there.

## First start

The mailbox already holds about 36 emails. The first pass takes them all as new and sends 5 listings at once, plus about 12 short notes for the emails no reader handles yet (Leboncoin, Bien'ici, newsletters). A good first test.

To skip them, make the first start one quiet pass, which stores everything as already sent and sends nothing, then deploy again to start `watch`:

```sh
ansible-playbook playbooks/<host>.yml --tags immo_watcher -e '{"immo_watcher_args": ["run", "--quiet"]}'
ansible-playbook playbooks/<host>.yml --tags immo_watcher
```

The pass runs in the pod itself, with the same image, environment, data folder and user mapping as `watch`. The unit goes inactive once it's done; the second run starts `watch`.

Only one watcher may run, or every notification comes twice: stop `make watch` on the laptop first. To carry the laptop's state over instead of the quiet pass, put its database in the data folder before the first deploy:

```sh
ssh <host> 'mkdir -p -m 0750 /opt/podman/immo-watcher/data'
scp data/watcher.sqlite <host>:/opt/podman/immo-watcher/data/
```

## Usage

```sh
podman exec immo-watcher immo-watcher listings    # the stored homes worth a look (--all: every one)
podman exec immo-watcher immo-watcher health
journalctl --user -u immo-watcher -f
systemctl --user restart immo-watcher
```

## Storage and backup

`immo_watcher_data_dir` (`0750`) holds `watcher.sqlite`, every website's email as it came (`emails/<website>/*.eml`, with personal tracking links) and `heartbeat`. The role exposes `immo_watcher_backup_paths`, `_exclude` and `_sqlite`; `watcher.sqlite` is dumped with `sqlite3 .backup` rather than copied. Add a job in the host inventory:

```yaml
backup_jobs:
    - name: immo-watcher
      repositories: [next_s3]
      paths: "{{ immo_watcher_backup_paths }}"
      exclude: "{{ immo_watcher_backup_exclude }}"
      sqlite: "{{ immo_watcher_backup_sqlite }}"
      schedule: "*-*-* 02:30:00" # daily
```

The job fails until the watcher has started once and created its database.

## Restarts and health

- `restartPolicy: Never` sits at pod level, the only level podman reads, and the unit runs `kube play --service-exit-code-propagation=any`: a container that exits non-zero fails the unit and systemd's `Restart=on-failure` brings it back. A configuration error (exit 1 at start) shows as a restart every 10 s.
- The liveness probe (`immo-watcher health`, every 120 s) only marks the container `unhealthy` in `podman ps`: under `restartPolicy: Never` podman acts on no probe. The watcher reports its own failing passes on `sys-alerts`.
