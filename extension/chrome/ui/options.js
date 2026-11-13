import { send } from "./client.js";
import { applyI18n, setLang, t } from "./i18n.js";

const $ = (s) => document.querySelector(s);
let state;

function render() {
  setLang(state.settings.lang);
  applyI18n();
  $("#lang").value = state.settings.lang;
  $("#webrtc").checked = state.settings.webrtcProtect;
  $("#auto").checked = state.settings.autoConnect;
  $("#wl").value = state.settings.whitelist.join("\n");
  $("#bl").value = state.settings.blacklist.join("\n");
  document.querySelectorAll("#modes button").forEach((b) => b.classList.toggle("active", b.dataset.mode === state.settings.mode));
}

const lines = (id) => $(id).value.split(/\r?\n/);

async function act(msg) {
  const data = await send(msg);
  state = data?.state || data;
  render();
  return data;
}

document.querySelectorAll("#modes button").forEach((b) =>
  b.addEventListener("click", () => act({ t: "setMode", mode: b.dataset.mode }))
);
$("#save").addEventListener("click", async () => {
  try {
    const r = await act({ t: "setLists", whitelist: lines("#wl"), blacklist: lines("#bl") });
    const bad = [...(r.invalid.whitelist || []), ...(r.invalid.blacklist || [])];
    $("#msg").textContent = bad.length ? `${t("invalid")} ${bad.join(", ")}` : t("saved");
  } catch (e) {
    $("#msg").textContent = e.message;
  }
});
for (const [sel, key] of [["#webrtc", "webrtcProtect"], ["#auto", "autoConnect"]]) {
  $(sel).addEventListener("change", (e) => act({ t: "setSettings", patch: { [key]: e.target.checked } }));
}
$("#lang").addEventListener("change", (e) => act({ t: "setSettings", patch: { lang: e.target.value } }));

send({ t: "state" }).then((s) => {
  state = s;
  render();
});
