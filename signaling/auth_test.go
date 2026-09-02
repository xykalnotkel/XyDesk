package main

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"net/http/httptest"
	"strconv"
	"testing"
	"time"
)

func newTestAuth() *Auth { return NewAuth("rahasia-uji-xydesk") }

// craftToken membuat token dengan timestamp tertentu (untuk uji kedaluwarsa).
func craftToken(t *testing.T, a *Auth, purpose, role string, ts int64) string {
	t.Helper()
	mac := hmac.New(sha256.New, a.secret)
	mac.Write([]byte(purpose))
	mac.Write([]byte{0})
	mac.Write([]byte(role))
	mac.Write([]byte{0})
	mac.Write([]byte(strconv.FormatInt(ts, 10)))
	sig := hex.EncodeToString(mac.Sum(nil))
	return strconv.FormatInt(ts, 10) + "." + purpose + "." + sig
}

func TestIssueVerifyRoleBinding(t *testing.T) {
	a := newTestAuth()
	// Token host TIDAK boleh dipakai sebagai client, dan sebaliknya.
	host := a.Issue("123456789", RoleHost.String())
	client := a.Issue("client", RoleClient.String())

	cases := []struct {
		name    string
		token   string
		purpose string
		role    string
		want    bool
	}{
		{"host token, role host", host, "123456789", "host", true},
		{"host token dipakai sebagai client — HARUS ditolak", host, "123456789", "client", false},
		{"client token, role client", client, "client", "client", true},
		{"client token dipakai sebagai host — HARUS ditolak", client, "123456789", "host", false},
		{"purpose tidak cocok", host, "987654321", "host", false},
		{"role di luar kontrak", host, "123456789", "admin", false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := a.Verify(tc.token, tc.purpose, tc.role); got != tc.want {
				t.Fatalf("Verify(%q, %q, %q) = %v, want %v", tc.token, tc.purpose, tc.role, got, tc.want)
			}
		})
	}
}

func TestVerifyExpiredAndSkew(t *testing.T) {
	a := newTestAuth()
	now := time.Now().Unix()

	if got := a.Verify(craftToken(t, a, "123456789", "host", now-301), "123456789", "host"); got {
		t.Fatal("token 301 detik lalu harusnya kedaluwarsa")
	}
	if got := a.Verify(craftToken(t, a, "123456789", "host", now-200), "123456789", "host"); !got {
		t.Fatal("token 200 detik lalu masih dalam jendela (CF: ±300 s)")
	}
	// Jendela ke depan juga ±300 detik (jam server mundur tidak memutus semua).
	if got := a.Verify(craftToken(t, a, "123456789", "host", now+200), "123456789", "host"); !got {
		t.Fatal("token 200 detik ke depan masih dalam jendela (CF: ±300 s)")
	}
	if got := a.Verify(craftToken(t, a, "123456789", "host", now+301), "123456789", "host"); got {
		t.Fatal("token 301 detik ke depan harusnya ditolak")
	}
}

func TestVerifyMalformed(t *testing.T) {
	a := newTestAuth()
	bad := []string{"", "satu", "dua.tiga", "x.y.z", "123.ab.cd", "123456789.123456789."}
	for _, tok := range bad {
		if a.Verify(tok, "123456789", "host") {
			t.Fatalf("token rusak %q seharusnya ditolak", tok)
		}
	}
}

// Middleware harus menolak role yang tidak cocok dengan token, dan menulis
// identitas terverifikasi ke header untuk handler WebSocket.
func TestMiddlewareRoleEnforced(t *testing.T) {
	a := newTestAuth()
	hostToken := a.Issue("123456789", RoleHost.String())

	build := func(query, authHeader string) *http.Request {
		r := httptest.NewRequest("GET", "/ws"+query, nil)
		if authHeader != "" {
			r.Header.Set("Authorization", authHeader)
		}
		return r
	}
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-XyDesk-Id", r.Header.Get("X-XyDesk-Id"))
		w.Header().Set("X-XyDesk-Role", r.Header.Get("X-XyDesk-Role"))
		w.WriteHeader(200)
	})

	t.Run("host token + role=host diterima", func(t *testing.T) {
		rec := httptest.NewRecorder()
		a.middleware(next).ServeHTTP(rec, build("?id=123456789&role=host", "Bearer "+hostToken))
		if rec.Code != 200 {
			t.Fatalf("kode %d, mau 200: %s", rec.Code, rec.Body.String())
		}
		if rec.Header().Get("X-XyDesk-Id") != "123456789" || rec.Header().Get("X-XyDesk-Role") != "host" {
			t.Fatalf("header identitas tidak terisi: %v", rec.Header())
		}
	})

	t.Run("host token + role=client ditolak (penyamar)", func(t *testing.T) {
		rec := httptest.NewRecorder()
		a.middleware(next).ServeHTTP(rec, build("?id=123456789&role=client", "Bearer "+hostToken))
		if rec.Code != 401 {
			t.Fatalf("kode %d, mau 401 — role tidak boleh dipalsukan", rec.Code)
		}
	})

	t.Run("tanpa token ditolak", func(t *testing.T) {
		rec := httptest.NewRecorder()
		a.middleware(next).ServeHTTP(rec, build("?id=123456789&role=host", ""))
		if rec.Code != 401 {
			t.Fatalf("kode %d, mau 401", rec.Code)
		}
	})

	t.Run("token di query juga diterima (klien Flutter)", func(t *testing.T) {
		rec := httptest.NewRecorder()
		r := httptest.NewRequest("GET", "/ws?id=123456789&role=host&token="+hostToken, nil)
		a.middleware(next).ServeHTTP(rec, r)
		if rec.Code != 200 {
			t.Fatalf("kode %d, mau 200", rec.Code)
		}
	})

	t.Run("id default 'client' saat query kosong", func(t *testing.T) {
		ct := a.Issue("client", RoleClient.String())
		rec := httptest.NewRecorder()
		a.middleware(next).ServeHTTP(rec, build("/ws", "Bearer "+ct))
		if rec.Code != 200 || rec.Header().Get("X-XyDesk-Id") != "client" {
			t.Fatalf("id client default tidak bekerja: %d %v", rec.Code, rec.Header())
		}
	})

	t.Run("token tidak terformat dengan benar ditolak", func(t *testing.T) {
		rec := httptest.NewRecorder()
		a.middleware(next).ServeHTTP(rec, build("?id=123456789&role=host", "Bearer bukan.token.sig"))
		if rec.Code != 401 {
			t.Fatalf("kode %d, mau 401", rec.Code)
		}
	})
}
