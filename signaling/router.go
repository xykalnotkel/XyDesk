package main

import "log"

// route mengarahkan satu pesan masuk. Inilah "otak" protokol: semua aturan
// pairing & relay ditegakkan di sini, bukan tersebar.
func route(c *Client, m Message) {
	switch m.Type {
	case TMsgHello:
		handleHello(c, m)
	case TMsgPair:
		handlePair(c, m)
	case TMsgPairResp:
		// Jawaban pairing hanya boleh datang dari host tujuan.
		if m.To == "" {
			c.send(Message{Type: TMsgError, Error: "pair-response butuh to"})
			return
		}
		relayChecked(c, m)
	case TMsgOffer, TMsgAnswer, TMsgICE, TMsgBye:
		// Relay murni antar peer; server tak peduli isinya (SDP/ICE adalah
		// urusan ujung-ke-ujung). Ini juga alasan server ringan & privasi aman.
		if m.To == "" {
			c.send(Message{Type: TMsgError, Error: "to wajib", Reason: m.Type})
			return
		}
		relayChecked(c, m)
	case TMsgList:
		// Hanya host yang dibagikan — ID client tidak disiarkan ke semua.
		// Ini menyamakan perilaku dengan Worker Cloudflare (privasi: daftar
		// global tidak boleh membocorkan semua perangkat ke setiap akun).
		c.send(Message{Type: TMsgDevices, Devices: c.hub.hostList()})
	case TMsgPing:
		c.send(Message{Type: TMsgPong})
	default:
		c.send(Message{Type: TMsgError, Error: "tipe tak dikenal", Reason: m.Type})
	}
}

// relayChecked meneruskan pesan HANYA bila arahnya sah menurut relayAllowed.
// Aturan ini cermin dari hub.js Worker Cloudflare: tanpa dia, client mana pun
// bisa mengirim `offer` langsung ke host id mana pun — atau menjawab `pair`
// yang bukan miliknya — dan server tidak menegakkan apa-apa.
func relayChecked(c *Client, m Message) {
	target, ok := c.hub.get(m.To)
	if !ok {
		c.send(Message{Type: TMsgError, Error: "peer-offline", Reason: m.To})
		return
	}
	if !relayAllowed(m.Type, c.role, target.info.Role) {
		c.send(Message{Type: TMsgError, Error: "arah relay ditolak", Reason: m.Type})
		return
	}
	c.hub.relay(c, m.To, m)
}

// relayAllowed mengunci alur yang sah:
//   - pair / offer      : client -> host
//   - pair-response / answer : host -> client
//   - ice / bye         : boleh dua arah, tetapi tidak pernah sesama role
//
// Ini mencegah host palsu menjawab permintaan pairing, dan mencegah client
// melempar offer ke sesama client.
func relayAllowed(typ string, from, to Role) bool {
	switch typ {
	case TMsgPair, TMsgOffer:
		return from == RoleClient && to == RoleHost
	case TMsgPairResp, TMsgAnswer:
		return from == RoleHost && to == RoleClient
	case TMsgICE, TMsgBye:
		return from != to
	}
	return false
}

// handleHello mendaftarkan perangkat. Id bersifat case-sensitive dan harus
// unik; bila duplikat, koneksi baru ditolak agar tak ada pencurian sesi.
// Identitas TIDAK diambil dari pesan: id diambil dari ?id= yang sudah diveri-
// fikasi middleware, dan role dari ?role= — bukan dari kolom `reason` yang
// bisa dipalsukan. Sejak 3 Sep 2026 pesan hello dengan `to` yang tidak cocok
// dengan token ditolak (ini menutup celah pemalsuan id di sisi self-host).
func handleHello(c *Client, m Message) {
	if m.To == "" {
		// DeviceId dibawa di kolom `to` pada hello agar protokol tetap satu
		// bentuk pesan; lihat docs/PROTOCOL.md.
		c.send(Message{Type: TMsgError, Error: "hello butuh id perangkat"})
		return
	}
	if !helloIDOK(c.verifiedID, m.To) {
		c.send(Message{Type: TMsgError, Error: "id tidak cocok dengan token"})
		return
	}
	c.id = m.To
	// Role TIDAK dibaca dari message — selalu berasal dari token yang
	// diverifikasi middleware (nilai aman bila header tidak terisi: client).
	role := c.role
	if role != RoleHost {
		role = RoleClient
	}
	c.info = DeviceInfo{
		ID:       m.To,
		Name:     firstNonEmpty(m.From, m.To), // name opsional di `from`
		Role:     role,
		Platform: m.Reason, // platform opsional di `reason`
		Online:   true,
		Since:    m.At.Unix(),
	}

	if !c.hub.register(c.id, c) {
		c.send(Message{Type: TMsgError, Error: "id sudah online"})
		return
	}

	c.hub.log.Printf("[join] %s (%s) role=%s", c.id, c.info.Name, c.info.Role)
	c.send(Message{Type: TMsgWelcome, From: c.id})
	c.hub.touch()
}

// handlePair meneruskan permintaan pairing client -> host beserta PIN 6 digit.
// Verifikasi PIN dilakukan di sisi host (lihat host/README.md) — server hanya
// merelay, sehingga PIN tak pernah tersimpan di server.
func handlePair(c *Client, m Message) {
	if m.To == "" {
		c.send(Message{Type: TMsgError, Error: "pair butuh id host"})
		return
	}
	if _, ok := c.hub.get(m.To); !ok {
		c.send(Message{Type: TMsgError, Error: "peer-offline", Reason: m.To})
		return
	}
	relayChecked(c, m)
}

// helloIDOK: id yang diklaim di hello hanya sah bila sama dengan id yang
// diverifikasi token (verifiedID kosong dipakai hanya oleh jalur lama/tanpa
// ikatan, misalnya koneksi sebelum middleware mengisi header).
func helloIDOK(verifiedID, claimedID string) bool {
	return claimedID != "" && (verifiedID == "" || claimedID == verifiedID)
}

func firstNonEmpty(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

// compile-time guard: pastikan log diimpor (dipakai helper bila perlu).
var _ = log.Printf
