package service

import (
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"

	"github.com/amirwoolyt-maker/icedragon-vpn/core/internal/config"
	"github.com/amirwoolyt-maker/icedragon-vpn/core/internal/version"
)

const maxNativeMessageBytes = 4 << 20

type nativeRequest struct {
	ID     any             `json:"id,omitempty"`
	Type   string          `json:"t"`
	Method string          `json:"method,omitempty"`
	Path   string          `json:"path,omitempty"`
	Body   json.RawMessage `json:"body,omitempty"`
}

type nativeResponse struct {
	ID      any             `json:"id,omitempty"`
	Type    string          `json:"t"`
	OK      bool            `json:"ok"`
	Status  int             `json:"status,omitempty"`
	Data    json.RawMessage `json:"data,omitempty"`
	Error   string          `json:"error,omitempty"`
	Version string          `json:"version,omitempty"`
}

type nativeDiscoverPayload struct {
	DaemonRunning   bool   `json:"daemon_running"`
	APIURL          string `json:"api_url,omitempty"`
	ProxyListen     string `json:"proxy_listen,omitempty"`
	ProxyAuth       bool   `json:"proxy_auth"`
	SystemProxyMode string `json:"system_proxy_mode,omitempty"`
	LocalToken      string `json:"local_token,omitempty"`
	DataDir         string `json:"data_dir"`
	CoreVersion     string `json:"core_version"`
}

// RunNativeMessaging serves Chrome/Edge/Firefox Native Messaging requests over
// stdin/stdout using 4-byte little-endian length-prefixed JSON frames.
func RunNativeMessaging(paths DataPaths, in io.Reader, out io.Writer) error {
	for {
		msg, err := readNativeFrame(in)
		if errors.Is(err, io.EOF) {
			return nil
		}
		if err != nil {
			return err
		}
		var req nativeRequest
		if err := json.Unmarshal(msg, &req); err != nil {
			if wErr := writeNativeFrame(out, nativeResponse{
				Type:  "error",
				OK:    false,
				Error: "invalid JSON request: " + err.Error(),
			}); wErr != nil {
				return wErr
			}
			continue
		}
		resp := handleNativeRequest(context.Background(), paths, req)
		if err := writeNativeFrame(out, resp); err != nil {
			return err
		}
	}
}

func readNativeFrame(r io.Reader) ([]byte, error) {
	var lenBuf [4]byte
	if _, err := io.ReadFull(r, lenBuf[:]); err != nil {
		return nil, err
	}
	n := binary.LittleEndian.Uint32(lenBuf[:])
	if n == 0 || n > maxNativeMessageBytes {
		return nil, fmt.Errorf("invalid native message size %d", n)
	}
	payload := make([]byte, n)
	if _, err := io.ReadFull(r, payload); err != nil {
		return nil, err
	}
	return payload, nil
}

func writeNativeFrame(w io.Writer, v any) error {
	payload, err := json.Marshal(v)
	if err != nil {
		return err
	}
	if len(payload) > maxNativeMessageBytes {
		return fmt.Errorf("native response exceeds %d bytes", maxNativeMessageBytes)
	}
	var lenBuf [4]byte
	binary.LittleEndian.PutUint32(lenBuf[:], uint32(len(payload)))
	if _, err := w.Write(lenBuf[:]); err != nil {
		return err
	}
	_, err = w.Write(payload)
	return err
}

func handleNativeRequest(ctx context.Context, paths DataPaths, req nativeRequest) nativeResponse {
	switch req.Type {
	case "ping":
		return nativeResponse{
			ID:      req.ID,
			Type:    "pong",
			OK:      true,
			Version: version.Current,
		}
	case "discover":
		payload := discoverDaemon(ctx, paths)
		raw, _ := json.Marshal(payload)
		return nativeResponse{
			ID:      req.ID,
			Type:    "discover",
			OK:      true,
			Data:    raw,
			Version: version.Current,
		}
	case "start_daemon":
		if err := ensureDaemonRunning(ctx, paths); err != nil {
			return nativeResponse{
				ID:    req.ID,
				Type:  "start_daemon",
				OK:    false,
				Error: err.Error(),
			}
		}
		payload := discoverDaemon(ctx, paths)
		raw, _ := json.Marshal(payload)
		return nativeResponse{
			ID:      req.ID,
			Type:    "start_daemon",
			OK:      payload.DaemonRunning,
			Data:    raw,
			Version: version.Current,
		}
	case "request":
		return proxyNativeAPIRequest(ctx, paths, req)
	default:
		return nativeResponse{
			ID:    req.ID,
			Type:  req.Type,
			OK:    false,
			Error: "unknown command: " + req.Type,
		}
	}
}

