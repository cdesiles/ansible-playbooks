# moOde — appliance layer

Manages the parts of a [moOde audio player](https://moodeaudio.org) host that its
WebUI does not own: file-sharing services, extra `config.txt` lines, update
awareness, Raspberry Pi power/thermal metrics and idle power-off.

Variables: [defaults/main.yml](defaults/main.yml)

## Layer ownership

| Owner | Files / areas |
| --- | --- |
| moOde WebUI | audio chain (`/boot/firmware/config.txt` outside the Ansible block, MPD, ALSA, CamillaDSP), renderers, network config, library, **software updates** |
| Ansible (this role) | `fs_smb` / `fs_nfs` state + unit masking, `config.txt` block, update check timer, `vcgencmd` metrics, idle power-off |
| Ansible (other roles) | `sshd`, `zsh`, `ntp_chrony`, `node_exporter`, `marantz_rc5` |

Never template moOde-owned files from Ansible: the worker rewrites them from its
SQLite config and the two would fight. `config.txt` gets a marked block only
(see [Boot config](#boot-config)).

## File sharing

`fs_smb` and `fs_nfs` in `cfg_system` are set from
`moode_sharing_smb_enabled` / `moode_sharing_nfs_enabled` (both `false` by
default), then `smbd`, `nmbd`, `wsdd2` and `nfs-server` are stopped, disabled and
**masked**. Masking is deliberate: a WebUI toggle or an update cannot re-expose
the card until an operator unmasks. moOde's own worker already disables
`smbd`/`nmbd`/`wsdd2` at boot when sharing is off, so this matches upstream
behaviour rather than fighting it.

To re-enable sharing, set the flag to `true` and re-run the playbook (the role
unmasks because the units are only masked when the flag is false).

## Boot config

`moode_boot_config_lines` goes into a marked block at the end of
`/boot/firmware/config.txt`, opened with `[all]`. A change prints a reboot
warning; Ansible never reboots the host.

moOde edits `config.txt` one line at a time (`sed`, WebUI changes and in-place
updates) and keeps lines it does not know. At boot it replaces the whole file
with its default when line 2 is not its main header, or when `# Device filters`,
`# General settings`, `# Do not alter this section` and `# Audio overlays` do
not each appear exactly once. Therefore:

- never put those headers in the block, even as comments (the role refuses them);
- never add settings the WebUI writes: the DAC overlay (`dtoverlay=i-sabre-q2m`)
  is written under `# Audio overlays` when the device is selected in Audio Config.

### Front panel (mozart)

The DAC's USB-C input feeds the Pi through the header (never power the Pi's own
input at the same time).

| Function | Wiring | `config.txt` |
| --- | --- | --- |
| Shutdown | button between GPIO17 (pin 11) and GND (pin 9) | `dtoverlay=gpio-shutdown,gpio_pin=17` |
| Wake from halt | Schottky diode, anode on GPIO3 (pin 5), cathode on the GPIO17 side of the button | none: a halted Pi 3 boots when GPIO3 goes low |
| Power LED | LED (resistor unless built in) between TXD/GPIO14 (pin 8) and GND (pin 14) | `enable_uart=1` |
| Amplifier | see [marantz_rc5](../marantz_rc5/README.md) | `dtoverlay=gpio-ir-tx,gpio_pin=22` |

- GPIO3 is the DAC's I²C clock. The diode keeps I²C clock pulses off GPIO17; a
  press while running holds SCL low until release, harmless since the host is
  shutting down.
- TXD idles high while the OS runs and drops when the Pi halts (the pins reset
  to inputs): LED off means safe to cut power. On a 3B+, `enable_uart=1` fixes
  the core clock at 250 MHz, and moOde's `console=serial0,115200` puts a serial
  console on GPIO14/15, so the LED flickers with boot messages.

## I-Sabre Q2M input

The I-Sabre Q2M HAT has its own microcontroller between the Pi and the DAC
chip; the `i-sabre-q2m` driver talks to it at I²C 0x48. The driver's register
cache assumes the HAT starts on I2S, so it never sends the input selection,
and the HAT cannot be read back (`Audiophonics Device ID : FF` at boot). A HAT
left on SPDIF plays nothing while moOde and `amixer` report I2S, and its
display does not show the stream's sample rate.

`moode_isabre_i2s_resync` enables `isabre-i2s.service`, which writes SPDIF then
I2S at boot (enabled only, never started by Ansible: that would interrupt
playback). By hand:

```bash
amixer -c DAC sset 'I2S/SPDIF Select' SPDIF && amixer -c DAC sset 'I2S/SPDIF Select' I2S
```

## Update check

moOde has no in-place upgrade across major series, and publish only the current
series' metadata. The role therefore checks two sources weekly:

- `{{ moode_update_url }}/update-moode<series>.txt` — the same file the WebUI's
  *CHECK for software update* reads: `Release:`, `Date:`, `ImageOnly:`.
- `{{ moode_update_releases_feed }}` — newest release name, used to detect a new
  major series (which requires a fresh image).

Installed release comes from `moodeutl --mooderel`; a pending restart from
`cfg_system.inplace_upd_applied`.

Notifications (ntfy) are sent only when the detected state changes, so the weekly
run is silent while nothing moves. **Ansible never applies an update.**

### Runbook: apply an in-series update

```sh
# On the host. Equivalent to System Config > CHECK for software update > INSTALL.
sudo /var/www/util/system-updater.sh moode10    # <series> from moodeutl --mooderel
sudo moodeutl --updlog                         # confirm "Update installed"
sudo reboot

# From the control node: an update can replace files this repo manages.
ansible-playbook playbooks/<host>.yml
```

The notification message contains the same commands with the right series.

### Runbook: new major series (`ImageOnly: Yes`, or a newer major in the feed)

1. Back up the card (this host's image normally lives under
   `/var/backups/<host>/` on andromeda).
2. Flash the new image with Raspberry Pi Imager — it must be configured with a
   login user, password **and** SSH enabled, or moOde will not start correctly.
3. Restore the moOde configuration (`moodeutl -e` before, `-i` after, or the
   WebUI backup).
4. Re-run the playbook for the host.

## Metrics

Written to node_exporter's textfile collector (`moode_metrics_dir`), exposed by
the `node` Prometheus job:

| Metric | Meaning |
| --- | --- |
| `moode_release_info{release,series,date}` | installed release (value `1`) |
| `moode_update_available` | newer in-series release published |
| `moode_update_image_only` | the published update needs a fresh image |
| `moode_major_update_available` | a newer major series exists (reflash) |
| `moode_reboot_pending` | an in-place update waits for a restart |
| `moode_update_check_success` / `_timestamp_seconds` | last check result/time |
| `moode_throttled_flags` | raw `vcgencmd get_throttled` bitmask |
| `moode_throttled_undervoltage_now` / `_occurred` | under-voltage, now / since boot |
| `moode_throttled_freq_capped_now` / `_occurred` | ARM frequency capped |
| `moode_throttled_now` / `_occurred` | throttling active / occurred |
| `moode_throttled_soft_temp_limit_now` / `_occurred` | soft temperature limit |
| `moode_soc_temperature_celsius` | SoC temperature |
| `moode_health_timestamp_seconds` | last scrape |

Grafana alerts (`roles/grafana/files/alerting-rules.yaml`) fire on
`moode_update_available`, `moode_major_update_available` and
`moode_throttled_undervoltage_now`.

## Operations

```bash
systemctl list-timers 'moode-*'
systemctl status moode-update.service
journalctl -u moode-update.service -n 20
cat /var/lib/node_exporter/textfile_collector/moode_update.prom
sudo /usr/local/bin/moode-update-check.sh   # manual run
```

## Auto power-off when idle

`moode_auto_poweroff_enabled` powers the host off after
`moode_auto_poweroff_idle_minutes` (default 60) without playback. The timer runs
every `moode_auto_poweroff_check_interval` (default 5 min), so the effective
delay is 60-65 min.

Playback is detected from two sources, because renderers bypass MPD:

| Source | Detection |
| --- | --- |
| MPD (library, radio, playlists) | `mpc status` reports `[playing]` |
| Spotify Connect (librespot), AirPlay (shairport-sync), Bluetooth (bluealsa), HDMI | any `/proc/asound/card*/pcm*p/sub0/status` in `state: RUNNING` |

The idle mark is stored in `moode_auto_poweroff_state_dir` and cleared as soon
as playback resumes. Two guards:

- `moode_auto_poweroff_ignore_sessions` (default `true`) clears the countdown
  while an interactive login exists (`who`), so maintenance sessions are safe.
- `moode_auto_poweroff_dry_run` logs `would power off` instead of shutting down
  — use it for the first deploy or when debugging.

```bash
systemctl list-timers moode-poweroff.timer
journalctl -u moode-poweroff.service -n 20
sudo /usr/local/bin/moode-idle-poweroff.sh   # manual run
sudo rm -f /var/lib/moode-poweroff/idle-since
```

The shutdown goes through `/sbin/shutdown -h -P now`, the same path as the
power button. Nothing cuts power afterwards: the Pi halts (LED off) and the
button boots it again through the GPIO3 wake (see [Front panel](#front-panel-mozart)).

## Requirements

- moOde image (uses `moodeutl` and its `cfg_system` table).
- `roles/node_exporter` for the textfile collector and scraping.
- `curl`, `systemd`, `vcgencmd` (shipped with Raspberry Pi OS).
