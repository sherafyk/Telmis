# AGENTS.md — Build the Repo “Docker Package” (End-to-End Spec)

You are the coding agent working inside this GitHub repo. Your job is to **implement a complete, production-usable Docker Compose package** for a low-end home media server that:

- **Reuses existing media files** on an external drive without re-downloading (Emby should index them immediately once the drive is mounted).
- Continues automated downloads via Sonarr/Radarr → qBittorrent.
- **Scopes VPN to torrents only** (no system-wide VPN routing).
- Uses **Emby** (keep it), plus **Sonarr + Radarr**, and replaces Jackett with **Prowlarr** (preferred).
- Targets **local-only** usage on home Wi-Fi (no remote access components).
- Is optimized for a **low-end mini-PC** (assume weak CPU, 4GB RAM, no GPU).
- Minimizes ongoing manual work and avoids duplicate file copies (best-practice import paths + single data root).

This document is the single source of truth for what must be built in the repo.

---

## 0) Scope and Non-Scope

### IN SCOPE (what you must implement in this repo)
- `compose.yaml` for the full stack
- `.env.example` (template) + `.gitignore`
- placeholder config directory structure tracked by git
- minimal scripts for validation + ergonomics
- optional `Makefile` targets
- README updates (repo usage + app-level configuration notes; no OS steps)
- optional CI workflow for lint/validation (no secrets, no external dependencies required)

### OUT OF SCOPE (do NOT write these instructions into this repo)
- Windows backup procedures
- Ubuntu installation instructions
- drive formatting/mounting/fstab/systemd units
- router configuration, reverse proxy, TLS, remote access
- “how to torrent” guidance or indexer sourcing
The user will handle machine setup separately. This repo is the “package” they deploy.

---

## 1) Architecture Decisions (Locked)

### 1.1 Service set (core)
Must include these containers:
- `emby`
- `sonarr`
- `radarr`
- `prowlarr`
- `gluetun`
- `qbittorrent`

Optional services (must be implemented as **Compose profiles** so they’re off by default):
- `flaresolverr` (profile: `flaresolverr`)
- `jackett` (profile: `jackett`) — legacy only

### 1.2 Networking (critical)
- **Only qBittorrent is behind VPN.**
- Implement VPN scoping via:
  - `qbittorrent.network_mode: "service:gluetun"`
- Expose qBittorrent ports on **gluetun**, not on qbittorrent.
- All other services remain on a normal bridge network (e.g., `media`).

**Connectivity rule for Sonarr/Radarr → qB:**
- Since qbittorrent shares gluetun’s network namespace, other containers should talk to qB via:
  - Host: `gluetun`
  - Port: `${QBITTORRENT_WEBUI_PORT}` (default 8080)
This avoids relying on host IP or special Docker hostname hacks.

### 1.3 Storage and path contract (critical)
User wants “seamless” reuse of existing media (no re-download) and minimal manual work.

This repo must standardize a **single canonical container path**: `/data`.

All data paths inside containers MUST be under `/data`:

**Required canonical layout (Option 2, locked):**
- `/data/media/movies`
- `/data/media/tv`
- `/data/torrents/incomplete`
- `/data/torrents/complete`

**Hard requirement:**
- In `compose.yaml`, mount `${DATA_DIR}:/data` into Sonarr, Radarr, and qBittorrent.
  - This ensures all apps see consistent paths and allows best-practice moves within a single filesystem.

**Existing library compatibility:**
- Emby must mount:
  - `${DATA_DIR}/media/movies` and `${DATA_DIR}/media/tv`
- Emby should be mounted **read-only** by default to protect media files.

### 1.4 Filesystem assumption
User chose the “best” route: external drive will be **ext4** (single Linux-native filesystem).  
Do not add formatting instructions; simply design the repo to work optimally given ext4 and consistent mounting.

