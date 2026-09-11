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

## Keybindings

- `↑/↓` - History search with substring matching
- `Ctrl+R` - Fuzzy history search
- `Ctrl+T` - Fuzzy file search
- `Alt+C` - Fuzzy directory change
- `Tab` - fzf completion menu
