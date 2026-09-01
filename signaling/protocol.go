// Package main — protokol signaling XyDesk.
//
// Server ini HANYA bidang signaling (plane kontrol): ia mempertemukan dua
// peer lalu meneruskan SDP/ICE, tetapi TIDAK PERNAH menyentuh media. Aliran
// video/audio berjalan end-to-end lewat WebRTC (DTLS-SRTP) di antara host dan
// client. Ini menjaga server tetap ringan (muat di VM gratis terkecil) dan
// menjaga privasi (server tak bisa menyadap layar).
package main

import (
	"encoding/json"
	"time"
)

// Role pihak dalam satu sesi. Host = PC yang dikendalikan (menangkap layar).
// Client = perangkat yang mengendalikan (Flutter app).
type Role string

const (
	RoleHost   Role = "host"
	RoleClient Role = "client"
)

// DeviceInfo mendeskripsikan satu perangkat yang terdaftar di hub.
type DeviceInfo struct {
	ID       string   `json:"id"`
	Name     string   `json:"name"`
	Role     Role     `json:"role"`
	Platform string   `json:"platform,omitempty"`
	Cap      []string `json:"cap,omitempty"` // e.g. ["av1","nvfbc","gamepad"]
	Online   bool     `json:"online"`
	Since    int64    `json:"since,omitempty"` // unix detik kapan online
}

// Message adalah satu frame JSON di atas WebSocket.
// Bidang kosong (omitempty) dihilangkan agar log tetap pendek.
type Message struct {
	Type      string          `json:"type"`
	To        string          `json:"to,omitempty"`        // id tujuan relay
	From      string          `json:"from,omitempty"`      // diisi server saat relay
	SDP       json.RawMessage `json:"sdp,omitempty"`       // offer / answer (dict)
	Candidate json.RawMessage `json:"candidate,omitempty"` // ICE candidate (dict)
	Accepted  *bool           `json:"accepted,omitempty"`  // jawaban pair
	PIN       string          `json:"pin,omitempty"`       // PIN 6 digit saat pair
	Devices   []DeviceInfo    `json:"devices,omitempty"`   // hasil list
	Error     string          `json:"error,omitempty"`
	Reason    string          `json:"reason,omitempty"`
	At        time.Time       `json:"-"`
}

// Tipe pesan yang dipahami server.
const (
	TMsgHello    = "hello"         // c->s: daftar perangkat
	TMsgWelcome  = "welcome"       // s->c: ack + info server
	TMsgPair     = "pair"          // c->h: minta pasangan (bawa PIN)
	TMsgPairResp = "pair-response" // h->c: terima/tolak
	TMsgOffer    = "offer"         // relai antar peer
	TMsgAnswer   = "answer"
	TMsgICE      = "ice"
	TMsgBye      = "bye"           // peer: sesi berakhir
	TMsgList     = "list"          // c->s: minta daftar perangkat
	TMsgDevices  = "devices"       // s->c: daftar perangkat
	TMsgDeviceUp = "device-update" // s->c: siaran naik/turun perangkat
	TMsgPing     = "ping"
	TMsgPong     = "pong"
	TMsgError    = "error"
)

// mustJSON menulis pesan ke buffer penulisan hub (tanpa mutex sendiri — mutex
// ada di Client.send).
func mustJSON(m Message) []byte {
	b, err := json.Marshal(m)
	if err != nil {
		// Mustahil untuk tipe ini; kalau terjadi, kembalikan error frame.
		return []byte(`{"type":"error","error":"serialize"}`)
	}
	return b
}
