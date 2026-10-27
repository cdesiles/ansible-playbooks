# static-web

Deploy static websites from Git repositories with Nginx.

Variables: [defaults/main.yml](defaults/main.yml)

## Notes

- Nginx configuration is deployed to `{{ nginx_conf_dir }}/<hostname>.conf`
- Sites are owned by nginx user (www-data on Debian, http on Arch)
- Git clones use shallow clone (depth=1) by default for efficiency
- Build commands run as nginx user
