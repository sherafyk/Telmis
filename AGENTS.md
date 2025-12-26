# Media Server Migration (Windows → Ubuntu Server + Docker) — Agent Runbook

This repo is the “source of truth” for standing up a stable home media server:

- Ubuntu Server LTS (headless)
- Docker Compose stack:
  - Emby (LAN)
  - Sonarr (LAN)
  - Radarr (LAN)
  - Jackett (LAN)
  - Gluetun (VPN tunnel)
  - qBittorrent (runs *inside* Gluetun network namespace; VPN-only downloads)

## Non-negotiable invariants

### 1) Clean Linux paths regardless of Windows folder names
The *canonical* paths used by containers MUST be:

- `/data/downloads`
- `/data/media/movies`
- `/data/media/tv`

Even if the physical disk still contains:
- `EMBY Media/Movies`
- `EMBY Media/TV Shows`
- `Downloads - qB`

We achieve this using:
- Physical disk mounted by UUID at `/mnt/storage`
- Bind mounts from `/mnt/storage/...` → `/data/...`

### 2) VPN isolation
Only qBittorrent is behind VPN:
- `qbittorrent` uses `network_mode: "service:gluetun"`
- qBittorrent ports are exposed on `gluetun` (not on qbittorrent)

### 3) “No /data mount = no start”
On boot, the stack MUST NOT start unless `/data` is mounted.

---

# Phase A — Windows “source” backup (do this BEFORE wiping)

1) Stop these apps/services:
- Emby Server
- Sonarr
- Radarr
- Jackett
- qBittorrent

2) Backup the *entire* folders (zip whole folders, no cherry-picking):

