# static-web

Deploy static websites with Nginx, from a Git repository or inline content.

Variables: [defaults/main.yml](defaults/main.yml)

## Notes

- Nginx configuration is deployed to `{{ nginx_conf_dir }}/<hostname>.conf`
- Sites are owned by nginx user (www-data on Debian, http on Arch)
- Git clones use shallow clone (depth=1) by default for efficiency
- Build commands run as nginx user
- `content` (instead of `git_repo`) deploys a single `index.html`, for placeholder pages