### 1.5 Keep Emby, LAN-only
- No reverse proxy, no HTTPS automation, no remote features.
- Expose Emby’s HTTP port only by default.

### 1.6 Preserve existing app settings (best effort)
User *prefers* to preserve current Sonarr/Radarr/qB settings, but it’s not strict.  
Repo must:
- Use bind-mounted config directories that make it easy to drop-in existing configs
- Avoid opinionated resets or “fresh init” scripts
- Avoid writing anything into `/config` at build time

---

## 2) Repo Deliverables (Files You Must Create/Update)

### 2.1 Required files
1) `compose.yaml`  
2) `.env.example`  
3) `.gitignore`  
4) `config/.gitkeep`  
5) `README.md` (repo usage + app-level notes; no OS steps)  
6) `scripts/validate.sh`  
7) `scripts/print-urls.sh`

### 2.2 Recommended files
8) `Makefile` (quality-of-life commands)  
9) `.github/workflows/ci.yml` (validate compose + shellcheck scripts)

---

## 3) compose.yaml — Implementation Requirements

### 3.1 Images (use these defaults)
Use widely adopted images:
- Emby: `lscr.io/linuxserver/emby:latest`
- Sonarr: `lscr.io/linuxserver/sonarr:latest`
- Radarr: `lscr.io/linuxserver/radarr:latest`
- Prowlarr: `lscr.io/linuxserver/prowlarr:latest`
- qBittorrent: `lscr.io/linuxserver/qbittorrent:latest`
- Gluetun: `qmcgaw/gluetun:latest`
- Flaresolverr: `ghcr.io/flaresolverr/flaresolverr:latest`
- Jackett: `lscr.io/linuxserver/jackett:latest`

### 3.2 Container names (must match exactly)
- `emby`, `sonarr`, `radarr`, `prowlarr`, `gluetun`, `qbittorrent`
- Optional: `flaresolverr`, `jackett`

### 3.3 Restart policy
All services:
- `restart: unless-stopped`

### 3.4 Environment conventions
LinuxServer containers must include:
- `PUID`, `PGID`, `TZ`, `UMASK` (UMASK optional but recommended)

### 3.5 Volumes (must be bind mounts; consistent and predictable)
- Config volumes must be:
  - `${CONFIG_DIR}/emby:/config`
  - `${CONFIG_DIR}/sonarr:/config`
  - `${CONFIG_DIR}/radarr:/config`
  - `${CONFIG_DIR}/prowlarr:/config`
  - `${CONFIG_DIR}/qbittorrent:/config`
  - `${CONFIG_DIR}/gluetun:/gluetun`
  - optional: `${CONFIG_DIR}/jackett:/config`

- Data volumes:
  - Sonarr: `${DATA_DIR}:/data`
  - Radarr: `${DATA_DIR}:/data`
  - qBittorrent: `${DATA_DIR}:/data`
  - Emby:
    - `${DATA_DIR}/media/movies:/data/movies:ro`
    - `${DATA_DIR}/media/tv:/data/tv:ro`

### 3.6 Ports (defaults configurable via .env)
Publish host ports as:
- Emby: `${EMBY_HTTP_PORT}:8096`
- Sonarr: `${SONARR_PORT}:8989`
- Radarr: `${RADARR_PORT}:7878`
- Prowlarr: `${PROWLARR_PORT}:9696`

qBittorrent ports must be published **on gluetun**:
- `${QBITTORRENT_WEBUI_PORT}:${QBITTORRENT_WEBUI_PORT}`
- `${QBITTORRENT_PORT}:${QBITTORRENT_PORT}/tcp`
- `${QBITTORRENT_PORT}:${QBITTORRENT_PORT}/udp`

Do NOT publish qB ports directly on qbittorrent service.

### 3.7 Gluetun VPN env (NordVPN)
Support BOTH OpenVPN and WireGuard (user can pick later) via `.env`:

