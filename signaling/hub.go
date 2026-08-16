package main

import (
	"log"
	"sync"
	"time"
)

// Hub adalah registri semua perangkat online. Ia memetakan deviceID -> *Client
// dan bertanggung jawab atas relay pesan antar peer serta siaran daftar
// perangkat. Satu proses = satu hub (cukup untuk skala self-host; kalau
// kelak butuh banyak node, ganti map ini dengan pub/sub seperti NATS/Redis —
// protokol tetap sama).
type Hub struct {
	mu      sync.RWMutex
	clients map[string]*Client
	log     *log.Logger
}

func NewHub(log *log.Logger) *Hub {
	return &Hub{clients: make(map[string]*Client), log: log}
}

// register menautkan client ke id-nya. Mengembalikan false bila id sudah
// dipakai (duplikat online) — panggil di luar kunci.
func (h *Hub) register(id string, c *Client) bool {
	h.mu.Lock()
	defer h.mu.Unlock()
	if _, exists := h.clients[id]; exists {
		return false
	}
	h.clients[id] = c
	return true
}

// unregister melepas client bila masih menunjuk ke koneksi yang sama.
func (h *Hub) unregister(id string, c *Client) {
	h.mu.Lock()
	if cur, ok := h.clients[id]; ok && cur == c {
		delete(h.clients, id)
	}
	h.mu.Unlock()
}

// get mengambil client berdasarkan id.
func (h *Hub) get(id string) (*Client, bool) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	c, ok := h.clients[id]
	return c, ok
}

// relay meneruskan msg ke tujuan. Jika tujuan offline, kirim error ke
// pengirim. Server selalu menimpa From dengan id pengirim agar peer tidak
// bisa memalsukan identitas.
func (h *Hub) relay(from *Client, toID string, msg Message) {
	to, ok := h.get(toID)
	if !ok {
		from.send(Message{Type: TMsgError, Error: "peer-offline", Reason: toID})
		return
	}
	msg.From = from.id
	to.send(msg)
}

// broadcast mengirim msg ke SEMUA client (dipakai untuk daftar perangkat).
func (h *Hub) broadcast(msg Message) {
	b := mustJSON(msg)
	h.mu.RLock()
	targets := make([]*Client, 0, len(h.clients))
	for _, c := range h.clients {
		targets = append(targets, c)
	}
	h.mu.RUnlock()
	for _, c := range targets {
		c.sendRaw(b)
	}
}

// snapshot mengembalikan daftar perangkat terkini (aman-baca).
func (h *Hub) snapshot() []DeviceInfo {
	h.mu.RLock()
	defer h.mu.RUnlock()
	out := make([]DeviceInfo, 0, len(h.clients))
	for _, c := range h.clients {
		out = append(out, c.info)
	}
	return out
}

// touch mengirim daftar perangkat ke semua client yang menaruh minat
// (semua client role=client menerima siaran daftar host).
func (h *Hub) touch() {
	h.broadcast(Message{Type: TMsgDevices, Devices: h.snapshot()})
}

// lastSeen dipakai untuk deteksi koneksi mati mendadak (lihat main.go).
func (h *Hub) lastSeen() map[string]time.Time {
	h.mu.RLock()
	defer h.mu.RUnlock()
	out := make(map[string]time.Time, len(h.clients))
	for id, c := range h.clients {
		out[id] = c.lastPong
	}
	return out
}
