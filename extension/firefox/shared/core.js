// Reads the local IceDragon Core status (GET /api/status, no auth when the
// dashboard has no login) and maps it to a small view for the UI.
//
// kind: "offline"  core not reachable (app closed)
//       "login"    core answers 401/403 (dashboard login or token required)
//       "off"      core runs but its proxy is switched off
//       "starting" core is starting / waiting for network
//       "error"    core reports an error
//       "ready"    core proxy is running

import { CORE } from "./constants.js";

export function mapStatus(json) {
  const st = json?.state || {};
  const phase = st.phase || "";
  const proxy = json?.proxy || null;
  const usage = json?.active_account?.usage || null;
  let kind = "ready";
  if (phase === "off") kind = "off";
  else if (phase === "starting" || phase === "waiting") kind = "starting";
  else if (phase === "error") kind = "error";
  else if (phase !== "running") kind = "starting";
  const port = Number(String(proxy?.listen || "").match(/:(\d+)$/)?.[1]) || CORE.proxyPort;
  return {
    kind,
    message: st.message || "",
    version: json?.version || "",
    port,
    country: { code: proxy?.country_code || json?.exit?.country_code || "", name: proxy?.country_name || json?.exit?.country_name || "", city: proxy?.city_name || json?.exit?.city || "" },
    ip: json?.exit?.ipv4 || json?.exit?.ipv6 || "",
    quota: usage
      ? { unlimited: Boolean(usage.unlimited), limit: usage.limit_bytes || 0, remaining: usage.remaining_bytes || 0, reset: usage.reset_at ? Date.parse(usage.reset_at) || 0 : 0 }
      : null,
  };
}

export async function fetchCore(fetchImpl = globalThis.fetch?.bind(globalThis), timeoutMs = 2500) {
  const ctl = new AbortController();
  const timer = setTimeout(() => ctl.abort(), timeoutMs);
  try {
    const r = await fetchImpl(CORE.statusUrl, { cache: "no-store", credentials: "omit", signal: ctl.signal });
    if (r.status === 401 || r.status === 403) return { kind: "login" };
    if (!r.ok) return { kind: "offline" };
    return mapStatus(await r.json());
  } catch {
    return { kind: "offline" };
  } finally {
    clearTimeout(timer);
  }
}
