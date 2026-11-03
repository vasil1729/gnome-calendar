#!/usr/bin/env bash
# Build and install Evolution Data Server for the native Windows port.
# Run from the MSYS2 UCRT64 shell.
set -euo pipefail

if [ "${MSYSTEM:-}" != "UCRT64" ]; then
  echo "error: run this script from the MSYS2 UCRT64 shell" >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MSYS_PREFIX=${MSYS_PREFIX:-/ucrt64}
EDS_SRC=${EDS_SRC:-$HOME/src/evolution-data-server-windows}
EDS_BUILD=${EDS_BUILD:-$EDS_SRC/build}
EDS_REPO=${EDS_REPO:-https://github.com/vasil1729/evolution-data-server.git}
EDS_BRANCH=${EDS_BRANCH:-windows-native-port}
EDS_PATCH="$SCRIPT_DIR/patches/evolution-data-server-windows.patch"

if [ ! -d "$EDS_SRC/.git" ]; then
  git clone --branch "$EDS_BRANCH" "$EDS_REPO" "$EDS_SRC"
fi

# The fork branch already contains the changes. If this is an upstream
# checkout, apply the patch instead.
if [ -f "$EDS_PATCH" ] && git -C "$EDS_SRC" apply --check "$EDS_PATCH" 2>/dev/null; then
  git -C "$EDS_SRC" apply "$EDS_PATCH"
fi

# Evolution Data Server requires libuuid. Windows has UUID support in
# rpcrt4.dll, so a tiny compatibility shim is enough.
SHIM="$SCRIPT_DIR/uuid-shim"
gcc -O2 -c "$SHIM/uuid.c" -o "$SHIM/uuid.o"
ar rcs "$MSYS_PREFIX/lib/libuuid.a" "$SHIM/uuid.o"
mkdir -p "$MSYS_PREFIX/include/uuid" "$MSYS_PREFIX/lib/pkgconfig"
cp "$SHIM/uuid/uuid.h" "$MSYS_PREFIX/include/uuid/uuid.h"
sed "s|@PREFIX@|$MSYS_PREFIX|g" "$SHIM/uuid.pc.in" > "$MSYS_PREFIX/lib/pkgconfig/uuid.pc"

rm -rf "$EDS_BUILD"
cmake -S "$EDS_SRC" -B "$EDS_BUILD" -G Ninja \
  -DCMAKE_INSTALL_PREFIX="$MSYS_PREFIX" \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_POLICY_DEFAULT_CMP0219=NEW \
  -DENABLE_GTK=OFF \
  -DENABLE_GTK4=ON \
  -DENABLE_GOA=OFF \
  -DENABLE_WEATHER=ON \
  -DENABLE_CANBERRA=OFF \
  -DENABLE_OAUTH2_WEBKITGTK=OFF \
  -DENABLE_OAUTH2_WEBKITGTK4=OFF \
  -DENABLE_TESTS=OFF \
  -DENABLE_EXAMPLES=OFF \
  -DENABLE_INTROSPECTION=OFF \
  -DENABLE_VALA_BINDINGS=OFF \
  -DENABLE_SMIME=OFF \
  -DENABLE_DOT_LOCKING=OFF \
  -DENABLE_IPV6=OFF \
  -DWITH_LIBDB=OFF \
  -DWITH_OPENLDAP=OFF \
  -DWITH_SUNLDAP=OFF \
  -DWITH_KRB5=OFF \
  -DSOCKET_LDFLAGS=ws2_32 \
  -DREGEX_LDFLAGS=systre

ninja -C "$EDS_BUILD"
ninja -C "$EDS_BUILD" install

echo "Evolution Data Server installed into $MSYS_PREFIX."
