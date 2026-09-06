# XyDesk Signaling Server (Go)

> STATUS: CADANGAN (self-host LAN). Produksi memakai `cloudflare/`
> (Worker + Durable Object) di `signal.xydesk.my.id`. Protokolnya identik
> (`protocol.go` = kontrak); server ini dipertahankan untuk skenario
> offline/LAN tanpa internet. Jangan mengembangkan fitur baru di sini
> tanpa menyamakan dengan `cloudflare/src/hub.js`.

Plane kontrol WebRTC untuk XyDesk: mempertemukan host & client lalu merelay
SDP/ICE. **Tidak pernah menyentuh media** — video/audio end-to-end lewat WebRTC.

## Jalankan

```bash
export XYDESK_SECRET=$(openssl rand -hex 32)   # wajib, rahasia bersama
go run . -addr :8080
# dengan TLS langsung (opsional):
go run . -addr :8443 -cert cert.pem -key key.pem
```

## Terbitkan token (untuk host & client)

```bash
XYDESK_SECRET=... go run . -issue <deviceId> -role host    # host (deviceId 9 digit)
XYDESK_SECRET=... go run . -issue perangkat-abc -role client
```

Token berlaku 5 menit; dibawa sebagai `Authorization: Bearer <token>`.
**Role ikut ditandatangani** (format identik dengan Worker Cloudflare, lihat
`docs/PROTOCOL.md`): token client tidak bisa dipakai ulang sebagai host, dan
id/role di query wajib cocok dengan token — pesan `hello` tidak bisa
memalsukannya (sejak 3 Sep 2026, disamakan dengan `cloudflare/src/hub.js`).

## Deploy gratis

Lihat `../docs/FREE-STACK.md`. Ringkasnya: build ARM64 (`GOOS=linux GOARCH=arm64
go build -o signaling .`), taruh di Oracle Cloud Always Free, TLS via Caddy.

## Protokol

Lihat `../docs/PROTOCOL.md`.