- `C:\ProgramData\Radarr\`
- `C:\ProgramData\Sonarr\`
- `C:\ProgramData\Jackett\`
- `C:\Users\TELMIS\AppData\Roaming\qBittorrent\`
- `C:\Users\TELMIS\AppData\Roaming\Emby-Server\`

3) Put the backup zips somewhere safe (USB stick or another machine).

Optional extra: Download in-app backups
- Sonarr → System → Backup
- Radarr → System → Backup

If you want automation, run: `scripts/windows-backup.ps1` as Admin.

---

# Phase B — Ubuntu install (target)

Install Ubuntu Server LTS.

During install:
- enable OpenSSH server
- set timezone to America/Los_Angeles
- create a normal user (this will usually become UID/GID 1000)

After install:
- `sudo apt update && sudo apt upgrade -y`

---

# Phase C — One-time server bootstrap (Ubuntu)

## C1) Install Docker Engine + Compose plugin
Run:
- `scripts/bootstrap-ubuntu.sh`

It installs:
- docker-ce, docker-ce-cli, containerd.io, docker-buildx-plugin, docker-compose-plugin
- git, curl, ca-certificates

## C2) Mount the external data drive
Run:
- `scripts/mount-data.sh`

This script:
- shows you the disk UUID via `lsblk -f` / `blkid`
- mounts the disk at `/mnt/storage` by UUID (fstab)
- creates bind mounts to produce canonical `/data/...` paths (fstab)
- verifies `/data/downloads` and `/data/media/*` exist and are writable

## C3) Clone and configure repo
Recommended location:
- `/opt/media-server`

Commands:
- `sudo mkdir -p /opt/media-server && sudo chown -R $USER:$USER /opt/media-server`
- `git clone <YOUR_REPO_URL> /opt/media-server`
- `cd /opt/media-server`
- `cp .env.example .env`
- edit `.env` and set the NordVPN/Gluetun variables + LAN subnet

## C4) Restore Windows configs into Docker volume folders
Copy the backed up Windows folders into:

- `/opt/media-server/config/radarr`
- `/opt/media-server/config/sonarr`
- `/opt/media-server/config/jackett`
- `/opt/media-server/config/qbittorrent`
- `/opt/media-server/config/emby`

Use:
- `scripts/restore-configs.sh /path/to/your/windows-backups`

## C5) Install systemd unit to enforce “no /data = no start”
Run:
- `sudo cp systemd/media-server.service /etc/systemd/system/media-server.service`
- `sudo systemctl daemon-reload`
- `sudo systemctl enable --now media-server.service`

---

# Phase D — Bring up stack and verify

Bring up:
- `make up`

Verify:
- `make ps`
- `make logs-gluetun`
- `make logs-qb`

Then run:
- `scripts/verify.sh`

Expected UIs:
- Emby: `http://<server-ip>:8096`
- Sonarr: `http://<server-ip>:8989`
- Radarr: `http://<server-ip>:7878`
- Jackett: `http://<server-ip>:9117`
- qBittorrent (through Gluetun): `http://<server-ip>:8080`

---

# Phase E — Post-restore in-app adjustments (likely required)

## Sonarr / Radarr paths
Update root folders to:
- Movies: `/data/media/movies`
- TV: `/data/media/tv`

Update download path assumptions to:
- `/data/downloads`

## Sonarr/Radarr → qBittorrent connectivity
qBittorrent is behind Gluetun, so other containers should talk to it via the HOST port.
We include `extra_hosts: host.docker.internal:host-gateway` so containers can use:

- Host: `host.docker.internal`
- Port: `${QBIT_WEBUI_PORT}`

---

# File templates the agent must generate

## 1) .env.example
Create `.env.example` with:

- TZ=America/Los_Angeles
- PUID=1000
- PGID=1000
- CONFIG_DIR=/opt/media-server/config
- DATA_DIR=/data
- LAN_SUBNET=192.168.1.0/24

- QBIT_WEBUI_PORT=8080
- QBIT_TORRENT_PORT=6881

### Gluetun / NordVPN (choose ONE protocol)
OpenVPN:
- VPN_SERVICE_PROVIDER=nordvpn
- VPN_TYPE=openvpn
- OPENVPN_USER=...
- OPENVPN_PASSWORD=...

WireGuard:
- VPN_SERVICE_PROVIDER=nordvpn
- VPN_TYPE=wireguard
- WIREGUARD_PRIVATE_KEY=...
- WIREGUARD_ADDRESSES=...

Optional server filters:
- SERVER_COUNTRIES=United States
- SERVER_CITIES=Los Angeles

## 2) compose.yaml
Create `compose.yaml` exactly as below.

## 3) systemd/media-server.service
Create a systemd unit that requires `/data` to be mounted before running compose.

## 4) scripts/*
Generate the scripts below. They must be idempotent (safe to re-run).

---

# compose.yaml

```yaml
services:
  emby:
    image: lscr.io/linuxserver/emby:latest
    container_name: emby
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - ${CONFIG_DIR}/emby:/config
      - ${DATA_DIR}/media/movies:/data/movies
      - ${DATA_DIR}/media/tv:/data/tv
    ports:
      - "8096:8096"
      - "8920:8920"
    restart: unless-stopped

  sonarr:
    image: lscr.io/linuxserver/sonarr:latest
    container_name: sonarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - ${CONFIG_DIR}/sonarr:/config
      - ${DATA_DIR}/media/tv:/tv
      - ${DATA_DIR}/downloads:/downloads
    ports:
      - "8989:8989"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped

  radarr:
    image: lscr.io/linuxserver/radarr:latest
    container_name: radarr
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
    volumes:
      - ${CONFIG_DIR}/radarr:/config
      - ${DATA_DIR}/media/movies:/movies
      - ${DATA_DIR}/downloads:/downloads
    ports:
      - "7878:7878"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: unless-stopped

  jackett:
    image: lscr.io/linuxserver/jackett:latest
    container_name: jackett
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - AUTO_UPDATE=true
    volumes:
      - ${CONFIG_DIR}/jackett:/config
      - ${DATA_DIR}/downloads:/downloads
    ports:
      - "9117:9117"
    restart: unless-stopped

  gluetun:
    image: qmcgaw/gluetun:latest
    container_name: gluetun
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - ${CONFIG_DIR}/gluetun:/gluetun
    ports:
      - "${QBIT_WEBUI_PORT}:${QBIT_WEBUI_PORT}"
      - "${QBIT_TORRENT_PORT}:${QBIT_TORRENT_PORT}"
      - "${QBIT_TORRENT_PORT}:${QBIT_TORRENT_PORT}/udp"
    environment:
      - TZ=${TZ}

      # VPN provider
      - VPN_SERVICE_PROVIDER=${VPN_SERVICE_PROVIDER}
      - VPN_TYPE=${VPN_TYPE}

      # OpenVPN
      - OPENVPN_USER=${OPENVPN_USER}
      - OPENVPN_PASSWORD=${OPENVPN_PASSWORD}

      # WireGuard
      - WIREGUARD_PRIVATE_KEY=${WIREGUARD_PRIVATE_KEY}
      - WIREGUARD_ADDRESSES=${WIREGUARD_ADDRESSES}

      # Optional server filters
      - SERVER_COUNTRIES=${SERVER_COUNTRIES}
      - SERVER_CITIES=${SERVER_CITIES}

      # Allow LAN to reach qB WebUI via gluetun container firewall
      - FIREWALL_INPUT_PORTS=${QBIT_WEBUI_PORT}

      # If your VPN/provider supports incoming port forwarding and you use it:
      - FIREWALL_VPN_INPUT_PORTS=${QBIT_TORRENT_PORT}

      # Allow gluetun namespace containers to access LAN subnet if ever needed
      - FIREWALL_OUTBOUND_SUBNETS=${LAN_SUBNET}

    restart: unless-stopped

  qbittorrent:
    image: lscr.io/linuxserver/qbittorrent:latest
    container_name: qbittorrent
    network_mode: "service:gluetun"
    depends_on:
      - gluetun
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
      - WEBUI_PORT=${QBIT_WEBUI_PORT}
      - TORRENTING_PORT=${QBIT_TORRENT_PORT}
    volumes:
      - ${CONFIG_DIR}/qbittorrent:/config
      - ${DATA_DIR}/downloads:/downloads
    restart: unless-stopped
