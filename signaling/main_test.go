package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

// setup menjalankan server sungguhan di httptest dan mengembalikan URL ws.
func setup(t *testing.T) (*httptest.Server, *Auth) {
	t.Helper()
	secret := "test-secret-please-ignore"
	auth := NewAuth(secret)
	hub := NewHub(logNoop())

	up := websocket.Upgrader{CheckOrigin: func(*http.Request) bool { return true }}
	mux := http.NewServeMux()
	mux.Handle("/ws", auth.middleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, err := up.Upgrade(w, r, nil)
		if err != nil {
			return
		}
		cl := NewClient(hub, c, logNoop())
		go cl.writePump()
		go cl.readPump()
	})))

	srv := httptest.NewServer(mux)
	t.Cleanup(srv.Close)
	return srv, auth
}

// dial membuka koneksi ber-token untuk perangkat `id` ber-role `role`.
func dial(t *testing.T, url, id, role, token string) *websocket.Conn {
	t.Helper()
	wsURL := "ws" + strings.TrimPrefix(url, "http")
	c, _, err := websocket.DefaultDialer.Dial(
		wsURL+"/ws?id="+id+"&role="+role,
		http.Header{"Authorization": {"Bearer " + token}},
	)
	if err != nil {
		t.Fatalf("dial(%s): %v", id, err)
	}
	t.Cleanup(func() { _ = c.Close() })
	return c
}

func readMsg(t *testing.T, c *websocket.Conn, timeout time.Duration) Message {
	t.Helper()
	_ = c.SetReadDeadline(time.Now().Add(timeout))
	var m Message
	if err := c.ReadJSON(&m); err != nil {
		t.Fatalf("read: %v", err)
	}
	return m
}

// readUntil membaca sampai menemukan tipe yang diinginkan (melewatkan siaran
// device-update / devices yang wajar diterima).
func readUntil(t *testing.T, c *websocket.Conn, want string, timeout time.Duration) Message {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		_ = c.SetReadDeadline(time.Now().Add(timeout))
		var m Message
		if err := c.ReadJSON(&m); err != nil {
			t.Fatalf("read(%s): %v", want, err)
		}
		if m.Type == want {
			return m
		}
	}
	t.Fatalf("tidak menerima %s dalam %s", want, timeout)
	return Message{}
}

func hello(t *testing.T, c *websocket.Conn, id, name, role string) {
	t.Helper()
	_ = c.WriteJSON(Message{Type: TMsgHello, To: id, From: name, Reason: role})
	readUntil(t, c, TMsgWelcome, 2*time.Second)
}

func TestAuthRejectsBadToken(t *testing.T) {
	srv, _ := setup(t)
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http")
	_, resp, err := websocket.DefaultDialer.Dial(wsURL+"/ws?id=dev1", http.Header{
		"Authorization": {"Bearer bogus.token.here"},
	})
	if err == nil {
		t.Fatal("harusnya gagal dengan token salah")
	}
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("status = %d, ingin 401", resp.StatusCode)
	}
}

// TestQueryTokenAuth memastikan jalur autentikasi query (?token=) — dipakai
// client Flutter — juga berfungsi.
func TestQueryTokenAuth(t *testing.T) {
	srv, auth := setup(t)
	wsURL := "ws" + strings.TrimPrefix(srv.URL, "http")
	c, _, err := websocket.DefaultDialer.Dial(
		wsURL+"/ws?id=dev1&role=host&token="+auth.Issue("dev1"), nil,
	)
	if err != nil {
		t.Fatalf("dial via query token: %v", err)
	}
	defer c.Close()
	_ = c.WriteJSON(Message{Type: TMsgHello, To: "dev1", From: "PC", Reason: "host"})
	m := readUntil(t, c, TMsgWelcome, 2*time.Second)
	if m.Type != TMsgWelcome {
		t.Fatalf("ingin welcome, dapat %s", m.Type)
	}
}

func TestHelloWelcomeAndList(t *testing.T) {
	srv, auth := setup(t)
	c := dial(t, srv.URL, "dev1", "host", auth.Issue("dev1"))
	hello(t, c, "dev1", "Gaming PC", "host")

	_ = c.WriteJSON(Message{Type: TMsgList})
	m := readUntil(t, c, TMsgDevices, 2*time.Second)
	if len(m.Devices) != 1 || m.Devices[0].ID != "dev1" {
		t.Fatalf("devices salah: %+v", m)
	}
	if m.Devices[0].Name != "Gaming PC" || m.Devices[0].Role != RoleHost {
		t.Fatalf("info perangkat salah: %+v", m.Devices[0])
	}
}

func TestRelayOfferBetweenPeers(t *testing.T) {
	srv, auth := setup(t)
	host := dial(t, srv.URL, "host-1", "host", auth.Issue("host-1"))
	client := dial(t, srv.URL, "client-1", "client", auth.Issue("client-1"))
	hello(t, host, "host-1", "PC", "host")
	hello(t, client, "client-1", "HP", "client")

	_ = client.WriteJSON(Message{Type: TMsgOffer, To: "host-1", SDP: []byte(`{"type":"offer","sdp":"fake"}`)})
	m := readUntil(t, host, TMsgOffer, 2*time.Second)
	if m.From != "client-1" {
		t.Fatalf("from harus client-1, dapat %s", m.From)
	}
}

func TestPairRelayedToHost(t *testing.T) {
	srv, auth := setup(t)
	host := dial(t, srv.URL, "host-1", "host", auth.Issue("host-1"))
	client := dial(t, srv.URL, "client-1", "client", auth.Issue("client-1"))
	hello(t, host, "host-1", "PC", "host")
	hello(t, client, "client-1", "HP", "client")

	_ = client.WriteJSON(Message{Type: TMsgPair, To: "host-1", PIN: "123456"})
	m := readUntil(t, host, TMsgPair, 2*time.Second)
	if m.PIN != "123456" || m.From != "client-1" {
		t.Fatalf("pair salah: %+v", m)
	}
}

func TestRelayToOfflinePeerErrors(t *testing.T) {
	srv, auth := setup(t)
	c := dial(t, srv.URL, "dev1", "client", auth.Issue("dev1"))
	hello(t, c, "dev1", "HP", "client")

	_ = c.WriteJSON(Message{Type: TMsgOffer, To: "ghost", SDP: []byte(`{}`)})
	m := readUntil(t, c, TMsgError, 2*time.Second)
	if m.Error != "peer-offline" {
		t.Fatalf("ingin error peer-offline, dapat %+v", m)
	}
}

func TestDuplicateIDRejected(t *testing.T) {
	srv, auth := setup(t)
	c1 := dial(t, srv.URL, "dev1", "host", auth.Issue("dev1"))
	c2 := dial(t, srv.URL, "dev1", "host", auth.Issue("dev1"))
	hello(t, c1, "dev1", "PC", "host")

	_ = c2.WriteJSON(Message{Type: TMsgHello, To: "dev1", Reason: "host"})
	m := readUntil(t, c2, TMsgError, 2*time.Second)
	if m.Error != "id sudah online" {
		t.Fatalf("ingin error duplikat, dapat %+v", m)
	}
}
