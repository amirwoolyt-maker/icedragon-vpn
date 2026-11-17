package proxy

import (
	"net"
	"sync"
	"sync/atomic"
	"time"
)

// Traffic is what the proxy's clients sent and received since the proxy
// started, through Mozilla and directly (routing), and the current speed of
// both together in bytes per second.
type Traffic struct {
	Up         int64 `json:"up"`
	Down       int64 `json:"down"`
	DirectUp   int64 `json:"direct_up"`
	DirectDown int64 `json:"direct_down"`
	UpRate     int64 `json:"up_rate"`
	DownRate   int64 `json:"down_rate"`
}

// rateWindow is how many one-second samples the speed averages.
const rateWindow = 3

// RateLimiter limits bandwidth in bytes per second using a token bucket.
type RateLimiter struct {
	rate      int64
	burst     int64
	mu        sync.Mutex
	tokens    float64
	lastCheck time.Time
}

func NewRateLimiter(bytesPerSec int64) *RateLimiter {
	if bytesPerSec <= 0 {
		return nil
	}
	burst := bytesPerSec / 2
	if burst < 32*1024 {
		burst = 32 * 1024
	}
	return &RateLimiter{
		rate:      bytesPerSec,
		burst:     burst,
		tokens:    float64(burst),
		lastCheck: time.Now(),
	}
}

func (l *RateLimiter) Wait(bytes int) {
	if l == nil || l.rate <= 0 || bytes <= 0 {
		return
	}
	l.mu.Lock()
	defer l.mu.Unlock()

	now := time.Now()
	elapsed := now.Sub(l.lastCheck).Seconds()
	l.lastCheck = now

	l.tokens += elapsed * float64(l.rate)
	if l.tokens > float64(l.burst) {
		l.tokens = float64(l.burst)
	}

	l.tokens -= float64(bytes)
	if l.tokens < 0 {
		debt := -l.tokens
		waitTime := time.Duration((debt / float64(l.rate)) * float64(time.Second))
		if waitTime > 0 {
			if waitTime > 2*time.Second {
				waitTime = 2 * time.Second
			}
			time.Sleep(waitTime)
			l.lastCheck = time.Now()
			l.tokens = 0
		}
	}
}

// trafficMeter counts bytes by route and samples the speed every second.
type trafficMeter struct {
	up, down, directUp, directDown atomic.Int64

	mu      sync.Mutex
	samples [rateWindow + 1][2]int64 // total up, down per second, oldest first
	filled  int
	stop    chan struct{}
	once    sync.Once

	limiter atomic.Pointer[RateLimiter]
}

func (m *trafficMeter) SetSpeedLimit(kbps int) {
	if kbps <= 0 {
		m.limiter.Store(nil)
	} else {
		m.limiter.Store(NewRateLimiter(int64(kbps) * 1024))
	}
}

func (m *trafficMeter) Limiter() *RateLimiter {
	return m.limiter.Load()
}

func newTrafficMeter() *trafficMeter {
	m := &trafficMeter{stop: make(chan struct{})}
	go m.sample()
	return m
}

func (m *trafficMeter) sample() {
	ticker := time.NewTicker(time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-m.stop:
			return
		case <-ticker.C:
			m.tick()
		}
	}
}

// tick records the totals of one second.
func (m *trafficMeter) tick() {
	up := m.up.Load() + m.directUp.Load()
	down := m.down.Load() + m.directDown.Load()
	m.mu.Lock()
	copy(m.samples[:], m.samples[1:])
	m.samples[rateWindow] = [2]int64{up, down}
	if m.filled <= rateWindow {
		m.filled++
	}
	m.mu.Unlock()
}

func (m *trafficMeter) close() { m.once.Do(func() { close(m.stop) }) }

func (m *trafficMeter) traffic() Traffic {
	t := Traffic{Up: m.up.Load(), Down: m.down.Load(), DirectUp: m.directUp.Load(), DirectDown: m.directDown.Load()}
	m.mu.Lock()
	if n := m.filled - 1; n > 0 {
		first, last := m.samples[rateWindow-n], m.samples[rateWindow]
		t.UpRate, t.DownRate = (last[0]-first[0])/int64(n), (last[1]-first[1])/int64(n)
	}
	m.mu.Unlock()
	return t
}

// countingConn counts what a client sends (written to the destination) and
// receives (read from it). route, when set, is the route the tunnel took
// (RoutedOpener), for the list of connections.
type countingConn struct {
	net.Conn
	up, down *atomic.Int64
	route    string
	meter    *trafficMeter
	// onClose, when set, runs once when the connection closes.
	onClose   func()
	closeOnce sync.Once
}

func (c *countingConn) Close() error {
	err := c.Conn.Close()
	if c.onClose != nil {
		c.closeOnce.Do(c.onClose)
	}
	return err
}

// Route is the route the tunnel took, or "".
func (c *countingConn) Route() string { return c.route }

func (c *countingConn) Read(p []byte) (int, error) {
	n, err := c.Conn.Read(p)
	if n > 0 {
		c.down.Add(int64(n))
		if c.meter != nil {
			if l := c.meter.Limiter(); l != nil {
				l.Wait(n)
			}
		}
	}
	return n, err
}

func (c *countingConn) Write(p []byte) (int, error) {
	n, err := c.Conn.Write(p)
	if n > 0 {
		c.up.Add(int64(n))
	}
	return n, err
}

// halfClosingCountingConn keeps half-close for connections that have it.
type halfClosingCountingConn struct{ *countingConn }

func (c halfClosingCountingConn) CloseWrite() error {
	return c.Conn.(interface{ CloseWrite() error }).CloseWrite()
}

func countConn(conn net.Conn, up, down *atomic.Int64) net.Conn {
	return countRouted(conn, up, down, "")
}

// countRouted is countConn for a tunnel that took route.
func countRouted(conn net.Conn, up, down *atomic.Int64, route string) net.Conn {
	return wrapCounting(&countingConn{Conn: conn, up: up, down: down, route: route})
}

// countRoutedWithMeter counts and enforces bandwidth limiting if enabled.
func countRoutedWithMeter(conn net.Conn, up, down *atomic.Int64, route string, meter *trafficMeter) net.Conn {
	return wrapCounting(&countingConn{Conn: conn, up: up, down: down, route: route, meter: meter})
}

func wrapCounting(counted *countingConn) net.Conn {
	conn := counted.Conn
	if _, ok := conn.(interface{ CloseWrite() error }); ok {
		return halfClosingCountingConn{counted}
	}
	return counted
}
