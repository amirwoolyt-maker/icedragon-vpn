package mobile

import (
	"net"
	"path/filepath"
	"testing"

	"github.com/armanlife/arman-vpn-client/core/internal/config"
)

func TestFreeListenIfBusyReassignsOccupiedDefaultPort(t *testing.T) {
	occupied, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer occupied.Close()

	addr := occupied.Addr().String()
	got, moved := freeListenIfBusy(addr, addr)
	if !moved {
		t.Fatalf("expected busy default port %s to be reassigned", addr)
	}
	if got == addr || got == "" {
		t.Fatalf("expected a different free loopback address, got %q", got)
	}
	probe, err := net.Listen("tcp", got)
	if err != nil {
		t.Fatalf("expected reassigned address %q to be free: %v", got, err)
	}
	_ = probe.Close()

	custom, movedCustom := freeListenIfBusy(addr, "127.0.0.1:10820")
	if movedCustom || custom != addr {
		t.Fatalf("expected non-default address %s to be preserved, got (%q, %v)", addr, custom, movedCustom)
	}
}

func TestEnsureFreeDefaultPortsSavesValidConfig(t *testing.T) {
	path := filepath.Join(t.TempDir(), config.FileName)
	cfg := config.Default()
	if err := config.Save(path, cfg); err != nil {
		t.Fatal(err)
	}
	if err := ensureFreeDefaultPorts(path); err != nil {
		t.Fatal(err)
	}
	loaded, _, err := config.Load(path)
	if err != nil {
		t.Fatal(err)
	}
	if !loaded.Dashboard.Enabled || loaded.Dashboard.Listen == "" {
		t.Fatalf("unexpected dashboard config: %+v", loaded.Dashboard)
	}
}
