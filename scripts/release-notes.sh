#!/usr/bin/env bash
# Prints release notes for <tag>: extracts the Download <table> from README.md
# and rewrites releases/latest/download links to versioned release assets.
set -euo pipefail

tag="${1:?usage: release-notes.sh <tag>}"
version="${tag#v}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "## 📥 دانلود مستقیم / Direct Download"
echo
awk '/^<table>/ { p = 1 } p { print } /^<\/table>/ && p { exit }' "$root/README.md" |
  sed -e "s|releases/latest/download/IceDragon-VPN-|releases/download/$tag/IceDragon-VPN-$version-|g" \
      -e "s|releases/latest/download/|releases/download/$tag/|g"
