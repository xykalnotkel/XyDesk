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
		c.hub.relay(c, m.To, m)
	case TMsgOffer, TMsgAnswer, TMsgICE, TMsgBye:
		// Relay murni antar peer; server tak peduli isinya (SDP/ICE adalah
		// urusan ujung-ke-ujung). Ini juga alasan server ringan & privasi aman.
		if m.To == "" {
			c.send(Message{Type: TMsgError, Error: "to wajib", Reason: m.Type})
			return
		}
		c.hub.relay(c, m.To, m)
	case TMsgList:
		c.send(Message{Type: TMsgDevices, Devices: c.hub.snapshot()})
	case TMsgPing:
		c.send(Message{Type: TMsgPong})
	default:
		c.send(Message{Type: TMsgError, Error: "tipe tak dikenal", Reason: m.Type})
	}
}

// handleHello mendaftarkan perangkat. Id bersifat case-sensitive dan harus
// unik; bila duplikat, koneksi baru ditolak agar tak ada pencurian sesi.
func handleHello(c *Client, m Message) {
	if m.To == "" {
		// DeviceId dibawa di kolom `to` pada hello agar protokol tetap satu
		// bentuk pesan; lihat docs/PROTOCOL.md.
		c.send(Message{Type: TMsgError, Error: "hello butuh id perangkat"})
		return
	}
	c.id = m.To
	c.info = DeviceInfo{
		ID:       m.To,
		Name:     firstNonEmpty(m.From, m.To), // name opsional di `from`
		Role:     roleFrom(m),
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
	c.hub.relay(c, m.To, m)
}

func roleFrom(m Message) Role {
	switch m.Reason {
	case "host":
		return RoleHost
	default:
		return RoleClient
	}
}

func firstNonEmpty(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

// compile-time guard: pastikan log diimpor (dipakai helper bila perlu).
var _ = log.Printf
