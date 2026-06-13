# nut — Network UPS Tools

Monitors a UPS over USB (or serial/network), notifies via ntfy on power events
and gracefully shuts the host down on low battery.

## Supported distributions

- Arch Linux
- Debian/Ubuntu

## What it does

- Installs `nut` and configures it in **standalone** mode (single host, no
  network slaves).
- Configures the `usbhid-ups` driver against the UPS defined in `nut_ups_name`
  (default: EATON Ellipse 1600, vendorid `0463`).
- Binds `upsd` to `127.0.0.1:3493` only — no LAN exposure.
- Runs `upsmon` as master, which:
  - calls `SHUTDOWNCMD` (`systemctl poweroff`) on `LOWBATT`,
  - dispatches every event to a `NOTIFYCMD` wrapper that POSTs to ntfy with
    severity, tags and a host-aware title.

## Configuration

Variables — see [defaults/main.yml](defaults/main.yml).

Required (role asserts at start):

```yaml
nut_monitor_password: "<min 12 chars>"  # local upsd user used by upsmon + exporter
nut_ntfy_topic: "ups-<host>"
```

Optional but commonly tweaked:

```yaml
nut_ups_name: eaton
nut_ups_description: "EATON Ellipse 1600"
nut_ups_vendorid: "0463"
nut_ntfy_server: https://ntfy.jokester.fr
nut_ntfy_token: "tk_..."  # publish token for nut_ntfy_topic
```

## Operations

### Check UPS status

```bash
upsc {{ nut_ups_name }}@localhost
```

### List configured UPSes

```bash
upsc -l
```

### Test the NOTIFYCMD pipeline without unplugging

```bash
sudo -u nut NOTIFYTYPE=ONBATT /usr/local/bin/ups-notify "Simulated ONBATT for ntfy plumbing test"
```

### Simulate a full power loss (DANGEROUS — actually powers off)

```bash
sudo upsmon -c fsd
```

### Logs

```bash
journalctl -u nut-monitor -u nut-server -u 'nut-driver@*' -f
```

## Security

- `upsd` binds to `127.0.0.1` only.
- `upsd.users` mode `0640` owned by `root:nut`.
- No anonymous read access — exporter and upsmon both authenticate as
  `nut_monitor_user`.
- udev rules shipped by the `nut` package grant USB device access to the `nut`
  group only.

## Companion role

See [`nut_exporter`](../nut_exporter/README.md) to expose Prometheus metrics
based on the same upsd instance.
