# Media Server (Docker Compose)

Local-only home media stack built for low-end hardware. This repo provides Emby plus automation (Sonarr/Radarr), Prowlarr, and qBittorrent routed **only** through VPN via Gluetun.

## What’s included

Core services:
- Emby
- Sonarr
- Radarr
- Prowlarr
- Gluetun (VPN tunnel)
- qBittorrent (VPN-scoped)

Optional services (profiles):
- Flaresolverr (`--profile flaresolverr`)
- Jackett (`--profile jackett`) — legacy only

**Local-only design:** no reverse proxy, TLS automation, or remote access components are included.

## Storage contract (single data root)

Set `DATA_DIR` in `.env` to the root of your media drive. It must contain:

- `/data/media/movies`
- `/data/media/tv`
- `/data/torrents/incomplete`
- `/data/torrents/complete`

All containers reference `/data` internally so that Sonarr/Radarr can move files without duplicate copies.

## Quick start (repo usage)

1) Copy the environment template:

```bash
cp .env.example .env
```

2) Edit `.env` and set your paths, ports, and VPN credentials.

3) Start the stack:

```bash
docker compose up -d
```

4) Print local URLs:

```bash
./scripts/print-urls.sh
```

## App configuration notes

### qBittorrent
Set paths so downloads land in the shared `/data` tree:
- Temporary/incomplete: `/data/torrents/incomplete`
- Completed: `/data/torrents/complete`

### Sonarr + Radarr
Set root folders so they import into the shared media library:
- Sonarr root folder: `/data/media/tv`
- Radarr root folder: `/data/media/movies`

When adding qBittorrent as a download client, use:
- Host: `gluetun`
- Port: `${QBITTORRENT_WEBUI_PORT}`

### Existing library imports
Emby points at `/data/media/...` and will index existing content immediately. Sonarr/Radarr can import existing libraries and optionally rename files over time.