func discoverDaemon(ctx context.Context, paths DataPaths) nativeDiscoverPayload {
	cfg, _, _ := config.Load(paths.Config)
	token, _ := readLocalToken(paths.LocalToken)
	client := NewClient(paths)
	apiURL, err := client.DashboardURL()
	if err != nil && cfg.Dashboard.Listen != "" {
		apiURL = "http://" + loopbackAddr(cfg.Dashboard.Listen)
	}
	running := false
	if apiURL != "" {
		probeCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
		defer cancel()
		var status map[string]any
		if client.Do(probeCtx, http.MethodGet, "/api/status", nil, &status) == nil {
			running = true
		}
	}
	return nativeDiscoverPayload{
		DaemonRunning:   running,
		APIURL:          apiURL,
		ProxyListen:     loopbackAddr(cfg.Proxy.Listen),
		ProxyAuth:       cfg.Proxy.Username != "",
		SystemProxyMode: cfg.SystemProxy.Mode,
		LocalToken:      token,
		DataDir:         paths.Dir,
		CoreVersion:     version.Current,
	}
}

func ensureDaemonRunning(ctx context.Context, paths DataPaths) error {
	if discoverDaemon(ctx, paths).DaemonRunning {
		return nil
	}
	exe, err := os.Executable()
	if err != nil {
		return err
	}
	args := []string{"-tray"}
	if paths.Dir != "" {
		args = append(args, "-data-dir", paths.Dir)
	}
	cmd := exec.Command(exe, args...)
	cmd.Stdin = nil
	cmd.Stdout = nil
	cmd.Stderr = nil
	if err := cmd.Start(); err != nil {
		return err
	}
	_ = cmd.Process.Release()

	deadline := time.Now().Add(6 * time.Second)
	for time.Now().Before(deadline) {
		if discoverDaemon(ctx, paths).DaemonRunning {
			return nil
		}
		time.Sleep(250 * time.Millisecond)
	}
	return errors.New("core service started, but local API is not responding yet")
}

func proxyNativeAPIRequest(ctx context.Context, paths DataPaths, req nativeRequest) nativeResponse {
	if !strings.HasPrefix(req.Path, "/api/") {
		return nativeResponse{
			ID:     req.ID,
			Type:   "request",
			OK:     false,
			Status: http.StatusBadRequest,
			Error:  "only /api/* paths are allowed",
		}
	}
	method := strings.ToUpper(strings.TrimSpace(req.Method))
	if method == "" {
		method = http.MethodGet
	}
	switch method {
	case http.MethodGet, http.MethodPost, http.MethodPut, http.MethodDelete:
	default:
		return nativeResponse{
			ID:     req.ID,
			Type:   "request",
			OK:     false,
			Status: http.StatusMethodNotAllowed,
			Error:  "unsupported HTTP method",
		}
	}

	client := NewClient(paths)
	base, err := client.DashboardURL()
	if err != nil {
		return nativeResponse{
			ID:     req.ID,
			Type:   "request",
			OK:     false,
			Status: http.StatusServiceUnavailable,
			Error:  err.Error(),
		}
	}
	var bodyReader io.Reader
	if len(req.Body) > 0 && string(bytes.TrimSpace(req.Body)) != "null" {
		bodyReader = bytes.NewReader(req.Body)
	}
	reqCtx, cancel := context.WithTimeout(ctx, 45*time.Second)
	defer cancel()
	httpReq, err := http.NewRequestWithContext(reqCtx, method, base+req.Path, bodyReader)
	if err != nil {
		return nativeResponse{ID: req.ID, Type: "request", OK: false, Status: http.StatusBadRequest, Error: err.Error()}
	}
	if bodyReader != nil {
		httpReq.Header.Set("Content-Type", "application/json")
	}
	if token, err := readLocalToken(paths.LocalToken); err == nil {
		httpReq.Header.Set(localTokenHeader, token)
	}
	resp, err := client.http.Do(httpReq)
	if err != nil {
		var netErr net.Error
		if errors.As(err, &netErr) {
			return nativeResponse{ID: req.ID, Type: "request", OK: false, Status: http.StatusServiceUnavailable, Error: err.Error()}
		}
		return nativeResponse{ID: req.ID, Type: "request", OK: false, Status: http.StatusBadGateway, Error: err.Error()}
	}
	defer resp.Body.Close()

	rawBody, err := io.ReadAll(io.LimitReader(resp.Body, maxNativeMessageBytes-512))
	if err != nil {
		return nativeResponse{ID: req.ID, Type: "request", OK: false, Status: resp.StatusCode, Error: err.Error()}
	}
	trimmed := bytes.TrimSpace(rawBody)
	ok := resp.StatusCode >= 200 && resp.StatusCode < 300
	var errMsg string
	if !ok {
		var e struct {
			Error string `json:"error"`
		}
		if json.Unmarshal(trimmed, &e) == nil && e.Error != "" {
			errMsg = e.Error
		} else {
			errMsg = http.StatusText(resp.StatusCode)
		}
	}
	var dataJSON json.RawMessage
	if len(trimmed) > 0 && json.Valid(trimmed) {
		dataJSON = trimmed
	} else if len(trimmed) > 0 {
		encoded, _ := json.Marshal(string(trimmed))
		dataJSON = encoded
	}
	return nativeResponse{
		ID:     req.ID,
		Type:   "request",
		OK:     ok,
		Status: resp.StatusCode,
		Data:   dataJSON,
		Error:  errMsg,
	}
}
