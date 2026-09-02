package main

import (
	"log"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	// writeTimeout menjaga agar peer yang lambat tak memblokir relay selamanya.
	writeTimeout = 5 * time.Second
	// pongTimeout adalah batas tak-aktif sebelum koneksi dianggap mati.
	pongTimeout = 90 * time.Second
	pingPeriod  = 30 * time.Second
)

// Client adalah satu koneksi WebSocket dari host atau client app.
type Client struct {
	hub *Hub
	ws  *websocket.Conn

	// role dan verifiedID diisi handler dari header yang ditulis middleware
	// auth (hasil verifikasi query ?id= & ?role=). Pesan `hello` TIDAK bisa
	// menggantinya — lihat router.go untuk penolakan id yang tidak cocok.
	role       Role
	verifiedID string

	id       string
	info     DeviceInfo
	lastPong time.Time

	writeMu sync.Mutex // guard penulisan (gorilla butuh satu penulis)
	log     *log.Logger
}

// NewClient membungkus koneksi mentah. id & info diisi nanti oleh handler
// setelah pesan `hello` diterima.
func NewClient(h *Hub, ws *websocket.Conn, log *log.Logger) *Client {
	return &Client{
		hub:      h,
		ws:       ws,
		lastPong: time.Now(),
		log:      log,
	}
}

// send menyusun + menulis satu pesan JSON. Aman-goroutine.
func (c *Client) send(m Message) { c.sendRaw(mustJSON(m)) }

func (c *Client) sendRaw(b []byte) {
	c.writeMu.Lock()
	defer c.writeMu.Unlock()
	_ = c.ws.SetWriteDeadline(time.Now().Add(writeTimeout))
	if err := c.ws.WriteMessage(websocket.TextMessage, b); err != nil {
		c.log.Printf("[send] %s: %v", c.id, err)
	}
}

// readPump membaca frame masuk dan mengarahkan ke router. Dipanggil sebagai
// goroutine; keluar saat koneksi putus.
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister(c.id, c)
		_ = c.ws.Close()
		c.hub.touch()
	}()

	c.ws.SetReadLimit(1 << 20) // 1 MiB cukup untuk SDP + beberapa ICE
	_ = c.ws.SetReadDeadline(time.Now().Add(pongTimeout))
	c.ws.SetPongHandler(func(string) error {
		c.lastPong = time.Now()
		_ = c.ws.SetReadDeadline(time.Now().Add(pongTimeout))
		return nil
	})

	for {
		var m Message
		if err := c.ws.ReadJSON(&m); err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseNormalClosure, websocket.CloseNoStatusReceived) {
				c.log.Printf("[read] %s: %v", c.id, err)
			}
			return
		}
		m.At = time.Now()
		route(c, m)
	}
}

// writePump mengirim ping berkala (keep-alive) dan menutup saat idle.
func (c *Client) writePump() {
	t := time.NewTicker(pingPeriod)
	defer t.Stop()
	defer c.ws.Close()
	for {
		select {
		case <-t.C:
			c.writeMu.Lock()
			_ = c.ws.SetWriteDeadline(time.Now().Add(writeTimeout))
			if err := c.ws.WriteMessage(websocket.PingMessage, nil); err != nil {
				c.writeMu.Unlock()
				return
			}
			c.writeMu.Unlock()
		}
	}
}
