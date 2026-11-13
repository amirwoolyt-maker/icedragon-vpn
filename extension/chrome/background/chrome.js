// Chromium background (MV3 service worker). A PAC script points the browser at
// the local IceDragon Core proxy; no proxy authentication is involved.

import { Engine } from "../shared/engine.js";
import { createMessageHandler } from "../shared/messages.js";
import { generatePac } from "../shared/routing.js";

const api = chrome;

const storage = {
  get: (keys) => api.storage.local.get(keys),
  set: (obj) => api.storage.local.set(obj),
};

const proxy = {
  async enable({ host, port, routeCfg }) {
    const data = generatePac({ host, port }, routeCfg);
    await api.proxy.settings.set({ value: { mode: "pac_script", pacScript: { data, mandatory: true } }, scope: "regular" });
    setIcon(true);
  },
  async disable() {
    await api.proxy.settings.clear({ scope: "regular" });
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
      /* optional */
    }
  },
};

function setIcon(on) {
  const s = on ? "" : "-off";
  api.action.setIcon({ path: { 16: `assets/icons/icon${s}16.png`, 32: `assets/icons/icon${s}32.png`, 48: `assets/icons/icon${s}48.png` } });
}

const engine = new Engine({ storage, proxy, privacy });
const handle = createMessageHandler(engine);

api.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  handle(msg).then(sendResponse);
  return true;
});

api.alarms.create("icedragon-tick", { periodInMinutes: 1 });
api.alarms.onAlarm.addListener((a) => {
  if (a.name === "icedragon-tick") engine.tick();
});
api.runtime.onStartup.addListener(() => engine.maybeAutoConnect());

engine.ready.then(() => setIcon(engine.s.conn.status === "connected"));