In `gluetun.environment` include:
- `VPN_SERVICE_PROVIDER=nordvpn`
- `VPN_TYPE=${VPN_TYPE}` where VPN_TYPE is `openvpn` or `wireguard`

OpenVPN vars:
- `OPENVPN_USER=${NORDVPN_USER}`
- `OPENVPN_PASSWORD=${NORDVPN_PASSWORD}`

WireGuard vars:
- `WIREGUARD_PRIVATE_KEY=${NORDVPN_WIREGUARD_PRIVATE_KEY}`
- `WIREGUARD_ADDRESSES=${NORDVPN_WIREGUARD_ADDRESSES}`

Optional server filters:
- `SERVER_COUNTRIES=${VPN_SERVER_COUNTRIES}` (default “United States”)

Firewall allowlist:
- `FIREWALL_INPUT_PORTS=${QBITTORRENT_WEBUI_PORT},${QBITTORRENT_PORT}`

Do not overcomplicate DNS or outbound subnet rules by default. Leave commented knobs in `.env.example`.

### 3.8 Low-end optimization requirements
Add conservative defaults that help small machines:
- Add log rotation limits for chatty containers (compose `logging` driver options):
  - `max-size: "10m"`, `max-file: "3"` (for all services)
- Avoid “nice to have” services (Portainer, Watchtower, dashboards) — not requested.
- Keep Emby HTTPS port disabled by default (no 8920 mapping unless the user opts in).

### 3.9 Optional profiles
- `flaresolverr` must be behind `profiles: ["flaresolverr"]` and only on internal network.
- `jackett` must be behind `profiles: ["jackett"]`.

---

## 4) .env.example — Implementation Requirements

Must include:
- Identity / perms:
  - `TZ=America/Los_Angeles`
  - `PUID=1000`
  - `PGID=1000`
  - `UMASK=022`

- Host paths (ABSOLUTE recommended):
  - `CONFIG_DIR=/opt/media-server/config`
  - `DATA_DIR=/data`

- Ports:
  - `EMBY_HTTP_PORT=8096`
  - `SONARR_PORT=8989`
  - `RADARR_PORT=7878`
  - `PROWLARR_PORT=9696`
  - `QBITTORRENT_WEBUI_PORT=8080`
  - `QBITTORRENT_PORT=6881`
  - (optional) `JACKETT_PORT=9117`

- Gluetun/Nord:
  - `VPN_TYPE=openvpn` (default)
  - `NORDVPN_USER=`
  - `NORDVPN_PASSWORD=`
  - `NORDVPN_WIREGUARD_PRIVATE_KEY=`
  - `NORDVPN_WIREGUARD_ADDRESSES=`
  - `VPN_SERVER_COUNTRIES=United States`

Include comments clarifying:
- Nord uses “service credentials” (user supplies them)
- WireGuard variables only apply when VPN_TYPE=wireguard
- DATA_DIR must contain the canonical folder structure under `/data`

Do NOT include any real secrets or example credentials.

---

## 5) .gitignore + config placeholder requirements

### 5.1 .gitignore must ignore
- `.env`
- everything under `config/` except `.gitkeep`
- `*.log` and other runtime junk

### 5.2 config directory
- Must include `config/.gitkeep` so the directory exists in git.
- Do not commit real configs.

---

## 6) Scripts (repo ergonomics)

### 6.1 scripts/validate.sh (required)
- Must run `docker compose config -q`
- Must exit non-zero if invalid
- Must be safe to run repeatedly
- Use:
  - `set -euo pipefail`

### 6.2 scripts/print-urls.sh (required)
- Must print the LAN URLs for each UI using the ports from `.env`:
  - Emby, Sonarr, Radarr, Prowlarr, qBittorrent
- Must not assume a hostname; print `<server-ip>` placeholder unless `HOSTNAME_OVERRIDE` is set.

---

## 7) Makefile (recommended)

