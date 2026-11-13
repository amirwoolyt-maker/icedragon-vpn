// Routing engine shared by Firefox (proxy.onRequest) and Chrome (PAC script).
//
// hostMatches / isLocalHost / decideRoute are written in plain ES5 and are
// self-contained on purpose: generatePac() embeds their source verbatim in the
// PAC script, so both browsers always make the exact same decision.

import { MODES } from "./constants.js";

/* ------------------------- rule normalisation ------------------------- */

/**
 * Normalise a user-entered rule to a canonical host pattern.
 *   "https://www.YouTube.com/watch?v=1" -> "www.youtube.com"
 *   "*.example.com"                     -> "example.com"   (apex + subdomains)
 *   "*.ir"                              -> "ir"
 *   "ab*.example.com"                   -> "ab*.example.com" (glob)
 * Returns null when the entry is not a valid pattern.
 */
export function normalizeEntry(raw) {
  let s = String(raw ?? "").trim().toLowerCase();
  if (!s) return null;
  s = s.replace(/^[a-z][a-z0-9+.-]*:\/\//, "");
  s = s.replace(/[/?#].*$/, "");
  s = s.replace(/^[^@]*@/, "");
  if (!s.startsWith("[")) s = s.replace(/:\d+$/, "");
  s = s.replace(/^\*\./, "").replace(/^\.+/, "").replace(/\.+$/, "");
  if (!s || s === "*" || s.includes("..")) return null;
  if (!/^[a-z0-9*_.\-\u0080-\uffff]+$/.test(s)) return null;
  if (!s.includes("*")) {
    try {
      s = new URL("http://" + s).hostname; // punycode for IDN
    } catch {
      return null;
    }
  }
  return s || null;
}

export function normalizeList(list) {
  const out = [];
  const seen = new Set();
  const invalid = [];
  for (const raw of Array.isArray(list) ? list : []) {
    if (!String(raw ?? "").trim()) continue;
    const n = normalizeEntry(raw);
    if (!n) invalid.push(String(raw));
    else if (!seen.has(n)) {
      seen.add(n);
      out.push(n);
    }
  }
  return { list: out, invalid };
}

/** Compile a normalised list into the structure hostMatches() consumes. */
export function compileRules(list) {
  const suffixes = [];
  const globs = [];
  for (const entry of list || []) {
    if (entry.includes("*")) {
      const src = "^" + entry.replace(/[.+?^${}()|[\]\\]/g, "\\$&").replace(/\*/g, ".*") + "$";
      globs.push(src);
    } else {
      suffixes.push(entry);
    }
  }
  return { suffixes: suffixes, globs: globs };
}

/* ------------------- ES5, PAC-embeddable decision code ------------------- */

export function hostMatches(host, rules) {
  host = String(host).toLowerCase();
  var i;
  var s = rules.suffixes;
  for (i = 0; i < s.length; i++) {
    if (host === s[i]) return true;
    if (host.length > s[i].length && host.slice(-s[i].length - 1) === "." + s[i]) return true;
  }
  var g = rules.globs;
  for (i = 0; i < g.length; i++) {
    if (new RegExp(g[i]).test(host)) return true;
  }
  return false;
}

export function isLocalHost(host) {
  host = String(host).toLowerCase().replace(/^\[|\]$/g, "");
  if (host === "localhost" || host === "::1" || host.indexOf(".") === -1 && host.indexOf(":") === -1) return true;
  if (/\.(local|localhost|lan|internal|home\.arpa)$/.test(host)) return true;
  var m = /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/.exec(host);
  if (m) {
    var a = +m[1];
    var b = +m[2];
    if (a === 10 || a === 127 || a === 0) return true;
    if (a === 169 && b === 254) return true;
    if (a === 192 && b === 168) return true;
    if (a === 172 && b >= 16 && b <= 31) return true;
  }
  if (/^(fc|fd|fe8|fe9|fea|feb)/.test(host) && host.indexOf(":") !== -1) return true;
  return false;
}

/**
 * cfg = { mode, wl: compiledRules, bl: compiledRules, direct: string[], force: string[] }
 * returns "proxy" | "direct"
 */
export function decideRoute(host, cfg) {
  if (hostMatches(host, { suffixes: cfg.force || [], globs: [] })) return "proxy";
  if (isLocalHost(host)) return "direct";
  if (hostMatches(host, { suffixes: cfg.direct || [], globs: [] })) return "direct";
  if (cfg.mode === "whitelist") return hostMatches(host, cfg.wl) ? "proxy" : "direct";
  if (cfg.mode === "blacklist") return hostMatches(host, cfg.bl) ? "direct" : "proxy";
  return "proxy";
}

/* ------------------------------- PAC output ------------------------------- */

function safeHost(h) {
  return String(h).replace(/[^a-zA-Z0-9.\-:\[\]]/g, "");
}

/**
 * Build the PAC script for Chromium. There is deliberately no DIRECT fallback
 * after the proxy: if the proxy is down, traffic fails instead of leaking.
 */
export function generatePac({ host, port }, cfg) {
  const addr = `${safeHost(host)}:${Number(port) | 0}`;
  const proxy = `PROXY ${addr}; SOCKS5 ${addr}`;
  return [
    "// IceDragon VPN (standalone) - generated, do not edit",
    hostMatches.toString(),
    isLocalHost.toString(),
    decideRoute.toString(),
    `var CFG = ${JSON.stringify(cfg)};`,
    `var PROXY = ${JSON.stringify(proxy)};`,
    'function FindProxyForURL(url, host) { return decideRoute(host, CFG) === "proxy" ? PROXY : "DIRECT"; }',
    "",
  ].join("\n");
}

export function hostOf(url) {
  try {
    return new URL(url).hostname.replace(/^\[|\]$/g, "");
  } catch {
    return "";
  }
}

export function buildRouteConfig(settings, extraDirect = [], force = []) {
  return {
    mode: Object.values(MODES).includes(settings.mode) ? settings.mode : MODES.GLOBAL,
    wl: compileRules(normalizeList(settings.whitelist).list),
    bl: compileRules(normalizeList(settings.blacklist).list),
    direct: extraDirect,
    force: force,
  };
}
