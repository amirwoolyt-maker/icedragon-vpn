import { send, activeTabUrl, openOptions } from "./client.js";
import { applyI18n, setLang, t } from "./i18n.js";

const $ = (s) => document.querySelector(s);
let state = null;
let busy = false;

const FLAGS = new Set(["ar","at","au","be","bg","br","ca","cl","co","de","dk","es","fi","fr","gb","gh","ie","it","jp","kr","mx","my","nl","no","nz","pe","ph","pt","se","sg","th","us","za"]);

function toast(msg) {
  const el = $("#toast");
  el.textContent = msg;
  el.hidden = false;
  clearTimeout(toast.t);
  toast.t = setTimeout(() => (el.hidden = true), 2200);
}

function setFlag(el, code) {
  const c = String(code || "").toLowerCase();
  if (FLAGS.has(c)) {
    el.style.backgroundImage = `url(../assets/flags/${c}.svg)`;
    el.textContent = "";
  } else {
    el.style.backgroundImage = "";
    el.textContent = c ? c.toUpperCase() : "\u2605";
  }
}

function fmtGB(n) {
  return (n / 1e9).toFixed(n >= 1e10 ? 0 : 1) + " GB";
}

const CORE_MSG = { offline: "coreOffline", login: "coreLogin", off: "coreOff", starting: "coreStarting", error: "coreError" };

function render() {
  setLang(state.settings.lang);
  applyI18n();
  const { conn, core } = state;
  const st = conn.status;
  const lost = st === "connected" && core.kind !== "ready";
  const cls = lost ? "err" : st === "connected" ? "on" : st === "connecting" ? "busy" : st === "error" ? "err" : "off";
  $("#pill").className = "pill " + cls;
  $("#pill-text").textContent = t(st);
  $("#power").className = "power " + (cls === "err" || cls === "off" ? "off" : cls);
  $("#status-text").textContent = t(st);
  $("#status-sub").textContent = st === "connected" ? t("tapDisconnect") : t("tapConnect");

  // Message: core problems first, then the last connect error.
  let msg = "";
  if (lost) msg = t(core.kind === "offline" ? "coreLost" : CORE_MSG[core.kind]);
  else if (st !== "connected" && core.kind !== "ready" && core.kind !== undefined) msg = t(CORE_MSG[core.kind] || "coreWaiting");
  $("#conn-err").hidden = !msg;
  $("#conn-err").textContent = msg;

  const c = core.country || { code: "", name: "", city: "" };
  const ready = core.kind === "ready";
  $("#server-host").textContent = (ready && core.ip) || "-";
  $("#loc-name").textContent = (ready && c.name) || "-";
  $("#loc-city").textContent = (ready && c.city) || "";
  setFlag($("#loc-flag"), ready ? c.code : "");

  const q = ready ? core.quota : null;
  $("#quota-card").hidden = !q;
  if (q) {
    if (q.unlimited) {
      $("#quota-left").textContent = t("unlimited");
      $("#quota-bar").style.width = "100%";
      $("#quota-reset").textContent = "";
    } else {
      $("#quota-left").textContent = fmtGB(q.remaining) + " " + t("left");
      $("#quota-bar").style.width = Math.max(0, Math.min(100, q.limit ? (q.remaining / q.limit) * 100 : 0)) + "%";
      $("#quota-reset").textContent = q.reset ? t("resets") + " " + new Date(q.reset).toLocaleDateString() : "";
    }
  }
  document.querySelectorAll("#modes button").forEach((b) => b.classList.toggle("active", b.dataset.mode === state.settings.mode));
  $("#btn-add").hidden = state.settings.mode === "global";
  tickTimer();
}

function tickTimer() {
  const since = state?.conn.status === "connected" ? state.conn.since : 0;
  if (!since) return ($("#timer").textContent = "00:00:00");
  const s = Math.max(0, Math.floor((Date.now() - since) / 1000));
  const p = (n) => String(n).padStart(2, "0");
  $("#timer").textContent = `${p(Math.floor(s / 3600))}:${p(Math.floor((s % 3600) / 60))}:${p(s % 60)}`;
}

async function call(msg) {
  try {
    const data = await send(msg);
    if (data && data.conn) state = data;
    else if (data?.state) state = data.state;
    return data;
  } catch (e) {
    toast(e.message);
    throw e;
  } finally {
    if (state) render();
  }
}

async function runBusy(fn) {
  if (busy) return;
  busy = true;
  if (state) {
    state.conn.status = "connecting";
    render();
  }
  try {
    await fn();
  } catch {
    /* toast shown */
  } finally {
    busy = false;
    if (state) render();
  }
}

$("#power").addEventListener("click", () =>
  runBusy(() => call({ t: state.conn.status === "connected" ? "disconnect" : "connect" }))
);
$("#btn-settings").addEventListener("click", openOptions);
document.querySelectorAll("#modes button").forEach((b) =>
  b.addEventListener("click", () => call({ t: "setMode", mode: b.dataset.mode }).catch(() => {}))
);
$("#btn-add").addEventListener("click", async () => {
  try {
    const r = await call({ t: "addHost", url: await activeTabUrl() });
    toast(`${t("added")}: ${r.host}`);
  } catch {
    /* toast */
  }
});

async function boot() {
  try {
    state = await send({ t: "refresh" });
    render();
  } catch (e) {
    toast(e.message);
  }
  setInterval(tickTimer, 1000);
  setInterval(async () => {
    if (busy) return;
    try {
      state = await send({ t: "refresh" });
      render();
    } catch { /* ignore */ }
  }, 3000);
}
boot();
