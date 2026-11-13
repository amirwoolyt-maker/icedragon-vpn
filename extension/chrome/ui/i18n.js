const T = {
  en: {
    connected: "Connected", disconnected: "Disconnected", connecting: "Connecting...", error: "Error",
    tapConnect: "Tap to connect", tapDisconnect: "Tap to disconnect", time: "Time",
    quota: "Quota", left: "left", unlimited: "Unlimited", resets: "Resets",
    modeGlobal: "Whole browser", modeWhite: "Whitelist only", modeBlack: "All except blacklist",
    addSite: "Add current site", added: "Added", settings: "Settings",
    whitelist: "Whitelist (proxied)", blacklist: "Blacklist (direct)",
    listHint: "One domain per line. *.example.com is allowed.", save: "Save", saved: "Saved",
    invalid: "Ignored invalid entries:", webrtc: "Block WebRTC IP leaks", autoConnect: "Connect on browser start",
    language: "Language",
    coreWaiting: "Core status unknown", coreOffline: "Please open the IceDragon app",
    coreLogin: "The core needs a dashboard login; the extension cannot read it",
    coreOff: "Turn on the proxy in the IceDragon app", coreStarting: "The core is starting...",
    coreError: "The core reports an error", coreLost: "IceDragon core is not responding",
  },
  fa: {
    connected: "متصل", disconnected: "قطع", connecting: "در حال اتصال...", error: "خطا",
    tapConnect: "برای اتصال بزنید", tapDisconnect: "برای قطع بزنید", time: "زمان",
    quota: "سهمیه", left: "باقی‌مانده", unlimited: "نامحدود", resets: "بازنشانی",
    modeGlobal: "کل مرورگر", modeWhite: "فقط وایت‌لیست", modeBlack: "همه به جز بلک‌لیست",
    addSite: "افزودن سایت فعلی", added: "اضافه شد", settings: "تنظیمات",
    whitelist: "وایت‌لیست (با پروکسی)", blacklist: "بلک‌لیست (مستقیم)",
    listHint: "هر دامنه در یک خط. *.example.com مجاز است.", save: "ذخیره", saved: "ذخیره شد",
    invalid: "موارد نامعتبر نادیده گرفته شد:", webrtc: "جلوگیری از نشت IP با WebRTC", autoConnect: "اتصال هنگام شروع مرورگر",
    language: "زبان",
    coreWaiting: "وضعیت هسته نامشخص است", coreOffline: "لطفاً برنامه IceDragon را باز کنید",
    coreLogin: "هسته ورود به داشبورد می‌خواهد؛ افزونه نمی‌تواند وضعیت را بخواند",
    coreOff: "پروکسی را در برنامه IceDragon روشن کنید", coreStarting: "هسته در حال راه‌اندازی است...",
    coreError: "هسته خطا گزارش می‌کند", coreLost: "هسته IceDragon پاسخ نمی‌دهد",
  },
};

let lang = "fa";

export function setLang(l) {
  lang = T[l] ? l : "fa";
  document.documentElement.lang = lang;
  document.documentElement.dir = lang === "fa" ? "rtl" : "ltr";
}

export const t = (k) => T[lang][k] ?? T.en[k] ?? k;

export function applyI18n(root = document) {
  root.querySelectorAll("[data-i18n]").forEach((el) => (el.textContent = t(el.dataset.i18n)));
  root.querySelectorAll("[data-i18n-ph]").forEach((el) => (el.placeholder = t(el.dataset.i18nPh)));
}
