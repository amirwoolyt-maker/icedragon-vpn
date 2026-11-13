// Firefox background (MV2, persistent page). proxy.onRequest routes requests to
// the local IceDragon Core proxy (SOCKS5 first, HTTP as failover).

import { Engine } from "../shared/engine.js";
import { createMessageHandler } from "../shared/messages.js";
import { decideRoute, hostOf } from "../shared/routing.js";

const api = browser;
let active = null; // { host, port, routeCfg }

const storage = {
  get: (keys) => api.storage.local.get(keys),
  set: (obj) => api.storage.local.set(obj),
};

const proxy = {
  async enable({ host, port, routeCfg }) {
    active = { host, port, routeCfg };
    setIcon(true);
  },
  async disable() {
    active = null;
    setIcon(false);
  },
};

const privacy = {
  async protect(on) {
    try {
      const p = api.privacy?.network?.webRTCIPHandlingPolicy;
      if (!p) return;
      if (on) await p.set({ value: "disable_non_proxied_udp" });
      else await p.clear({});
    } catch {
      /* optional permission */
    }
  },
};

// Registered synchronously at top level so it is live before any request.
api.proxy.onRequest.addListener(
  (details) => {
    const a = active;
    if (!a) return { type: "direct" };
    if (decideRoute(hostOf(details.url), a.routeCfg) !== "proxy") return { type: "direct" };
    return [
      { type: "socks", host: a.host, port: a.port, proxyDNS: true, failoverTimeout: 5 },
      { type: "http", host: a.host, port: a.port, failoverTimeout: 5 },
    ];
  },
  { urls: ["<all_urls>"] }
);

api.proxy.onError.addListener((e) => console.warn("[IceDragon] proxy error:", e.message));

function setIcon(on) {
  const s = on ? "" : "-off";
  api.browserAction.setIcon({
    path: { 16: `assets/icons/icon${s}16.png`, 32: `assets/icons/icon${s}32.png`, 48: `assets/icons/icon${s}48.png` },
  });
}

const engine = new Engine({ storage, proxy, privacy });
const handle = createMessageHandler(engine);

api.runtime.onMessage.addListener((msg) => handle(msg));

api.alarms.create("icedragon-tick", { periodInMinutes: 1 });
api.alarms.onAlarm.addListener((a) => {
  if (a.name === "icedragon-tick") engine.tick();
});

engine.ready.then(async () => {
  setIcon(engine.s.conn.status === "connected");
  await engine.refreshCore();
  engine.maybeAutoConnect();
});
