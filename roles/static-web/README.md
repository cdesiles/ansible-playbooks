# static-web

Deploy static websites from Git repositories with Nginx.

## Variables

See [defaults/main.yml](defaults/main.yml)

**Main configuration:**

```yaml
static_web_sites:
    "portfolio.example.fr":
        git_repo: "https://github.com/example/portfolio.git"
        git_branch: "main" # Optional, defaults to main
        git_depth: 1 # Optional, shallow clone
        build_command: "npm install && npm run build" # Optional
        root_dir: "dist" # Optional, serve subdirectory
        ssl_enabled: true # Optional, defaults to true (HTTPS)

    "blog.example.com":
        git_repo: "https://github.com/example/blog.git"
        # ssl_enabled defaults to true, set to false for HTTP only
```

## Notes

- Nginx configuration is deployed to `{{ nginx_conf_dir }}/<hostname>.conf`
- Sites are owned by nginx user (www-data on Debian, http on Arch)
- Git clones use shallow clone (depth=1) by default for efficiency
- Build commands run as nginx user
