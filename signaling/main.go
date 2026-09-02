// XyDesk signaling server — plane kontrol untuk mempertemukan host & client.
//
// Jalankan:
//
//	XYDESK_SECRET=$(openssl rand -hex 32) go run . -addr :8080
//
// Tanpa TLS (untuk LAN/dev), atau letakkan di belakang reverse-proxy (Caddy/
// nginx) yang memasang TLS. WebRTC TIDAK membutuhkan signaling yang aman untuk
// keamanan media (DTLS-SRTP sudah end-to-end), tetapi TLS mencegah penyadapan
// SDP/ICE dan pembajakan pairing.
package main

import (
	"crypto/tls"
	"flag"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/gorilla/websocket"
)

func main() {
	addr := flag.String("addr", ":8080", "alamat bind HTTP(S)")
	cert := flag.String("cert", "", "path sertifikat TLS (opsional)")
	key := flag.String("key", "", "path kunci TLS (opsional)")
	issue := flag.String("issue", "", "terbitkan token untuk <purpose> lalu keluar")
	issueRole := flag.String("issue-role", "client", "role token terbitan (host|client)")
	flag.Parse()

	secret := os.Getenv("XYDESK_SECRET")
	if secret == "" {
		log.Fatal("XYDESK_SECRET wajib di-set (mis. `openssl rand -hex 32`)")
	}

	logger := log.New(os.Stdout, "[xydesk] ", log.LstdFlags)
	hub := NewHub(logger)
	auth := NewAuth(secret)

	if *issue != "" {
		role := RoleClient
		if *issueRole == RoleHost.String() {
			role = RoleHost
		}
		logger.Printf("token (%s, %s): %s", *issue, role, auth.Issue(*issue, role.String()))
		return
	}

	up := websocket.Upgrader{
		// Dev/LAN: izinkan asal mana pun. Untuk produksi publik, batasi
		// CheckOrigin agar hanya domain app yang boleh terhubung.
		CheckOrigin: func(*http.Request) bool { return true },
	}

	mux := http.NewServeMux()

	// Titik-titik HTTP kecil (tanpa WebSocket).
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})

	// WebSocket ber-autentikasi: /ws?id=<deviceId>&role=host|client
	mux.Handle("/ws", auth.middleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := up.Upgrade(w, r, nil)
		if err != nil {
			logger.Printf("[upgrade] %v", err)
			return
		}
		c := NewClient(hub, conn, logger)
		c.role = Role(r.Header.Get("X-XyDesk-Role"))
		c.verifiedID = r.Header.Get("X-XyDesk-Id")
		go c.writePump()
		go c.readPump()
	})))

	srv := &http.Server{
		Addr:              *addr,
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
	}

	// Penggantian sweeper: koneksi yang diam terlalu lama ditutup.
	go sweep(hub, logger)

	if *cert != "" && *key != "" {
		logger.Printf("mendengarkan (TLS) di %s", *addr)
		logger.Fatal(srv.ListenAndServeTLS(*cert, *key))
	} else {
		logger.Printf("mendengarkan (tanpa TLS) di %s", *addr)
		logger.Fatal(srv.ListenAndServe())
	}
}

// sweep menutup peer yang tak merespons ping (lastPong kedaluwarsa).
func sweep(h *Hub, log *log.Logger) {
	for range time.Tick(15 * time.Second) {
		for id, seen := range h.lastSeen() {
			if time.Since(seen) > 90*time.Second {
				if c, ok := h.get(id); ok {
					log.Printf("[sweep] %s idle, menutup", id)
					_ = c.ws.Close()
				}
			}
		}
	}
}

// pastikan tls diimpor bila kelak diaktifkan lewat auto-TLS.
var _ = tls.VersionTLS13
