#!/usr/bin/env bash
set -euo pipefail

env_file="${ENV_FILE:-.env}"
if [[ ! -f "$env_file" ]]; then
  env_file=".env.example"
fi

read_env() {
  local key="$1"
  if [[ -f "$env_file" ]]; then
    sed -n "s/^${key}=//p" "$env_file" | tail -n 1
  fi
}

host="${HOSTNAME_OVERRIDE:-<server-ip>}"

emby_port="$(read_env EMBY_HTTP_PORT)"
sonarr_port="$(read_env SONARR_PORT)"
radarr_port="$(read_env RADARR_PORT)"
prowlarr_port="$(read_env PROWLARR_PORT)"
qb_port="$(read_env QBITTORRENT_WEBUI_PORT)"

emby_port="${emby_port:-8096}"
sonarr_port="${sonarr_port:-8989}"
radarr_port="${radarr_port:-7878}"
prowlarr_port="${prowlarr_port:-9696}"
qb_port="${qb_port:-8080}"

cat <<URLS
Emby:        http://${host}:${emby_port}
Sonarr:      http://${host}:${sonarr_port}
Radarr:      http://${host}:${radarr_port}
Prowlarr:    http://${host}:${prowlarr_port}
qBittorrent: http://${host}:${qb_port}
URLS
