#!/usr/bin/env bash
# Assemble a self-contained Windows bundle for GNOME Calendar.
# Run from the MSYS2 UCRT64 shell after build-eds.sh and
# build-gnome-calendar.sh.
set -euo pipefail

if [ "${MSYSTEM:-}" != "UCRT64" ]; then
  echo "error: run this script from the MSYS2 UCRT64 shell" >&2
  exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MSYS_PREFIX=${MSYS_PREFIX:-/ucrt64}
BUNDLE=${BUNDLE:-/c/Users/$USER/GNOME-Calendar-Native}
LOCALES=${LOCALES:-"en en_GB bg"}

if [ -z "$BUNDLE" ] || [ "$BUNDLE" = "/" ]; then
  echo "error: refusing to use an unsafe bundle path: $BUNDLE" >&2
  exit 1
fi

BUNDLE_WIN=$(cygpath -m "$BUNDLE")

rm -rf "$BUNDLE"
mkdir -p "$BUNDLE"/bin "$BUNDLE"/libexec "$BUNDLE"/lib "$BUNDLE"/share "$BUNDLE"/etc
cp -f "$SCRIPT_DIR/bundle-README.txt" "$BUNDLE/README.txt"
if [ -f "$SCRIPT_DIR/../COPYING" ]; then
  cp -f "$SCRIPT_DIR/../COPYING" "$BUNDLE/COPYING"
fi

collect_dlls() {
  ldd "$1" 2>/dev/null | awk '/=> \/ucrt64\// {print $3}' | sort -u
}

copy_dlls_for() {
  local target="$1"
  local dll
  [ -f "$target" ] || return 0
  for dll in $(collect_dlls "$target"); do
    cp -f "$dll" "$BUNDLE/bin/"
  done
}

echo "Copying executables"
cp -f "$MSYS_PREFIX/bin/gnome-calendar.exe" "$BUNDLE/bin/"
cp -f "$MSYS_PREFIX/bin/dbus-daemon.exe" "$BUNDLE/bin/"
cp -f "$MSYS_PREFIX/bin/libgeoclue-2.0.dll" "$BUNDLE/bin/"
cp -f "$MSYS_PREFIX/bin/gdk-pixbuf-query-loaders.exe" "$BUNDLE/bin/"

for exe in \
  evolution-source-registry.exe \
  evolution-calendar-factory.exe \
  evolution-calendar-factory-subprocess.exe \
  evolution-addressbook-factory.exe \
  evolution-addressbook-factory-subprocess.exe \
  glib-pacrunner.exe
do
  if [ -f "$MSYS_PREFIX/libexec/$exe" ]; then
    cp -f "$MSYS_PREFIX/libexec/$exe" "$BUNDLE/libexec/"
  fi
done

echo "Copying modules and data"
cp -a "$MSYS_PREFIX/lib/evolution-data-server" "$BUNDLE/lib/"
cp -a "$MSYS_PREFIX/lib/gio" "$BUNDLE/lib/"
cp -a "$MSYS_PREFIX/lib/gdk-pixbuf-2.0" "$BUNDLE/lib/"
cp -a "$MSYS_PREFIX/share/glib-2.0" "$BUNDLE/share/"
cp -a "$MSYS_PREFIX/share/icons" "$BUNDLE/share/"
cp -a "$MSYS_PREFIX/share/gtk-4.0" "$BUNDLE/share/"
cp -a "$MSYS_PREFIX/share/dbus-1" "$BUNDLE/share/"
cp -a "$MSYS_PREFIX/etc/fonts" "$BUNDLE/etc/"
mkdir -p "$BUNDLE/lib/libgweather-4"
cp -f "$MSYS_PREFIX/lib/libgweather-4/Locations.bin" "$BUNDLE/lib/libgweather-4/"

mkdir -p "$BUNDLE/share/locale"
for loc in $LOCALES; do
  if [ -d "$MSYS_PREFIX/share/locale/$loc" ]; then
    cp -a "$MSYS_PREFIX/share/locale/$loc" "$BUNDLE/share/locale/"
  fi
done

echo "Collecting DLL dependencies"
copy_dlls_for "$MSYS_PREFIX/bin/gnome-calendar.exe"
copy_dlls_for "$MSYS_PREFIX/bin/dbus-daemon.exe"
copy_dlls_for "$MSYS_PREFIX/bin/libgeoclue-2.0.dll"
copy_dlls_for "$MSYS_PREFIX/bin/gdk-pixbuf-query-loaders.exe"
for exe in "$BUNDLE"/libexec/*.exe; do
  copy_dlls_for "$exe"
done
for dll in "$MSYS_PREFIX"/lib/evolution-data-server/*/*.dll; do
  copy_dlls_for "$dll"
done
for dll in "$MSYS_PREFIX"/lib/gio/modules/*.dll; do
  copy_dlls_for "$dll"
done
for dll in "$MSYS_PREFIX"/lib/gdk-pixbuf-2.0/2.10.0/loaders/*.dll; do
  copy_dlls_for "$dll"
done

echo "Rewriting D-Bus service files for the bundle"
for f in "$BUNDLE"/share/dbus-1/services/*.service; do
  [ -f "$f" ] || continue
  sed -i "s|C:/msys64/ucrt64|$BUNDLE_WIN|g; s|/ucrt64|$BUNDLE_WIN|g" "$f"
  awk '/^Exec=/ && $0 !~ /\.exe([[:space:]]|$)/ { sub(/^Exec=[^[:space:]]+/, "&.exe") } { print }' "$f" > "$f.tmp"
  mv "$f.tmp" "$f"
done

echo "Building the native launcher"
if command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -ExecutionPolicy Bypass \
    -File "$(cygpath -w "$SCRIPT_DIR/launcher/build-launcher.ps1")" \
    -BundleDir "$(cygpath -w "$BUNDLE")"
else
  echo "warning: powershell.exe not found; build windows/launcher/build-launcher.ps1 manually" >&2
fi

echo "Bundle created at $BUNDLE"
du -sh "$BUNDLE"
