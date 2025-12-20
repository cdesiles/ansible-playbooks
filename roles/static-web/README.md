# static-web

Deploy static websites from Git repositories with Nginx.

## Features

- Clone static sites from Git repositories
- Automatic Nginx vhost configuration
- HTTPS enabled by default with Let's Encrypt
- Support for build commands (npm, hugo, jekyll, etc.)
- Subdirectory serving (for built assets)
- Static file caching
- Security headers (including HSTS for HTTPS)

## Dependencies

- nginx role (automatically included via meta/main.yml)

## Variables

See [defaults/main.yml](defaults/main.yml)

**Main configuration:**

```yaml
static_web_sites:
  "portfolio.example.fr":
    git_repo: "https://github.com/example/portfolio.git"
    git_branch: "main"  # Optional, defaults to main
    git_depth: 1  # Optional, shallow clone
    build_command: "npm install && npm run build"  # Optional
    root_dir: "dist"  # Optional, serve subdirectory
    ssl_enabled: true  # Optional, defaults to true (HTTPS)

  "blog.example.com":
    git_repo: "https://github.com/example/blog.git"
    # ssl_enabled defaults to true, set to false for HTTP only
```

## Usage

**Inventory (host_vars or group_vars):**

```yaml
static_web_sites:
  "portfolio.example.fr":
    git_repo: "https://github.com/username/portfolio.git"
  
  "docs.example.com":
    git_repo: "https://github.com/company/documentation.git"
    git_branch: "gh-pages"
    root_dir: "_site"
```

**Playbook:**

```yaml
- hosts: webservers
  roles:
    - static-web
```

## File Structure

Sites are deployed to `/var/www/static/<hostname>/`

Example:
```
/var/www/static/
├── portfolio.example.fr/
│   └── index.html
└── blog.example.com/
    ├── _site/          # Built assets (if root_dir specified)
    └── ...
```

## Advanced Examples

**Hugo site:**
```yaml
static_web_sites:
  "blog.example.com":
    git_repo: "https://github.com/example/hugo-blog.git"
    build_command: "hugo --minify"
    root_dir: "public"
```

**React app:**
```yaml
static_web_sites:
  "app.example.com":
    git_repo: "https://github.com/example/react-app.git"
    build_command: "npm ci && npm run build"
    root_dir: "build"
```

## Updating Sites

Re-run the playbook to pull latest changes:

```bash
ansible-playbook -i inventory playbook.yml --tags static-web
```

## Notes

- Nginx configuration is deployed to `{{ nginx_conf_dir }}/<hostname>.conf`
- Sites are owned by nginx user (www-data on Debian, http on Arch)
- Git clones use shallow clone (depth=1) by default for efficiency
- Build commands run as nginx user
