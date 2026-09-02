package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"strconv"
	"strings"
	"time"
)

// Auth menyediakan token HMAC berumur pendek tanpa server auth eksternal —
// nol biaya, nol kartu kredit, nol ketergantungan. Token adalah bukti bahwa
// pemegangnya tahu SHARED_SECRET (ditaruh di env server & dikonfigurasi di
// host + client). Untuk fase PoC ini cukup; kelak bisa ditukar OAuth
// (Firebase Spark / Supabase free) TANPA mengubah protokol signaling, karena
// verifikasi terjadi di sini saja (sebelum upgrade WebSocket).
//
// Format token WAJIB identik dengan Worker Cloudflare (src/worker.js):
//
//	ts.purpose.sig   dengan sig = HMAC-SHA256(secret, purpose \x00 role \x00 ts)
//
// Role ikut ditandatangani: token yang diterbitkan untuk role client TIDAK
// bisa dipakai ulang sebagai host, dan sebaliknya. Sebelum 3 Sep 2026 server
// Go menandatangani tanpa role (HMAC(purpose \x00 ts)) sehingga token yang
// terbit di sini ditolak Worker produksi dan sebaliknya — dua format, satu
// nama. Kini satu format untuk keduanya.
type Auth struct{ secret []byte }

func NewAuth(secret string) *Auth { return &Auth{secret: []byte(secret)} }

// Issue membuat token `ts.purpose.sig` untuk role tertentu, berlaku 5 menit.
// `purpose` = deviceId (host) atau "client".
func (a *Auth) Issue(purpose, role string) string {
	ts := time.Now().Unix()
	mac := hmac.New(sha256.New, a.secret)
	mac.Write([]byte(purpose))
	mac.Write([]byte{0})
	mac.Write([]byte(role))
	mac.Write([]byte{0})
	mac.Write([]byte(strconv.FormatInt(ts, 10)))
	sig := hex.EncodeToString(mac.Sum(nil))
	return strconv.FormatInt(ts, 10) + "." + purpose + "." + sig
}

// Verify memeriksa token: format benar, belum kedaluwarsa, signature cocok,
// dan role yang diminta cocok dengan yang ditandatangani.
//
// Jendela waktu disamakan dengan Worker Cloudflare: |sekarang - ts| <= 300
// detik (bolak-balik, bukan cuma ke belakang). Jam server yang mundur tidak
// membuat semua koneksi putus sekaligus.
func (a *Auth) Verify(token, purpose, role string) bool {
	if role != RoleHost.String() && role != RoleClient.String() {
		return false
	}
	parts := strings.Split(token, ".")
	if len(parts) != 3 {
		return false
	}
	var ts int64
	if v, err := strconv.ParseInt(parts[0], 10, 64); err != nil {
		return false
	} else {
		ts = v
	}
	if skew := time.Since(time.Unix(ts, 0)); skew > 5*time.Minute || skew < -5*time.Minute {
		return false // kedaluwarsa / jam server mundur
	}
	if parts[1] != purpose {
		return false
	}
	mac := hmac.New(sha256.New, a.secret)
	mac.Write([]byte(purpose))
	mac.Write([]byte{0})
	mac.Write([]byte(role))
	mac.Write([]byte{0})
	mac.Write([]byte(parts[0]))
	expect := hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(expect), []byte(parts[2]))
}

// middleware memaksa autentikasi: header `Authorization: Bearer <token>`
// ATAU query `?token=<token>`. Query dipakai client Flutter
// (web_socket_channel tak kirim header kustom); header dipakai host Rust.
//
// ID dan role WAJIB datang dari query (`?id=`, `?role=`) — keduanya
// diverifikasi di sini dan diteruskan ke handler lewat header internal
// X-XyDesk-Id / X-XyDesk-Role. Pesan hello tidak boleh mengganti identitas
// setelah gerbang ini (lihat router.go).
func (a *Auth) middleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token := ""
		if h := r.Header.Get("Authorization"); strings.HasPrefix(h, "Bearer ") {
			token = strings.TrimPrefix(h, "Bearer ")
		} else {
			token = r.URL.Query().Get("token")
		}
		if token == "" {
			http.Error(w, "missing token", http.StatusUnauthorized)
			return
		}
		purpose := r.URL.Query().Get("id")
		if purpose == "" {
			purpose = "client"
		}
		role := RoleClient
		if r.URL.Query().Get("role") == RoleHost.String() {
			role = RoleHost
		}
		if !a.Verify(token, purpose, role.String()) {
			http.Error(w, "token invalid/expired", http.StatusUnauthorized)
			return
		}
		r.Header.Set("X-XyDesk-Id", purpose)
		r.Header.Set("X-XyDesk-Role", role.String())
		next.ServeHTTP(w, r)
	})
}
