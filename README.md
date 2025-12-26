# Media Server (Windows → Ubuntu Server LTS + Docker)  
**Emby + Sonarr + Radarr + Jackett + qBittorrent (VPN-only via Gluetun)**

This repo is the **source of truth** for migrating an existing Windows “home server” mini-PC to a stable **Ubuntu Server LTS + Docker Compose** stack, with one critical design goal:

✅ **Only the downloader (qBittorrent) runs through the VPN** — everything else stays on normal LAN networking.

That eliminates the main instability from the old setup (system-wide NordVPN routing/DNS/firewall/killswitch).

---

## What you get (end state)

- Ubuntu Server LTS (headless) + Docker
- External drive mounted predictably and permanently
- Canonical Linux paths:
  - `/data/downloads`
  - `/data/media/movies`
  - `/data/media/tv`
- Docker services:
  - Emby (LAN)
  - Sonarr (LAN)
  - Radarr (LAN)
  - Jackett (LAN)
  - Gluetun (VPN tunnel)
  - qBittorrent (runs *inside* Gluetun network namespace)
- Update flow:
  - edit on another machine
  - `git push`
  - on the server: `git pull && docker compose up -d`

---

## Repo layout

Typical layout:

```text
media-server/
  AGENTS.md
  README.md
  compose.yaml
  .env.example
  .env                # NOT committed
  config/             # persistent app configs
    emby/
    sonarr/
    radarr/
    jackett/
    qbittorrent/
    gluetun/
  scripts/
    bootstrap-ubuntu.sh
    mount-data.sh
    restore-configs.sh
    verify.sh
    windows-backup.ps1
  systemd/
    media-server.service
