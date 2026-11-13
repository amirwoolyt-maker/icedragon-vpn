// Message router shared by both backgrounds. UI -> background protocol:
//   { t: "<action>", ...payload }  =>  { ok: true, data } | { ok: false, error, code }

export function createMessageHandler(engine) {
  const actions = {
    state: () => engine.getState(),
    refresh: () => engine.refresh(),
    connect: () => engine.connect(),
    disconnect: () => engine.disconnect(),
    setMode: (m) => engine.setMode(m.mode),
    setLists: (m) => engine.setLists(m),
    addHost: (m) => engine.addHost(m.url),
    setSettings: (m) => engine.setSettings(m.patch || {}),
  };

  return async function handle(msg) {
    await engine.ready;
    const fn = actions[msg?.t];
    if (!fn) return { ok: false, error: "Unknown action.", code: "bad_action" };
    try {
      return { ok: true, data: await fn(msg) };
    } catch (err) {
      return { ok: false, error: err?.message || String(err), code: err?.code || "error" };
    }
  };
}
