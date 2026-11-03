#!/usr/bin/env bash
# Build and install GNOME Calendar for the native Windows port.
# Run from the MSYS2 UCRT64 shell after build-eds.sh.
set -euo pipefail

if [ "${MSYSTEM:-}" != "UCRT64" ]; then
  echo "error: run this script from the MSYS2 UCRT64 shell" >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MSYS_PREFIX=${MSYS_PREFIX:-/ucrt64}
GC_SRC=${GC_SRC:-$HOME/src/gnome-calendar-windows}
GC_BUILD=${GC_BUILD:-$GC_SRC/build}
GC_REPO=${GC_REPO:-https://github.com/vasil1729/gnome-calendar.git}
GC_BRANCH=${GC_BRANCH:-windows-native-port}

if [ ! -d "$GC_SRC/.git" ]; then
  git clone --branch "$GC_BRANCH" "$GC_REPO" "$GC_SRC"
fi

# The blueprint-compiler package can contain a build-machine shebang.
BLUEPRINT="$MSYS_PREFIX/bin/blueprint-compiler"
if [ -f "$BLUEPRINT" ] && ! head -1 "$BLUEPRINT" | grep -q "^#!$MSYS_PREFIX/bin/python3.exe"; then
  sed -i "1s|.*|#!$MSYS_PREFIX/bin/python3.exe|" "$BLUEPRINT"
fi

# GNOME Calendar requires libgeoclue. The weather location provider is
# not available on Windows, so use a small API-compatible stub.
SHIM="$SCRIPT_DIR/geoclue-stub"
gcc -shared -o "$MSYS_PREFIX/bin/libgeoclue-2.0.dll" "$SHIM/geoclue.c" \
  -I"$SHIM" \
  -Wl,--out-implib,"$MSYS_PREFIX/lib/libgeoclue-2.0.dll.a" \
  $(pkg-config --cflags --libs gobject-2.0 gio-2.0)
mkdir -p "$MSYS_PREFIX/include/libgeoclue-2.0" "$MSYS_PREFIX/lib/pkgconfig"
cp "$SHIM/geoclue.h" "$MSYS_PREFIX/include/libgeoclue-2.0/geoclue.h"
sed "s|@PREFIX@|$MSYS_PREFIX|g" "$SHIM/libgeoclue-2.0.pc.in" > "$MSYS_PREFIX/lib/pkgconfig/libgeoclue-2.0.pc"

rm -rf "$GC_BUILD"
meson setup "$GC_BUILD" "$GC_SRC" \
  --prefix="$MSYS_PREFIX" \
  --buildtype=release

ninja -C "$GC_BUILD"
ninja -C "$GC_BUILD" install

echo "GNOME Calendar installed into $MSYS_PREFIX."
