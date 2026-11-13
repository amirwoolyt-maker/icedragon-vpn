// UI -> background transport (works with Chrome callbacks and Firefox promises).

const rt = globalThis.browser?.runtime || globalThis.chrome?.runtime;

export function send(msg) {
  return new Promise((resolve, reject) => {
    const done = (res) => {
      if (!res) return reject(new Error("Background not responding."));
      if (!res.ok) return reject(Object.assign(new Error(res.error), { code: res.code }));
      resolve(res.data);
    };
    try {
      const p = rt.sendMessage(msg, done);
      if (p && typeof p.then === "function") p.then(done, reject);
    } catch (e) {
      reject(e);
    }
  });
}

export const isFirefox = typeof globalThis.browser !== "undefined" && !!globalThis.browser.runtime?.getBrowserInfo;

export async function activeTabUrl() {
  const tabs = globalThis.browser?.tabs || globalThis.chrome?.tabs;
  const res = await new Promise((resolve) => {
    const p = tabs.query({ active: true, currentWindow: true }, resolve);
    if (p && p.then) p.then(resolve);
  });
  return res?.[0]?.url || "";
}

export function openOptions() {
  const r = globalThis.browser?.runtime || globalThis.chrome.runtime;
  r.openOptionsPage();
}
