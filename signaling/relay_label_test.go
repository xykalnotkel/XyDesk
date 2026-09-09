package main

import (
	"encoding/json"
	"testing"
)

// Label perangkat pada `pair` wajib selamat melewati hub. Dulu `Message`
// tidak punya field `name`/`platform`, sehingga `relay` yang men-serialize
// ulang struct bertipe ini MEMBUANG keduanya dalam diam — chip "HP · Android"
// di host tidak pernah tampil saat memakai hub Go (hanya Worker Cloudflare
// yang melewatkan field asing). Regresi: field hilang = test merah.
func TestPairLabelSelamatMelewatiHub(t *testing.T) {
	mentah := []byte(`{"type":"pair","to":"host-1","pin":"123456",` +
		`"name":"Redmi Note 12","platform":"android"}`)

	var masuk Message
	if err := json.Unmarshal(mentah, &masuk); err != nil {
		t.Fatalf("pesan pair tidak bisa di-decode: %v", err)
	}
	if masuk.Name != "Redmi Note 12" || masuk.Platform != "android" {
		t.Fatalf("decode membuang label: name=%q platform=%q", masuk.Name, masuk.Platform)
	}

	// relay() mengirim via mustJSON — inilah titik yang dulu membuang field.
	var ulang Message
	if err := json.Unmarshal(mustJSON(masuk), &ulang); err != nil {
		t.Fatalf("hasil relay tidak bisa di-decode: %v", err)
	}
	if ulang.Name != "Redmi Note 12" {
		t.Fatalf("relay membuang name: dapat %q", ulang.Name)
	}
	if ulang.Platform != "android" {
		t.Fatalf("relay membuang platform: dapat %q", ulang.Platform)
	}
}

// Field label wajib omitempty — pesan non-pair (offer/answer/ice/bye) tidak
// boleh tiba-tiba membawa `name`/`platform` kosong ke peer lama.
func TestLabelOmitemptyDiPesanNonPair(t *testing.T) {
	b := mustJSON(Message{Type: TMsgBye, From: "a"})
	var m map[string]any
	if err := json.Unmarshal(b, &m); err != nil {
		t.Fatalf("decode bye gagal: %v", err)
	}
	if _, ada := m["name"]; ada {
		t.Fatalf("bye membawa name kosong: %s", b)
	}
	if _, ada := m["platform"]; ada {
		t.Fatalf("bye membawa platform kosong: %s", b)
	}
}