Implement at least:
- `make up`       → `docker compose up -d`
- `make down`     → `docker compose down`
- `make ps`       → `docker compose ps`
- `make logs`     → `docker compose logs -f --tail=200`
- `make pull`     → `docker compose pull`
- `make restart`  → `docker compose restart`
- `make config`   → `docker compose config`
- `make validate` → `./scripts/validate.sh`

No OS-specific assumptions; do not use GNU-only extensions beyond standard make conventions.

---

## 8) README.md — Must Be Updated (Repo Usage + App-Level Notes Only)

README must include:
1) What the stack is (Emby + Sonarr/Radarr + Prowlarr + qB behind VPN)
2) Storage contract (DATA_DIR must contain):
   - `/data/media/movies`
   - `/data/media/tv`
   - `/data/torrents/incomplete`
   - `/data/torrents/complete`
3) Minimal “repo usage” steps:
   - copy `.env.example` → `.env`
   - edit `.env`
   - `docker compose up -d`
   - `./scripts/print-urls.sh`
4) App-level configuration notes (NOT OS steps):
   - In qBittorrent set:
     - temp/incomplete: `/data/torrents/incomplete`
     - completed: `/data/torrents/complete`
   - In Sonarr/Radarr set root folders:
     - `/data/media/tv`
     - `/data/media/movies`
   - Explain that Sonarr/Radarr should connect to qB using:
     - Host `gluetun`, Port `${QBITTORRENT_WEBUI_PORT}`
   - Mention “existing library import” concept:
     - Emby points at `/data/media/...` and indexes existing content
     - Sonarr/Radarr can import existing content and optionally rename gradually

Must explicitly state:
- Local-only design
- No remote access components included

---

## 9) Optional CI (recommended)

Add `.github/workflows/ci.yml`:
- Trigger on push + PR
- Steps:
  - checkout
  - run `docker compose config -q` using `.env.example` copied to `.env` (with blank secrets allowed)
  - run shellcheck on `scripts/*.sh` if available (or a lightweight bash lint equivalent)
- CI must not require secrets.

Important: Compose validation in CI should not actually start containers; only validate config renders.

---

## 10) Implementation Plan (What You Must Do in Order)

1) Create/update `.gitignore`
2) Create `config/.gitkeep`
3) Create `.env.example` exactly per requirements
4) Create `compose.yaml` meeting the locked architecture + constraints
5) Create scripts:
   - `scripts/validate.sh`
   - `scripts/print-urls.sh`
   Make them executable (`chmod +x`).
6) Create `Makefile` (recommended)
7) Update `README.md` to match this repo design
8) (Optional) Add CI workflow
9) Run local validation:
   - `docker compose config -q`
   - `./scripts/validate.sh`
   - Ensure `docker compose up -d` would work with a real `.env` and mounted data dir (do not require actual VPN secrets at validation stage).

---

## 11) Definition of Done (Acceptance Checklist)

Repo is complete when:
- [ ] All required files exist (compose, env template, scripts, gitignore, config placeholder, README)
- [ ] `docker compose config -q` succeeds with `.env.example` copied to `.env` (secrets blank but present)
- [ ] qBittorrent is definitively VPN-scoped:
  - [ ] qbittorrent has `network_mode: "service:gluetun"`
  - [ ] qB ports published on gluetun only
- [ ] All services bind-mount configs under `${CONFIG_DIR}/...`
- [ ] Sonarr/Radarr/qB mount `${DATA_DIR}:/data` (single data root)
- [ ] Emby mounts media folders read-only
- [ ] Log rotation is configured to avoid disk bloat on a low-end machine
- [ ] Optional services are behind profiles and do not run by default
- [ ] No secrets are committed (`.env` ignored, config ignored)

---

## 12) Exact Content Templates (You may implement directly)

You should implement the compose/env/scripts with the exact structure described above. Keep it clean, minimal, and consistent.

Do not introduce additional complexity unless required by the constraints in this file.
