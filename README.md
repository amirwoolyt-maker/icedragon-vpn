<div align="center">

**🇺🇸 English** &nbsp;/&nbsp; [🇮🇷 فارسی](docs/readme/README_fa.md)

</div>
<br>

<p align="center"><img src="docs/images/logo.png" width="128" alt="IceDragon VPN"></p>

<h1 align="center">IceDragon VPN</h1>

<h2 align="center">⚠️ Unofficial independent project</h2>

<h3 align="center">IceDragon VPN is a customized Dark-Glass Android client built on the open-source <a href="https://github.com/armanlife/arman-vpn-client">Arman VPN</a> core. It is not made, owned, sponsored, or endorsed by Mozilla, and is not affiliated with Mozilla in any way.</h3>

<div align="center">

[![Downloads](https://img.shields.io/github/downloads/amirwoolyt-maker/icedragon-vpn/total?style=flat-square&logo=github&label=Downloads)](https://github.com/amirwoolyt-maker/icedragon-vpn/releases)
[![Last Version](https://img.shields.io/github/v/release/amirwoolyt-maker/icedragon-vpn?style=flat-square&label=Version)](https://github.com/amirwoolyt-maker/icedragon-vpn/releases/latest)
[![License](https://img.shields.io/github/license/amirwoolyt-maker/icedragon-vpn?style=flat-square&label=License)](LICENSE)

</div>

## What is IceDragon VPN?

**IceDragon VPN** is a free, open-source Android VPN that works with a Firefox Account. It carries your internet traffic through Mozilla's servers on **Fastly**'s infrastructure over secure **HTTP/1.1, HTTP/2, and HTTP/3** tunnels, wrapped in a sleek **Dark Glassmorphism** interface.

Completely free, no ads, no tracking.

## 📥 Download

<table>
<thead>
<tr><th>System</th><th>Download</th></tr>
</thead>
<tbody>
<tr><td>Android</td><td><a href="https://github.com/amirwoolyt-maker/icedragon-vpn/releases/latest/download/IceDragon-VPN-Android-universal.apk"><img src="https://img.shields.io/badge/APK-Universal-1a7f37?logo=android&logoColor=white" alt="APK Universal"></a><br><a href="https://github.com/amirwoolyt-maker/icedragon-vpn/releases/latest/download/IceDragon-VPN-Android-arm64-v8a.apk"><img src="https://img.shields.io/badge/APK-ARMv8-2da44e?logo=android&logoColor=white" alt="APK ARMv8"></a><br><a href="https://github.com/amirwoolyt-maker/icedragon-vpn/releases/latest/download/IceDragon-VPN-Android-armeabi-v7a.apk"><img src="https://img.shields.io/badge/APK-ARMv7-4ac26b?logo=android&logoColor=white" alt="APK ARMv7"></a><br><a href="https://github.com/amirwoolyt-maker/icedragon-vpn/releases/latest/download/IceDragon-VPN-Android-x86_64.apk"><img src="https://img.shields.io/badge/APK-x64-6fdd8b?logo=android&logoColor=white" alt="APK x64"></a></td></tr>
<tr><td>Android TV</td><td><a href="https://github.com/amirwoolyt-maker/icedragon-vpn/releases/latest/download/IceDragon-VPN-Android-universal.apk"><img src="https://img.shields.io/badge/APK-Universal-1a7f37?logo=android&logoColor=white" alt="APK Universal"></a></td></tr>
</tbody>
</table>

**Which file should I download?**

- **ARMv8 (`arm64-v8a`):** Recommended for most modern Android phones (smaller download).
- **Universal (`universal`):** Installs on every Android phone and Android TV.

## 🚀 Main features

- 🐉 **Dark Glassmorphism UI:** Refined dark interface with luminous connection ring, live speed sparkline, session duration timer, and quick location chips.
- ⭐ **Favorites & One-Tap Fastest Server:** Pin favorite countries to the home screen and connect to the fastest server with a single tap.
- 🩺 **Smart Connection Doctor:** Automatically diagnoses DNS filtering, relay health, and tests optimal circumvention combinations (`H2+SNI`, `H3`, `H2+Record`, `H1+First-Byte`).
- 🆓 **50 GB/month per Firefox Account:** Full multi-account support with automatic quota-threshold switching.
- 🔀 **Split Tunneling (App & Site Routing):** Choose which sites (`geosite.dat`, `geoip.dat`) and Android apps bypass the VPN.
- 🔒 **Encrypted DNS (DoH / DoT)**, **TLS Fragment**, **API Relay + ECH**, and **Android Kill Switch** shortcut.
- 🔄 **In-App Update Checker:** Detects the matching APK for your phone architecture right from **Settings → About → Check for updates**.

## 🛠️ Building from source

GitHub Actions automatically tests Go core + Flutter app, builds all Android APKs (`arm64-v8a`, `armeabi-v7a`, `x86_64`, `universal`), and publishes them to [Releases](https://github.com/amirwoolyt-maker/icedragon-vpn/releases).

To build locally on Windows:

```powershell
.\scripts\build-apk-windows.ps1 -ToolsRoot "E:\arman-dev-tools"
```
