# aur_build

Task library for roles that build packages from the AUR. It grants the deploy
user passwordless `sudo pacman` for the duration of one build, then removes it.

Not a playbook role: callers pull it in with `include_role` + `tasks_from`.

| Task file  | Purpose                                                     |
| ---------- | ----------------------------------------------------------- |
| `open.yml` | Creates `{{ aur_build_sudoers_file }}` (0440, `visudo -cf`) |
| `close.yml`| Removes it                                                  |

## Usage

```yaml
- name: Build and install foo
  block:
    - name: Open the AUR build sudo window
      ansible.builtin.include_role:
        name: aur_build
        tasks_from: open

    - name: Build
      become: false                     # makepkg refuses to run as root
      ansible.builtin.command:
        cmd: paru -S --noconfirm foo
      changed_when: true
  always:
    - name: Close the AUR build sudo window
      ansible.builtin.include_role:
        name: aur_build
        tasks_from: close
```

Variables: [defaults/main.yml](defaults/main.yml)

## Why a drop-in and not an /etc/sudoers edit

sudo applies the **last** matching rule (`sudoers(5)`), so a `%wheel ALL=(ALL)
NOPASSWD: ALL` edit is only as safe as its own restore path, and it widens the
window to every wheel member and every command. A drop-in named `zz-*` is
narrower (one user, one command) and removing it restores the previous state
without rewriting `/etc/sudoers`.

Three traps this file exists to encode:

- **Ordering.** The filename must sort after other drop-ins granting the user
  ALL (e.g. `jokester`), else their `ALL` rule wins and the build stops on a
  password prompt.
- **`sudo -v` is not covered.** A command-scoped NOPASSWD rule does not make
  `sudo -v` passwordless. Do not enable yay's `Sudoloop`/`--sudoloop` in an
  unattended build; makepkg and paru do not call it.
- **Interrupted runs.** `always:` does not run on Ctrl-C or a lost connection,
  and callers only open the window while their package is missing, so nothing
  would ever close it. The rule carries `NOTAFTER=` (`aur_build_window_minutes`):
  sudo skips an expired rule and the user's own rule applies again.
