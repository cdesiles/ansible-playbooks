# backup

Encrypted, deduplicated, incremental backups with [restic](https://restic.readthedocs.io/).

Variables: [defaults/main.yml](defaults/main.yml)

## Model

Two independent lists, related many-to-many.

- A **repository** is a destination: a restic repository URL, credentials, retention policy.
- A **job** is a source set: paths and databases, plus the repositories it pushes to.

One job feeds several destinations from a single set of dumps. That is what makes 3-2-1 expressible without dumping the same database twice.

`repository` is `RESTIC_REPOSITORY` verbatim, so any backend restic supports works:

| repository URL | destination |
| --- | --- |
| `s3:https://host/bucket/prefix` | object storage |
| `/local/path` | filesystem directory |
| `sftp:user@host:/path` | remote server over SSH |
| `rest:https://host:8000/` | rest-server |

Credentials for a backend are passed through the `env` mapping, exported as written. A repository that also declares `mountpoint` is a removable device, mounted on demand and unmounted after the run.

### What goes where

The **what** of a backup (which files, which databases, how to dump them consistently) is owned by the service role, not this one. The ntfy role knows its storage layout — that `user.db` is durable but `cache.db` is ephemeral, and that `user.db` must be dumped with `sqlite3 .backup` rather than copied — so it publishes a manifest in its own defaults:

```yaml
# roles/ntfy/defaults/main.yml
ntfy_backup_paths:   ["{{ ntfy_data_dir | dirname }}"]
ntfy_backup_exclude: ["{{ ntfy_cache_dir }}/cache.db*", "{{ ntfy_data_dir }}/user.db*"]
ntfy_backup_sqlite:  ["{{ ntfy_data_dir }}/user.db"]
```

The **where** (repositories, retention, schedule) is operator policy, decided in the inventory:

```yaml
backup_jobs:
  - name: ntfy
    repositories: [offsite]
    paths: "{{ ntfy_backup_paths }}"
    exclude: "{{ ntfy_backup_exclude }}"
    sqlite: "{{ ntfy_backup_sqlite }}"
```

This keeps the storage knowledge in one place (the service role), so a change to ntfy's layout cannot silently drift from its backup. The inventory stays a single, auditable list of jobs and policy. There is no role-to-role dependency — only a naming convention: a service that wants backing up declares `<service>_backup_paths` / `_exclude` / `_sqlite` / `_postgres` in its defaults, and the inventory references them. Role defaults load at play-compile time, so a targeted `--tags backup` still sees them.

## Why restic and not borg

borg 1.x has no S3 backend. The S3 connector lives in [borgstore](https://github.com/borgbackup/borgstore), used only by the Borg 2 beta, whose own README states there are no data migration tools while the format is unstable. Reaching S3 with borg means keeping a local repository and mirroring it with rclone — two stages, double the disk, and a `sync` that can propagate a local corruption to the only offsite copy.

restic reaches all three destinations natively. All operations here stay behind `repo_backup`, `repo_forget` and `repo_check` in `templates/backup.sh.j2`, so adding a second engine later is a contained change.

SFTP and rest-server are supported by the `repository` URL with no role changes — they are simply not used in this inventory yet.

## Configuration

```yaml
# inventory/host_vars/<host>/vars.yml
backup_repositories:
  - name: offsite
    repository: "s3:https://s3.fr1.next.ink/lisez-next/{{ inventory_hostname }}"
    password: "{{ vault_backup_offsite_password }}"
    env:
      AWS_ACCESS_KEY_ID: "{{ vault_backup_s3_access_key }}"
      AWS_SECRET_ACCESS_KEY: "{{ vault_backup_s3_secret_key }}"
      AWS_DEFAULT_REGION: fr1
    retention:
      keep_weekly: 4
    read_data_subset: "5%"
    notify:
      server: https://ntfy.jokester.fr
      topic: backups
      token: "{{ vault_backup_ntfy_token }}"

  # Removable disk, skipped without error when not plugged in.
  # - name: usb
  #   repository: /mnt/backup-usb/restic
  #   uuid: 1234-5678-90ab
  #   mountpoint: /mnt/backup-usb
  #   fstype: ext4
  #   password: "{{ vault_backup_usb_password }}"
  #   retention:
  #     keep_weekly: 12
  #   notify:
  #     topic: backups-reminders   # low-priority reminder, not an alarm

backup_jobs:
  - name: ntfy
    repositories: [offsite]
    paths: "{{ ntfy_backup_paths }}"
    exclude: "{{ ntfy_backup_exclude }}"
    sqlite: "{{ ntfy_backup_sqlite }}"
```

Generate the repository password and **store it outside this repository and outside the machine being backed up**:

```bash
openssl rand -base64 32
ansible-vault encrypt_string '<password>' --name 'vault_backup_offsite_password'
```

Losing it means losing every snapshot. There is no recovery path, and a password kept only in a vault on the host being backed up protects nothing after that host dies.

Two hosts must never share a repository — keep their `repository` paths distinct. A restic repository is not designed for concurrent writers from different machines.

## Sources

| key | behaviour |
| --- | --- |
| `paths` / `exclude` | files, straight into the snapshot |
| `sqlite: [path…]` | dumped with `sqlite3 ".backup"` |
| `postgres: [db…]` or `all` | `pg_dump -Fc` per database, plus `pg_dumpall --globals-only` |
| `command:` | escape hatch, `$DUMPS` points at the staging dir |

A job needs at least one source. `paths` alone is fine, as is `postgres` alone.

### Databases are dumped, not copied

Copying a database file while the service is writing produces a torn copy. SQLite keeps recent writes in a `-wal` sidecar, PostgreSQL in its own WAL. The result restores cleanly and is silently inconsistent — the worst possible failure mode, because you only discover it when you need it.

So the live file is excluded from `paths` and a consistent dump is written into the staging directory instead:

```
<dumps>/<job>/sqlite/opt/podman/ntfy/data/user.db     # mirrors the source path
<dumps>/<job>/postgres/<db>.dump
<dumps>/<job>/postgres/globals.sql
```

The staging directory is wiped before and after every run, so plaintext dumps never linger.

`globals.sql` carries roles, grants and tablespaces. Without it a restored dump has no owners to grant privileges to.

## Operations

```bash
# Run a job now and watch it
sudo systemctl start backup@ntfy.service
sudo journalctl -u backup@ntfy.service -f

# Timers
systemctl list-timers 'backup@*'

# Any interactive restic command: source the repository environment first
sudo -i
set -a; . /etc/backup/repos/offsite.env; set +a

restic snapshots
restic snapshots --tag ntfy
restic stats
restic check --read-data
```

## Restore

```bash
sudo -i
set -a; . /etc/backup/repos/offsite.env; set +a

restic snapshots --tag ntfy
restic restore <snapshot-id> --target /tmp/restore     # inspect first
restic restore latest --tag ntfy --target /            # restore in place
```

`--target /` writes absolute paths back where they came from. Restore to a scratch directory first unless you are certain.

Browsing without extracting:

```bash
restic mount /mnt/restic     # FUSE, read-only
```

### From a device repository

The disk must be attached and mounted first — the automatic mount only happens during a backup run:

```bash
mount /dev/disk/by-uuid/<uuid> /mnt/backup-usb
set -a; . /etc/backup/repos/usb.env; set +a
restic snapshots
```

### On a machine that never ran this role

Nothing host-specific is needed. Install restic and point it at the repository:

```bash
export RESTIC_REPOSITORY='s3:https://s3.fr1.next.ink/lisez-next/omega'
export RESTIC_PASSWORD='<password>'
export AWS_ACCESS_KEY_ID='...'
export AWS_SECRET_ACCESS_KEY='...'
export AWS_DEFAULT_REGION='fr1'
restic snapshots
```

### Restoring ntfy

```bash
sudo systemctl --user -M jokester@ stop ntfy.service

sudo -i
set -a; . /etc/backup/repos/offsite.env; set +a
restic restore latest --tag ntfy --target /tmp/ntfy-restore

# Config and attachments
rsync -a /tmp/ntfy-restore/opt/podman/ntfy/ /opt/podman/ntfy/

# The consistent user.db copy lives under the staging path, not in place
install -o jokester -g jokester -m 0644 \
  /tmp/ntfy-restore/var/lib/backup/dumps/ntfy/sqlite/opt/podman/ntfy/data/user.db \
  /opt/podman/ntfy/data/user.db
rm -f /opt/podman/ntfy/data/user.db-wal /opt/podman/ntfy/data/user.db-shm

sudo systemctl --user -M jokester@ start ntfy.service
```

Deleting the stale `-wal`/`-shm` sidecars matters: a fresh `user.db` next to an old WAL is a corrupt pair.

### Restoring PostgreSQL

```bash
sudo -u postgres psql -f <restored>/postgres/globals.sql
sudo -u postgres createdb immich
sudo -u postgres pg_restore -d immich <restored>/postgres/immich.dump
```

## Design notes

### One job, several destinations

Dumps are produced once and pushed to each repository in turn. A failure on one destination is recorded and the remaining ones are still attempted; the unit exits non-zero if any failed, and the notification lists which.

### A missing device is a skip, not a failure

If `/dev/disk/by-uuid/<uuid>` is absent the destination is skipped and the run still succeeds. Alerting every week about a disk that lives in a drawer trains you to ignore the alerts that matter.

If *every* destination of a job is skipped, that is reported — silence there would be indistinguishable from a successful backup.

### Locking

- **Per repository** (`/run/backup/repo-<name>.lock`): two jobs sharing a destination queue; jobs on different destinations run in parallel.
- **Per job** (`/run/backup/job-<name>.lock`, non-blocking): a second run of the same job exits immediately rather than fighting over the staging directory. systemd already prevents this for timer-driven runs; the lock covers manual invocation.

### Retention

Retention lives on the repository, because a large local disk should keep more history than metered object storage. `restic forget` is scoped with `--tag <job>`, so a weekly job cannot prune the snapshots of a daily one sharing the repository. `--prune` runs in the same invocation, otherwise unreferenced data is never reclaimed.

Every snapshot is a logically complete view; "incremental" describes only how it is stored. `keep_weekly: 4` gives four complete, independently restorable backups.

### Integrity checks

`restic check` runs after every backup: structure, indexes and metadata. Setting `read_data_subset` (e.g. `"5%"`) additionally re-hashes that fraction of the pack files, so the whole repository gets verified over time without paying for a full read on every run.

### Excludes that are easy to get wrong

The role always excludes restic's own cache, and the staging directories of *other* jobs — otherwise a job backing up `/var` would sweep up both.

### Monitoring

After each run the script writes Prometheus metrics into node_exporter's
textfile directory (`backup_metrics_dir`), re-exposed by the exporter:

```
backup_last_success_timestamp_seconds{backup_job="ntfy", repo="next_s3"}
backup_last_run_timestamp_seconds{backup_job="ntfy", repo="next_s3", result="success|fail|skip"}
```

This is what turns "silence" into a signal: ntfy alerts on failures, but a
timer that stopped firing (or a job that's been failing for a week) looks the
same as success unless you track `backup_last_success_timestamp_seconds`. The
Grafana "Backups - Restic" dashboard and the `BackupStale` /
`BackupTimerSilent` Prometheus rules (deployed by the prometheus role) consume
these. Metrics are written only when `backup_metrics_dir` exists, i.e. when
node_exporter is deployed on the host.

### Failure notification

Each repository can carry a `notify` channel: `{ topic, server, token, notify_success }`. A repository with `notify.topic` alerts on that destination's own result — an offsite failure is `urgent`, a missing USB disk is a low-priority `warning`, and a destination without `notify` is silent. Success alerts are opt-in per channel (`notify_success`), off by default because routine chatter trains you to ignore the failure alerts.

A job-level failure (a database dump, before any destination runs) alerts the first repository's channel, so order a job's repositories with the primary channel first.

Every configured channel gets a test notification during the play. ntfy runs with `auth-default-access: deny-all`, so a token lacking write access to the topic would otherwise fail silently at 03:00 — this surfaces it at deploy time instead.

### What this does not do

- **No automated restore test.** An untested backup is a hypothesis. Restore one by hand, on a schedule.
- **No append-only protection.** The host holds credentials that can delete its own snapshots, so an attacker with root can destroy the backups too. Mitigate with object versioning or an object-lock policy on the bucket, which is outside this role.
