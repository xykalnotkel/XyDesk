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
type Auth struct{ secret []byte }

func NewAuth(secret string) *Auth { return &Auth{secret: []byte(secret)} }

// Issue membuat token `ts.purpose.sig` untuk role tertentu, berlaku 5 menit.
// `purpose` = deviceId (host) atau "client".
func (a *Auth) Issue(purpose string) string {
	ts := time.Now().Unix()
	mac := hmac.New(sha256.New, a.secret)
	mac.Write([]byte(purpose))
	mac.Write([]byte{0})
	mac.Write([]byte(strconv.FormatInt(ts, 10)))
	sig := hex.EncodeToString(mac.Sum(nil))
	return strconv.FormatInt(ts, 10) + "." + purpose + "." + sig
}

// Verify memeriksa token: format benar, belum kedaluwarsa, tanda tangan cocok.
func (a *Auth) Verify(token string, purpose string) bool {
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
	if time.Since(time.Unix(ts, 0)) > 5*time.Minute || time.Until(time.Unix(ts, 0)) > time.Minute {
		return false // kedaluwarsa / jam server mundur
	}
	if parts[1] != purpose {
		return false
	}
	mac := hmac.New(sha256.New, a.secret)
	mac.Write([]byte(purpose))
	mac.Write([]byte{0})
	mac.Write([]byte(parts[0]))
	expect := hex.EncodeToString(mac.Sum(nil))
	return hmac.Equal([]byte(expect), []byte(parts[2]))
}

// middleware memaksa autentikasi: header `Authorization: Bearer <token>`
// ATAU query `?token=<token>`. Query dipakai client Flutter
// (web_socket_channel tak kirim header kustom); header dipakai host Rust.
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
		// purpose dibaca dari query (?id=...) — lihat main.go.
		purpose := r.URL.Query().Get("id")
		if purpose == "" {
			purpose = "client"
		}
		if !a.Verify(token, purpose) {
			http.Error(w, "token invalid/expired", http.StatusUnauthorized)
			return
		}
		next.ServeHTTP(w, r)
	})
}
