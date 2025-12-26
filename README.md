# Media Server (Docker Compose)

This repo is the **source of truth** for a lightweight home media stack designed for:
- **Local-only** access on your home Wi-Fi (no remote access / reverse proxy by default)
- **Seamless reuse of existing media files** on an external drive (no re-download)
- **Stability** by avoiding “VPN routes the whole machine”
- **Low-end hardware** friendly defaults

## What’s in the stack

Core services:
- **Emby** (media server)
- **Sonarr** (TV automation)
- **Radarr** (movie automation)
- **Prowlarr** (indexer manager; syncs indexers to Sonarr/Radarr)
- **Gluetun** (VPN tunnel container)
- **qBittorrent** (torrent client) — runs **behind Gluetun only**

Optional services (profiles):
- **Flaresolverr** (`--profile flaresolverr`) — only if you need it for tough indexers
- **Jackett** (`--profile jackett`) — legacy compatibility (generally not needed if using Prowlarr)

## Networking model (important)

Only **qBittorrent** is VPN-scoped.

In Compose, qBittorrent uses:
- `network_mode: "service:gluetun"`

So all torrent traffic is forced through the VPN tunnel, while Emby/Sonarr/Radarr/Prowlarr stay on normal LAN routing.

## Storage model (simple + “no duplicates” friendly)

This repo assumes your host has a single data root (recommended):
- `DATA_DIR=/data`

Inside it, use this layout:

- `/data/media/movies`
- `/data/media/tv`
- `/data/torrents/incomplete`
- `/data/torrents/complete`

### Why mount everything under `/data`?
Because Sonarr/Radarr can do clean “move” operations within one filesystem and avoid copy+delete behavior. It also keeps paths consistent across containers.

## Ports (defaults)

- Emby: `8096`
- Sonarr: `8989`
- Radarr: `7878`
- Prowlarr: `9696`
- qBittorrent WebUI: `8080`
- qBittorrent incoming: `6881/tcp` + `6881/udp`

You can change these in `.env`.

## Repo layout

