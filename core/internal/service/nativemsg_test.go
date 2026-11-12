package service

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestDashboardGuardExtensionOriginRequiresLocalToken(t *testing.T) {
	d := newTestDaemon(t)
	h := newDashboardServer(d).handler()

	for _, origin := range []string{"chrome-extension://abcdefghijklmnop", "moz-extension://12345678-1234-1234-1234-1234567890ab"} {
		// Without X-Local-Token, extension origin is still rejected by CSRF check.
		req := httptest.NewRequest(http.MethodPost, "/api/delay", bytes.NewReader([]byte(`{}`)))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Origin", origin)
		rec := httptest.NewRecorder()
		h.ServeHTTP(rec, req)
		if rec.Code != http.StatusForbidden {
			t.Fatalf("POST with %s and no local token = %d, want 403", origin, rec.Code)
		}

		// With valid X-Local-Token, extension origin is permitted.
		reqAuth := httptest.NewRequest(http.MethodPost, "/api/delay", bytes.NewReader([]byte(`{}`)))
		reqAuth.Header.Set("Content-Type", "application/json")
		reqAuth.Header.Set("Origin", origin)
		reqAuth.Header.Set(localTokenHeader, d.localToken)
		recAuth := httptest.NewRecorder()
		h.ServeHTTP(recAuth, reqAuth)
		if recAuth.Code != http.StatusNoContent {
			t.Fatalf("POST with %s and local token = %d (%s), want 204", origin, recAuth.Code, recAuth.Body.String())
		}
	}

	// Regular web origins remain blocked even if a malicious script tried anything.
	reqWeb := httptest.NewRequest(http.MethodPost, "/api/delay", bytes.NewReader([]byte(`{}`)))
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
	var in bytes.Buffer
	if err := writeNativeFrame(&in, nativeRequest{ID: 1, Type: "ping"}); err != nil {
		t.Fatal(err)
	}
	if err := writeNativeFrame(&in, nativeRequest{ID: 2, Type: "discover"}); err != nil {
		t.Fatal(err)
	}
	var out bytes.Buffer
	if err := RunNativeMessaging(d.paths, &in, &out); err != nil {
		t.Fatal(err)
	}
	for _, wantType := range []string{"pong", "discover"} {
		frame, err := readNativeFrame(&out)
		if err != nil {
			t.Fatal(err)
		}
		var resp nativeResponse
		if err := json.Unmarshal(frame, &resp); err != nil {
			t.Fatal(err)
		}
		if !resp.OK || resp.Type != wantType {
			t.Fatalf("native response = %+v, want ok=true type=%s", resp, wantType)
		}
	}
}
