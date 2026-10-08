# zsh configuration

## Features

- **Powerlevel10k** theme with instant prompt
- **Syntax highlighting** for commands
- **Autosuggestions** based on history
- **fzf integration** (Ctrl+R history, Ctrl+T files, Alt+C directories)
- **fzf-tab** for completion menus
- **Smart aliases** (docker → podman, ls → eza)
- **Persistent history** across sessions

## Configuration

### Users

Configure users in inventory:

```yaml
zsh_users:
  - jsmith
  - root
```

### macOS

Homebrew is initialised from `.zshenv` (the role overwrites `~/.zprofile`,
which is where the installer normally puts `brew shellenv`). Override the
prefix on Intel Macs:

```yaml
zsh_darwin_brew_prefix: /usr/local
```

### Rust

`.zshenv` prepends `zsh_cargo_bin` (default `~/.cargo/bin`) to `PATH` when it
exists, so rustup shims and `cargo install` binaries are available in every
shell. Override for a custom `CARGO_HOME`:

```yaml
zsh_cargo_bin: /opt/cargo/bin
```

### Node.js

`.zshenv` prepends `./node_modules/.bin` to `PATH`, so binaries from locally
installed dependencies (eslint, tsc, vite, …) can be run directly inside a
project without `npx`. The entry is relative and therefore resolved against the
current working directory each time a command is looked up.

## Keybindings

- `↑/↓` - History search with substring matching
- `Ctrl+R` - Fuzzy history search
- `Ctrl+T` - Fuzzy file search
- `Alt+C` - Fuzzy directory change
- `Tab` - fzf completion menu
