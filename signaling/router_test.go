package main

import "testing"

// Aturan arah relay harus mencerminkan hub.js Worker Cloudflare. Kalau
// berubah di satu sisi, sisi lain ikut berubah.
func TestRelayAllowed(t *testing.T) {
	cases := []struct {
		name string
		typ  string
		from Role
		to   Role
		want bool
	}{
		{"pair client->host", TMsgPair, RoleClient, RoleHost, true},
		{"pair host->client DITOLAK", TMsgPair, RoleHost, RoleClient, false},
		{"pair sesama client DITOLAK", TMsgPair, RoleClient, RoleClient, false},
		{"offer client->host", TMsgOffer, RoleClient, RoleHost, true},
		{"offer host->client DITOLAK", TMsgOffer, RoleHost, RoleClient, false},
		{"pair-response host->client", TMsgPairResp, RoleHost, RoleClient, true},
		{"pair-response client->host DITOLAK", TMsgPairResp, RoleClient, RoleHost, false},
		{"answer host->client", TMsgAnswer, RoleHost, RoleClient, true},
		{"answer client->host DITOLAK", TMsgAnswer, RoleClient, RoleHost, false},
		{"ice host->client", TMsgICE, RoleHost, RoleClient, true},
		{"ice client->host", TMsgICE, RoleClient, RoleHost, true},
		{"ice sesama host DITOLAK", TMsgICE, RoleHost, RoleHost, false},
		{"bye host->client", TMsgBye, RoleHost, RoleClient, true},
		{"bye sesama client DITOLAK", TMsgBye, RoleClient, RoleClient, false},
		{"tipe tak dikenal DITOLAK", "hack", RoleClient, RoleHost, false},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := relayAllowed(tc.typ, tc.from, tc.to); got != tc.want {
				t.Fatalf("relayAllowed(%q, %s, %s) = %v, mau %v", tc.typ, tc.from, tc.to, got, tc.want)
			}
		})
	}
}

// Id pada hello wajib sama dengan id yang diverifikasi token — pesan klien
// tidak boleh mengganti identitas setelah gerbang auth.
func TestHelloIDOK(t *testing.T) {
	cases := []struct {
		name       string
		verifiedID string
		claimedID  string
		want       bool
	}{
		{"cocok", "123456789", "123456789", true},
		{"berbeda DITOLAK", "123456789", "987654321", false},
		{"claimed kosong DITOLAK", "123456789", "", false},
		{"tanpa verifiedID (jalur lama) tetap mengikat nilai", "", "123456789", true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			if got := helloIDOK(tc.verifiedID, tc.claimedID); got != tc.want {
				t.Fatalf("helloIDOK(%q, %q) = %v, mau %v", tc.verifiedID, tc.claimedID, got, tc.want)
			}
		})
	}
}

// hostList tidak boleh membocorkan id client.
func TestHostListFilter(t *testing.T) {
	hub := NewHub(nil)
	hub.clients["host-1"] = &Client{id: "host-1", info: DeviceInfo{ID: "host-1", Role: RoleHost}}
	hub.clients["client-1"] = &Client{id: "client-1", info: DeviceInfo{ID: "client-1", Role: RoleClient}}

	got := hub.hostList()
	if len(got) != 1 || got[0].ID != "host-1" {
		t.Fatalf("hostList() = %+v, mau hanya host-1", got)
	}
	if all := hub.snapshot(); len(all) != 2 {
		t.Fatalf("snapshot() harus tetap lengkap (dipakai internal): %d", len(all))
	}
}
