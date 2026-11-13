// Shared constants. The extension is a browser-only front end for the local
// IceDragon Core: it never talks to Mozilla, it only points the browser at the
// core's local proxy and reads the core's local status API.

export const CORE = {
  host: "127.0.0.1",
  proxyPort: 10810, // SOCKS5 + HTTP
  apiPort: 10820,
  statusUrl: "http://127.0.0.1:10820/api/status",
};

// Hosts that never go through the proxy (the core's own API).
export const ALWAYS_DIRECT_HOSTS = ["127.0.0.1", "localhost"];

export const MODES = { GLOBAL: "global", WHITELIST: "whitelist", BLACKLIST: "blacklist" };

export const DEFAULT_SETTINGS = {
  mode: MODES.GLOBAL,
  whitelist: [],
  blacklist: [],
  lang: "fa",
  webrtcProtect: true,
  autoConnect: false,
};
