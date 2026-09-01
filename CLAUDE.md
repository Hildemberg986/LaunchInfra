# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Install

Build the `.deb` package:
```bash
make build
```

Install dependencies:
```bash
make install-deps        # both build and runtime
make install-deps-build  # build tools only
make install-deps-runtime  # nginx, certbot, python3-certbot-nginx only
```

Install locally:
```bash
sudo dpkg -i ../launchinfra_*.deb
```

Clean build artifacts:
```bash
make clean
```

## Architecture

LaunchInfra is a Bash CLI for provisioning Nginx virtual hosts with automatic Let's Encrypt SSL. It operates as a system package installed to `/usr/bin/launchinfra`, with supporting libraries in `/usr/share/launchinfra/lib/`.

### Entry point & module loading

`src/launchinfra.sh` is the bootstrap — it detects whether it's running from `/usr/bin` or `/usr/local/bin` to locate its library directory, then sources all modules and calls `dispatch_cli`.

### Libraries (`src/lib/`)

| Module | Responsibility |
|---|---|
| `cli.sh` | CLI dispatch, argument parsing, help/version output, version detection via `debian/changelog` |
| `config.sh` | User/group detection (handles `sudo`), config file loading (`~/.config/launchinfra/launchinfra.conf` and `/etc/launchinfra/launchinfra.conf`), logging to `/var/log/launchinfra.log`, `run_helper` privilege wrapper |
| `nginx_project.sh` | Project creation (static site or reverse proxy), removal, disable/restore, SSL renewal, nginx config editing, default nginx setup |
| `utils.sh` | Port checking/listing, domain conflict checking, project listing, project info display, SSL expiry checking, backup creation |
| `logging.sh` | Colored log helpers (`log_info`, `log_success`, `log_warning`, `log_error`) |

### Privileged helper

`postinst` installs `/usr/local/bin/launchinfra-helper` — a Bash case-statement wrapper for privileged operations (nginx test/reload, certbot, file ownership/chmod, mkdir, rm, symlink, tee, openssl check, tar backup). Non-root users invoke it via passwordless sudoers entries (`/etc/sudoers.d/launchinfra`).

### Security model

- **Group-based**: users must be in the `launchinfra` group to run the CLI
- **User isolation**: each user manages only their projects (`$NGINX_NAME = "$REAL_USER-$PROJETO"`); root sees everything
- **No direct sudo**: all privileged operations go through the helper, not raw `sudo`

## Development Workflow

### Versioning

Versions are managed in `Makefile` (current: `VERSION = 2.3.13`). The `cli.sh` `show_version()` function hardcodes the visible version and must be updated in sync.

```bash
# Bump version, build, and install
./scripts/bump-version.sh 2.4.0 "New feature description"

# Auto-detect bump level from conventional commits
./scripts/release-auto.sh

# Release with explicit level: major|minor|patch
./scripts/release.sh patch
```

### Linting

ShellCheck is run in CI (`~/.github/workflows/release.yml`). Run before committing:
```bash
shellcheck src/*.sh src/lib/*.sh
```

### Testing

No test suite exists. The project relies on shellcheck for validation and manual testing of CLI commands.

## Key Patterns

- **`run_helper`**: all privileged filesystem/nginx/certbot operations are routed through this wrapper — never call `sudo` directly
- **Version detection (`get_version` in `cli.sh`)**: reads from `debian/changelog` locally, or from the installed Debian changelog file after installation. Falls back to `2.0` if neither is found
- **`--dry-run` parsing**: handled early in `create_project` before any filesystem changes
- **Project name validation**: must match `^[a-zA-Z0-9_-]+$` and cannot contain `..` or `/`
- **`REAL_USER` detection**: uses `id -u` + `$SUDO_USER` — when running via `sudo`, `REAL_USER` is the user who invoked sudo, not root. For root-privileged checks (e.g. `setup-nginx`), use `$(id -u) = 0` directly

## Fixes Applied

### `setup-nginx` rejected when invoked via `sudo` (fixed)

`setup_nginx_default` checked `[ "$REAL_USER" != "root" ]`, which was wrong because `REAL_USER` is set from `$SUDO_USER` when running via `sudo`. The fix uses `[ "$(id -u)" != "0" ]` directly, so `sudo launchinfra setup-nginx` now works correctly.

### SSL certificate now targets the project file, not `default` (fixed)

Both `create_project` and `renew_ssl` now temporarily remove `/etc/nginx/sites-enabled/default` before running `certbot --nginx`, ensuring the SSL directives are written to the project's own Nginx config file, not the global default.

### Port conflict no longer blocks proxy reverso (fixed)

The port-in-use check that previously prompted "Deseja continuar? (s/N)" for reverse proxy projects now issues a warning only — the port being in use is expected behavior for proxy targets.

## Known Issues

### Backend validation before SSL (not fixed)

The `create_project` flow validates backend HTTP before requesting SSL via `curl`, but if the backend returns 502/503 during validation, the SSL creation still proceeds with the same risk of partial failure.
