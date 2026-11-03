#!/usr/bin/env bash
# Run this from the MSYS2 UCRT64 shell.
set -euo pipefail

if [ "${MSYSTEM:-}" != "UCRT64" ]; then
  echo "error: run this script from the MSYS2 UCRT64 shell" >&2
  exit 1
fi

pacman -S --needed --noconfirm \
  mingw-w64-ucrt-x86_64-toolchain \
  mingw-w64-ucrt-x86_64-gtk4 \
  mingw-w64-ucrt-x86_64-libadwaita \
  mingw-w64-ucrt-x86_64-libsoup3 \
  mingw-w64-ucrt-x86_64-libical \
  mingw-w64-ucrt-x86_64-json-glib \
  mingw-w64-ucrt-x86_64-libsecret \
  mingw-w64-ucrt-x86_64-sqlite3 \
  mingw-w64-ucrt-x86_64-libxml2 \
  mingw-w64-ucrt-x86_64-fribidi \
  mingw-w64-ucrt-x86_64-gsettings-desktop-schemas \
  mingw-w64-ucrt-x86_64-graphene \
  mingw-w64-ucrt-x86_64-libgweather \
  mingw-w64-ucrt-x86_64-nss \
  mingw-w64-ucrt-x86_64-icu \
  mingw-w64-ucrt-x86_64-dbus \
  mingw-w64-ucrt-x86_64-adwaita-icon-theme \
  mingw-w64-ucrt-x86_64-hicolor-icon-theme \
  mingw-w64-ucrt-x86_64-gettext \
  mingw-w64-ucrt-x86_64-pkgconf \
  mingw-w64-ucrt-x86_64-meson \
  mingw-w64-ucrt-x86_64-ninja \
  mingw-w64-ucrt-x86_64-cmake \
  mingw-w64-ucrt-x86_64-blueprint-compiler \
  mingw-w64-ucrt-x86_64-python \
  mingw-w64-ucrt-x86_64-libtre \
  mingw-w64-ucrt-x86_64-libsystre \
  gperf

# The blueprint-compiler package can ship a shebang containing the build
# machine's absolute path. Rewrite it to the local UCRT64 Python.
BLUEPRINT=/ucrt64/bin/blueprint-compiler
if [ -f "$BLUEPRINT" ] && ! head -1 "$BLUEPRINT" | grep -q '^#!/ucrt64/bin/python3.exe'; then
  sed -i '1s|.*|#!/ucrt64/bin/python3.exe|' "$BLUEPRINT"
fi

echo "MSYS2 UCRT64 build dependencies are installed."
