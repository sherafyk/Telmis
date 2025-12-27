# 📺 Telmis Media Server — Quick Cheat Sheet

**Server IP (example):** `192.168.254.47`
**Data mount:** `/data`
**Compose directory:** `~/media-server`

---

## 🔗 Web Interfaces

* **Emby:** `http://<server-ip>:8096`
* **Sonarr:** `http://<server-ip>:8989`
* **Radarr:** `http://<server-ip>:7878`
* **Prowlarr:** `http://<server-ip>:9696`
* **qBittorrent:** `http://<server-ip>:8080`

---

## 🐳 Docker Basics (Most Used)

### Start everything

```bash
cd ~/media-server
docker compose up -d
```

### Stop everything

```bash
docker compose down
```

### Restart everything

```bash
docker compose restart
```

### Restart one service

```bash
docker compose restart emby
docker compose restart gluetun
docker compose restart qbittorrent
```

### See running containers

```bash
docker ps
```

---

## 🧪 Logs & Debugging

### View logs (last 200 lines)

```bash
docker logs --tail=200 emby
docker logs --tail=200 sonarr
docker logs --tail=200 radarr
docker logs --tail=200 prowlarr
docker logs --tail=200 qbittorrent
docker logs --tail=200 gluetun
```

### Live logs (Ctrl+C to stop)

```bash
docker logs -f gluetun
```

---

## 🔐 VPN Checks (qBittorrent only)

### Check VPN IP (should NOT be your ISP)

```bash
docker exec -it gluetun wget -qO- https://ipinfo.io/ip ; echo
```

### Restart VPN + qB only

```bash
docker compose up -d --force-recreate gluetun qbittorrent
```

---

## 📁 Disk & Media Checks

### Confirm /data is mounted

```bash
lsblk -f
df -h /data
```

### Check media folders

```bash
ls -la /data/media
ls -la /data/torrents
```

### Fix ownership (safe to re-run)

```bash
sudo chown -R 1000:1000 /data
```

---

## 🔄 Reboot Safety Check

### Reboot server

```bash
sudo reboot
```

### After reboot, confirm:

```bash
docker ps
df -h /data
```

---

## 🧰 qBittorrent Login Recovery

### Username

```
admin
```

### Find temporary password

```bash
docker logs qbittorrent --tail=200 | grep -i password
```

---

## 🛠️ Container File Access (Advanced)

### List files inside a container

```bash
docker exec -it emby ls -la /data
docker exec -it sonarr ls -la /data
```

---

## ⚠️ Emergency Fixes

### Docker permission issue

```bash
sudo usermod -aG docker $USER
sudo reboot
```

### Re-pull images (if updates break something)

```bash
docker compose pull
docker compose up -d
```

---

## 🧠 Golden Rules (Read Once)

* Always operate from: `~/media-server`
* Never store media outside `/data`
* Never let qBittorrent download outside `/data/torrents`
* Sonarr/Radarr **move**, not copy
* Emby only reads `/data/media`
* If something breaks: **check logs first**

---

## ✅ System Health Snapshot (one-liner)

```bash
docker ps && df -h /data
```
