# XyDesk Signaling Server (Go)

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
XYDESK_SECRET=... go run . -issue <deviceId>   # host pakai deviceId, client pakai apa pun
```

Token berlaku 5 menit; dibawa sebagai `Authorization: Bearer <token>`.

## Test

```bash
go test ./...    # 7 skenario: auth, hello/list, relay offer, pair, offline, duplikat id
go vet ./...
```

## Deploy gratis

Lihat `../docs/FREE-STACK.md`. Ringkasnya: build ARM64 (`GOOS=linux GOARCH=arm64
go build -o signaling .`), taruh di Oracle Cloud Always Free, TLS via Caddy.

## Protokol

Lihat `../docs/PROTOCOL.md`.
