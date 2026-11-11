<div align="center">

<p align="center"><img src="docs/images/logo.png" width="136" alt="IceDragon VPN"></p>

<h1 align="center">IceDragon VPN</h1>

<h3 align="center">Fast, Encrypted &amp; Open-Source Android VPN with Dark-Glass Design</h3>

[![Last Version](https://img.shields.io/github/v/release/amirwoolyt-maker/icedragon-vpn?style=flat-square&label=Version&color=38BDF8)](https://github.com/amirwoolyt-maker/icedragon-vpn/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/amirwoolyt-maker/icedragon-vpn/total?style=flat-square&logo=github&label=Downloads&color=6366F1)](https://github.com/amirwoolyt-maker/icedragon-vpn/releases)
[![Telegram](https://img.shields.io/badge/Telegram-@icedragon__lair-26A5E4?style=flat-square&logo=telegram)](https://t.me/icedragon_lair)
[![License](https://img.shields.io/github/license/amirwoolyt-maker/icedragon-vpn?style=flat-square&label=License)](LICENSE)

[📥 Download Latest APK](#-quick-download) &bull; [✨ Features](#-why-icedragon-vpn) &bull; [💬 Telegram Channel](https://t.me/icedragon_lair) &bull; [🌐 فارسی](docs/readme/README_fa.md) &bull; [Русский](docs/readme/README_ru.md) &bull; [中文](docs/readme/README_zh.md)

</div>

---

## ✨ Why IceDragon VPN?

**IceDragon VPN** is a fast, free, and open-source Android VPN built for speed, stability, and everyday privacy. Powered by high-throughput **HTTP/2 & HTTP/3** encrypted tunnels, smart multi-account failover, and a sleek **Dark-Glass** interface, it delivers reliable, low-latency connectivity in a single tap.

### Key Highlights

- 🧊 **Dark-Glass Experience:** Clean, fluid, battery-friendly dark UI with instant splash launch (`#070A18`), adaptive dragon crest icon, and real-time connection metrics.
- 🚀 **HTTP/2 & HTTP/3 Encrypted Tunnels:** High-speed encrypted transport built to stay fast and resilient across demanding networks.
- 🔄 **50 GB/month per Account + Smart Failover:** Seamlessly switch between saved accounts at your configured threshold without dropping active connections.
- ⚡ **Quick Server Chips with Live Latency:** One-tap access to recent locations on the home screen with color-coded ping badges (`ms`), plus automatic fastest-server selection.
- 🩺 **1-Tap Auto-Fix & Connect:** Built-in Connection Doctor diagnoses core, DNS, TLS, and relay issues and gets you connected automatically.
- 📲 **Home Screen Widget & Quick Settings Tile:** Connect, disconnect, or reconnect straight from your Android home screen widget or status-bar notification.
- 🛡️ **App Split Tunneling & Built-in Bypass Tools:** Per-app VPN bypass, TLS fragmentation, custom DoH/DoT DNS, and relay support for restrictive networks.
- 🔔 **Automatic Update Notifications:** Stay effortlessly up to date with non-intrusive in-app notifications and direct APK downloads from GitHub Releases.

---

## 📥 Quick Download

Choose the APK matching your Android device:

<table>
  <tr>
    <th>Edition</th>
    <th>Recommended For</th>
    <th>Download</th>
  </tr>
  <tr>
    <td><strong>Android ARM64 (<code>arm64-v8a</code>)</strong></td>
    <td>Modern Android phones &amp; tablets (recommended)</td>
    <td><a href="https://github.com/amirwoolyt-maker/icedragon-vpn/releases/latest/download/IceDragon-VPN-Android-arm64-v8a.apk"><img src="https://img.shields.io/badge/Download-ARM64%20APK-38BDF8?style=flat-square&logo=android" alt="Download ARM64 APK"></a></td>
  </tr>
  <tr>
    <td><strong>Android Universal</strong></td>
    <td>Any Android device (includes all CPU architectures)</td>
    <td><a href="https://github.com/amirwoolyt-maker/icedragon-vpn/releases/latest/download/IceDragon-VPN-Android-universal.apk"><img src="https://img.shields.io/badge/Download-Universal%20APK-6366F1?style=flat-square&logo=android" alt="Download Universal APK"></a></td>
  </tr>
  <tr>
    <td><strong>Android ARMv7 (<code>armeabi-v7a</code>)</strong></td>
    <td>Older 32-bit Android phones &amp; Android TV boxes</td>
    <td><a href="https://github.com/amirwoolyt-maker/icedragon-vpn/releases/latest/download/IceDragon-VPN-Android-armeabi-v7a.apk"><img src="https://img.shields.io/badge/Download-ARMv7%20APK-38BDF8?style=flat-square&logo=android" alt="Download ARMv7 APK"></a></td>
  </tr>
  <tr>
    <td><strong>Android x86_64</strong></td>
    <td>x86_64 Chromebooks, emulators &amp; tablets</td>
    <td><a href="https://github.com/amirwoolyt-maker/icedragon-vpn/releases/latest/download/IceDragon-VPN-Android-x86_64.apk"><img src="https://img.shields.io/badge/Download-x86__64%20APK-38BDF8?style=flat-square&logo=android" alt="Download x86_64 APK"></a></td>
  </tr>
</table>

> Browse all versions, release notes, and SHA-256 checksums on the [Releases page](https://github.com/amirwoolyt-maker/icedragon-vpn/releases).

---

## 💬 Community & Updates

Join the official IceDragon VPN Telegram channel for announcements, troubleshooting tips, release alerts, and direct community support:

👉 **[t.me/icedragon_lair](https://t.me/icedragon_lair)** (`@icedragon_lair`)

---

## 🛠️ Building from Source

GitHub Actions automatically runs Go &amp; Flutter tests and builds signed release APKs on every push to `main` via [`.github/workflows/build-apk.yml`](.github/workflows/build-apk.yml).

To build APKs locally on Windows:

```powershell
.\scripts\build-apk-windows.ps1 -ToolsRoot "E:\icedragon-dev-tools"
```

---

## 📄 License

Released under the [GNU General Public License v3.0](LICENSE).
