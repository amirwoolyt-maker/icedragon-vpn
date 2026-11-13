// Browser-agnostic engine: connect/disconnect the browser to the local
// IceDragon Core proxy and manage routing settings. Browser specifics (proxy
// API, storage, privacy) are injected through `adapters`.
//
// adapters = {
//   storage: { get(keys) -> obj, set(obj) },
//   proxy:   { enable({ host, port, routeCfg }), disable() },
//   privacy: { protect(bool) } (optional),
//   fetch:   fetch implementation (optional),
// }

import { ALWAYS_DIRECT_HOSTS, CORE, DEFAULT_SETTINGS, MODES } from "./constants.js";
import { fetchCore } from "./core.js";
import { buildRouteConfig, hostOf, normalizeEntry, normalizeList } from "./routing.js";

const KEYS = ["settings", "conn"];

export class EngineError extends Error {
  constructor(message, code) {
    super(message);
    this.code = code;
  }
}

export class Engine {
  constructor(adapters) {
    this.a = adapters;
    this.fetchImpl = adapters.fetch || globalThis.fetch?.bind(globalThis);
    this.s = {
      settings: { ...DEFAULT_SETTINGS },
      conn: { desired: false, status: "disconnected", since: 0, error: "", errorCode: "" },
    };
    this.core = { kind: "offline" };
    this.ready = this._load();
    this._chain = Promise.resolve();
  }

  async _load() {
    const saved = await this.a.storage.get(KEYS);
    if (saved.settings) this.s.settings = { ...DEFAULT_SETTINGS, ...saved.settings };
    if (saved.conn) this.s.conn = { ...this.s.conn, ...saved.conn };
    if (this.s.conn.desired) {
      // Restore the proxy right after a browser/worker restart.
      this.s.conn.status = "connected";
      await this._applyProxy();
    } else {
      this.s.conn.status = "disconnected";
    }
  }

  async _save(...keys) {
    const obj = {};
    for (const k of keys.length ? keys : KEYS) obj[k] = this.s[k];
    await this.a.storage.set(obj);
  }

  _run(fn) {
    const p = this._chain.then(fn, fn);
    this._chain = p.catch(() => {});
    return p;
  }

  routeConfig() {
    return buildRouteConfig(this.s.settings, [...ALWAYS_DIRECT_HOSTS]);
  }

  async _applyProxy() {
    await this.a.proxy.enable({ host: CORE.host, port: this.core.port || CORE.proxyPort, routeCfg: this.routeConfig() });
    await this.a.privacy?.protect(Boolean(this.s.settings.webrtcProtect));
  }

  async _clearProxy() {
    await this.a.proxy.disable();
    await this.a.privacy?.protect(false);
  }

  /* ----------------------------- core status ----------------------------- */

  async refreshCore() {
    this.core = await fetchCore(this.fetchImpl);
    return this.core;
  }

  refresh() {
    return this._run(async () => {
      await this.refreshCore();
      return this.getState();
    });
  }

  /* ------------------------- connect / disconnect ------------------------- */

  connect() {
    return this._run(async () => {
      const c = this.s.conn;
      Object.assign(c, { desired: true, status: "connecting", error: "", errorCode: "" });
      const core = await this.refreshCore();
      const fail = {
        offline: ["core_offline", "IceDragon core is not running."],
        login: ["core_login", "The core requires a dashboard login; the extension cannot read its status."],
        off: ["core_off", "The core's proxy is switched off. Turn it on in IceDragon."],
        starting: ["core_starting", "The core is still starting. Try again in a moment."],
        error: ["core_error", core.message || "The core reports an error."],
      }[core.kind];
      if (fail) {
        await this._clearProxy().catch(() => {});
        Object.assign(c, { desired: false, status: "error", since: 0, error: fail[1], errorCode: fail[0] });
        await this._save("conn");
        return this.getState();
      }
      await this._applyProxy();
      Object.assign(c, { status: "connected", since: Date.now() });
      await this._save("conn");
      return this.getState();
    });
  }

  disconnect() {
    return this._run(async () => {
      await this._clearProxy().catch(() => {});
      Object.assign(this.s.conn, { desired: false, status: "disconnected", since: 0, error: "", errorCode: "" });
      await this._save("conn");
      return this.getState();
    });
  }

  /** Periodic check (alarm): keeps the core view fresh. */
  tick() {
    return this._run(async () => {
      await this.refreshCore();
    });
  }

  /* ------------------------------ settings ------------------------------ */

  setMode(mode) {
    return this._run(async () => {
      if (!Object.values(MODES).includes(mode)) throw new EngineError("Unknown mode.", "bad_mode");
      this.s.settings.mode = mode;
      await this._save("settings");
      await this._reapply();
      return this.getState();
    });
  }

  setLists({ whitelist, blacklist }) {
    return this._run(async () => {
      const res = {};
      for (const [key, val] of [["whitelist", whitelist], ["blacklist", blacklist]]) {
        if (val === undefined) continue;
        const { list, invalid } = normalizeList(val);
        this.s.settings[key] = list;
        res[key] = invalid;
      }
      await this._save("settings");
      await this._reapply();
      return { state: this.getState(), invalid: res };
    });
  }

  /** Add the active tab's host to the list the current mode uses. */
  addHost(url) {
    return this._run(async () => {
      const host = normalizeEntry(hostOf(url));
      if (!host) throw new EngineError("This page has no domain that can be added.", "bad_host");
      const key = this.s.settings.mode === MODES.BLACKLIST ? "blacklist" : "whitelist";
      const set = new Set(this.s.settings[key]);
      set.add(host);
      this.s.settings[key] = [...set];
      await this._save("settings");
      await this._reapply();
      return { host, list: key, state: this.getState() };
    });
  }

  setSettings(patch) {
    return this._run(async () => {
      for (const k of ["lang", "webrtcProtect", "autoConnect"]) if (k in patch) this.s.settings[k] = patch[k];
      await this._save("settings");
      await this._reapply();
      return this.getState();
    });
  }

  async _reapply() {
    if (this.s.conn.status === "connected") await this._applyProxy();
  }

  /** Auto-connect on browser start when enabled. */
  async maybeAutoConnect() {
    await this.ready;
    if (this.s.settings.autoConnect && !this.s.conn.desired) await this.connect();
  }

  getState() {
    return {
      settings: { ...this.s.settings },
      conn: { ...this.s.conn },
      core: this.core,
    };
  }
}
