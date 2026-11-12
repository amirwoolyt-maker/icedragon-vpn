package service

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/amirwoolyt-maker/icedragon-vpn/core/internal/version"
)

func TestDashboardGuardExtensionOriginRequiresLocalToken(t *testing.T) {
	d := newTestDaemon(t)
	d.localToken = "test-local-token-12345"
	if err := os.WriteFile(d.paths.LocalToken, []byte(d.localToken), 0o600); err != nil {
		t.Fatal(err)
	}
	h := newDashboardServer(d).handler()

	for _, origin := range []string{"chrome-extension://abcdefghijklmnop", "moz-extension://12345678-1234-1234-1234-1234567890ab"} {
		// Without X-Local-Token, extension origin is rejected by CSRF check.
		req := httptest.NewRequest(http.MethodPost, "/api/delay", bytes.NewReader([]byte(`{}`)))
		req.Host = "127.0.0.1:10820"
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Origin", origin)
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		if rec.Code != http.StatusForbidden {
			t.Fatalf("POST with %s and no local token = %d, want 403", origin, rec.Code)
		}

		// With valid X-Local-Token, extension origin is permitted.
		reqAuth := httptest.NewRequest(http.MethodPost, "/api/delay", bytes.NewReader([]byte(`{}`)))
		reqAuth.Host = "127.0.0.1:10820"
		reqAuth.Header.Set("Content-Type", "application/json")
		reqAuth.Header.Set("Origin", origin)
		reqAuth.Header.Set(localTokenHeader, d.localToken)
		recAuth := httptest.NewRecorder()
		h.ServeHTTP(recAuth, reqAuth)
		if recAuth.Code != http.StatusNoContent {
			t.Fatalf("POST with %s and local token = %d (%s), want 204", origin, recAuth.Code, recAuth.Body.String())
		}
	}

	// Regular web origins remain blocked even if a local token is present.
	reqWeb := httptest.NewRequest(http.MethodPost, "/api/delay", bytes.NewReader([]byte(`{}`)))
	reqWeb.Host = "127.0.0.1:10820"
	reqWeb.Header.Set("Content-Type", "application/json")
	reqWeb.Header.Set("Origin", "https://evil.example")
	reqWeb.Header.Set(localTokenHeader, d.localToken)
	recWeb := httptest.NewRecorder()
	h.ServeHTTP(recWeb, reqWeb)
	if recWeb.Code != http.StatusForbidden {
		t.Fatalf("POST with https web origin = %d, want 403", recWeb.Code)
	}
}

func TestNativeMessagingPingAndDiscoverRoundTrip(t *testing.T) {
	d := newTestDaemon(t)
	d.localToken = "test-token-native-msg"
	if err := os.WriteFile(d.paths.LocalToken, []byte(d.localToken), 0o600); err != nil {
		t.Fatal(err)
	}

	host := NewNativeMessagingHost(d.paths)
	probed := false
	host.probeStatus = func(ctx context.Context, apiURL, token string) bool {
		probed = true
		if token != d.localToken {
			t.Errorf("probeStatus token = %q, want %q", token, d.localToken)
		}
		if apiURL == "" {
			t.Errorf("probeStatus apiURL is empty")
		}
		return true
	}

	var in bytes.Buffer
	if err := writeNativeFrame(&in, nativeRequest{ID: 1, Type: "ping"}); err != nil {
		t.Fatal(err)
	}
	if err := writeNativeFrame(&in, nativeRequest{ID: 2, Type: "discover"}); err != nil {
		t.Fatal(err)
	}
	var out bytes.Buffer
	if err := host.Serve(&in, &out); err != nil {
		t.Fatal(err)
	}

	if !probed {
		t.Fatal("expected probeStatus mock to be called during discover")
	}

	// Message 1: pong
	frame1, err := readNativeFrame(&out)
	if err != nil {
		t.Fatal(err)
	}
	var resp1 nativeResponse
	if err := json.Unmarshal(frame1, &resp1); err != nil {
		t.Fatal(err)
	}
	if !resp1.OK || resp1.Type != "pong" || resp1.Version != version.Current {
		t.Fatalf("resp1 = %+v, want pong with version %s", resp1, version.Current)
	}

	// Message 2: discover
	frame2, err := readNativeFrame(&out)
	if err != nil {
		t.Fatal(err)
	}
	var resp2 nativeResponse
	if err := json.Unmarshal(frame2, &resp2); err != nil {
		t.Fatal(err)
	}
	if !resp2.OK || resp2.Type != "discover" || resp2.Version != version.Current {
		t.Fatalf("resp2 = %+v, want discover with version %s", resp2, version.Current)
	}

	var payload nativeDiscoverPayload
	if err := json.Unmarshal(resp2.Data, &payload); err != nil {
		t.Fatalf("unmarshal discover payload: %v", err)
	}
	if !payload.DaemonRunning {
		t.Fatalf("payload.DaemonRunning = false, want true from probeStatus mock")
	}
	if payload.LocalToken != d.localToken {
		t.Fatalf("payload.LocalToken = %q, want %q", payload.LocalToken, d.localToken)
	}
	if payload.CoreVersion != version.Current {
		t.Fatalf("payload.CoreVersion = %q, want %q", payload.CoreVersion, version.Current)
	}

	// Verify discover when daemon probe returns false (not running)
	hostOffline := NewNativeMessagingHost(d.paths)
	hostOffline.probeStatus = func(ctx context.Context, apiURL, token string) bool {
		return false
	}
	var inOffline, outOffline bytes.Buffer
	if err := writeNativeFrame(&inOffline, nativeRequest{ID: 3, Type: "discover"}); err != nil {
		t.Fatal(err)
	}
	if err := hostOffline.Serve(&inOffline, &outOffline); err != nil {
		t.Fatal(err)
	}
	frameOffline, err := readNativeFrame(&outOffline)
	if err != nil {
		t.Fatal(err)
	}
	var respOffline nativeResponse
	if err := json.Unmarshal(frameOffline, &respOffline); err != nil {
		t.Fatal(err)
	}
	var payloadOffline nativeDiscoverPayload
	if err := json.Unmarshal(respOffline.Data, &payloadOffline); err != nil {
		t.Fatalf("unmarshal offline discover payload: %v", err)
	}
	if payloadOffline.DaemonRunning {
		t.Fatalf("payloadOffline.DaemonRunning = true, want false")
	}
}
