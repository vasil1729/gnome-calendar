---
type: build
title: Build the native Windows app
description: Step-by-step MSYS2 UCRT64 build for Evolution Data Server, GNOME Calendar, the runtime bundle, and the native launcher.
tags: [build, msys2, mingw, meson, cmake, windows]
---

# Build the native Windows app

This page is the technical build guide for the `windows-native-port` branch. It
assumes a 64-bit Windows 10 or 11 machine and an internet connection for the
initial MSYS2 package download. The end result is a self-contained folder with
`GNOME Calendar.exe` and all of its runtime data.

## 1. Install MSYS2

Install MSYS2 from <https://www.msys2.org/> and open the **MSYS2 UCRT64** shell.
Do not use the plain MSYS shell or the MINGW64 shell: the build expects the
UCRT64 prefix at `/ucrt64`.

The build was developed with:

- MSYS2 UCRT64
- GCC 16.2.0
- CMake 4.4.5
- Meson 1.12.1
- Ninja 1.13.2
- GTK 4.24.1
- libadwaita 1.10.0
- GLib 2.90.1
- Evolution Data Server 3.63.1

Newer packages should work, but the Windows-specific patches assume the current
UCRT64 package layout.

## 2. Install the build dependencies

From the repository root:

```bash
bash windows/setup-msys2.sh
```

The script installs the UCRT64 toolchain, GTK4, libadwaita, libsoup3, libical,
JSON-GLib, libsecret, SQLite, libxml2, FriBidi, GSettings desktop schemas,
Graphene, libgweather, NSS, ICU, D-Bus, the Adwaita and hicolor icon themes,
gettext, pkgconf, Meson, Ninja, CMake, Blueprint, Python, libtre/libsystre, and
the MSYS `gperf` tool.

It also rewrites the `blueprint-compiler` shebang if the MSYS2 package contains a
path from the package build machine. That package bug shows up as:

```text
/ucrt64/bin/blueprint-compiler: D:\M\msys64\ucrt64\bin/python3.exe: bad interpreter
```

The fix is the first line of `/ucrt64/bin/blueprint-compiler`; the setup script
sets it to `#!/ucrt64/bin/python3.exe`.

## 3. Build Evolution Data Server

```bash
bash windows/build-eds.sh
```

What the script does:

1. Clones `vasil1729/evolution-data-server` at the `windows-native-port` branch
   into `$HOME/src/evolution-data-server-windows` if the directory does not
   exist. Override `EDS_SRC`, `EDS_REPO`, or `EDS_BRANCH` to use another tree.
2. Applies `windows/patches/evolution-data-server-windows.patch` if the checkout
   is an upstream tree and the patch applies cleanly. The fork branch already
   contains the changes.
3. Builds and installs the minimal `libuuid` shim from `windows/uuid-shim/`
   into `/ucrt64`. The shim uses Windows `UuidCreate()` from `rpcrt4.dll`.
4. Configures EDS with CMake and Ninja using the Windows-compatible options:
   GTK3 off, GTK4 on, GOA off, WebKit OAuth off, IPv6 off, libdb/LDAP/Kerberos
   off, `SOCKET_LDFLAGS=ws2_32`, and `REGEX_LDFLAGS=systre`.
5. Builds and installs EDS into `/ucrt64`.

Important: the EDS source is large. The first build takes several minutes. If
the build stops on a missing package, check the package list in
`windows/setup-msys2.sh`.

The EDS changes are documented in
[Evolution Data Server on Windows](../architecture/evolution-data-server.md).
The complete patch is in `windows/patches/evolution-data-server-windows.patch`.

## 4. Build GNOME Calendar

```bash
bash windows/build-gnome-calendar.sh
```

What the script does:

1. Clones the GNOME Calendar `windows-native-port` branch into
   `$HOME/src/gnome-calendar-windows` if needed. Override `GC_SRC`, `GC_REPO`,
   or `GC_BRANCH` to use another tree.
2. Fixes the `blueprint-compiler` shebang again if necessary.
3. Builds the GeoClue API stub from `windows/geoclue-stub/`, installs
   `libgeoclue-2.0.dll`, and writes `libgeoclue-2.0.pc`. The app's Meson build
   requires `libgeoclue-2.0`; the stub satisfies the dependency and returns no
   location, which is the correct behavior on Windows without a location
   provider.
4. Removes the previous build directory, configures the app with Meson into
   `/ucrt64`, builds it, and installs it.

The app changes are small and documented in
[Windows patch catalog](../architecture/windows-patches.md). The most important
one is the `g_type_ensure()` fix for template-only widget types. Without it the
Windows static-library link can drop `GcalDateChooserRow` and `GcalDateSelector`
and the event editor's schedule section fails to build its template at runtime.

## 5. Assemble the portable bundle

```bash
bash windows/build-bundle.sh
```

The default destination is:

```text
C:\Users\<you>\GNOME-Calendar-Native
```

Override it with `BUNDLE`:

```bash
BUNDLE=/d/Apps/GNOME-Calendar-Native bash windows/build-bundle.sh
```

The script:

- Copies `gnome-calendar.exe`, `dbus-daemon.exe`, the EDS factories, the
  GeoClue stub, and `gdk-pixbuf-query-loaders.exe`.
- Copies the EDS registry modules, calendar/addressbook backends, GIO modules,
  GdkPixbuf loaders, GSettings schemas, icons, GTK data, D-Bus configuration,
  fontconfig configuration, GWeather `Locations.bin`, and the selected locales.
- Collects every DLL reported by `ldd` for the app, services, modules, and
  loaders into `bin`.
- Rewrites the D-Bus service files so their `Exec` paths point at the bundle and
  include `.exe`.
- Compiles `GNOME Calendar.exe` from
  `windows/launcher/native-launcher.cs` with the .NET Framework `csc.exe`.

The bundle is relocatable. The launcher regenerates the GdkPixbuf loader cache
with the current absolute path at startup.

## 6. Run it

Double-click:

```text
C:\Users\<you>\GNOME-Calendar-Native\GNOME Calendar.exe
```

The launcher:

1. Closes its inherited console handles so it can run as a GUI process.
2. Sets the runtime environment (GTK, GSettings, GIO, GdkPixbuf, GWeather, EDS).
3. Regenerates the GdkPixbuf loader cache.
4. Picks an ephemeral loopback TCP port and starts `dbus-daemon.exe`.
5. Starts `evolution-source-registry.exe` and
   `evolution-calendar-factory.exe`.
6. Starts `gnome-calendar.exe` and waits for it to exit.
7. Kills the factories and the private bus.

Logs are written to:

```text
%LOCALAPPDATA%\GNOME Calendar\logs
```

The portal and logind warnings are expected. The portal warning means the app
is using its fallback clock format/week start. The logind warning means
suspend/resume integration is unavailable.

## 7. Optional desktop shortcut

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File windows\launcher\build-launcher.ps1 `
  -BundleDir "C:\Users\<you>\GNOME-Calendar-Native" `
  -CreateDesktopShortcut
```

The shortcut points at `GNOME Calendar.exe` and uses the embedded GNOME
Calendar icon.

## Environment variables used by the build

| Variable | Default | Purpose |
| --- | --- | --- |
| `MSYS_PREFIX` | `/ucrt64` | Install prefix for EDS, the app, and the shims. |
| `EDS_SRC` | `$HOME/src/evolution-data-server-windows` | EDS checkout. |
| `EDS_REPO` | `https://github.com/vasil1729/evolution-data-server.git` | EDS repository. |
| `EDS_BRANCH` | `windows-native-port` | EDS branch. |
| `GC_SRC` | `$HOME/src/gnome-calendar-windows` | GNOME Calendar checkout. |
| `GC_REPO` | `https://github.com/vasil1729/gnome-calendar.git` | GNOME Calendar repository. |
| `GC_BRANCH` | `windows-native-port` | GNOME Calendar branch. |
| `BUNDLE` | `C:\Users\$USER\GNOME-Calendar-Native` | Output bundle. |
| `LOCALES` | `en en_GB bg` | Locales copied into the bundle. |

## Build troubleshooting

### `gperf` missing

```bash
pacman -S gperf
```

### `Dependency "uuid" not found`

Run `windows/build-eds.sh`; it installs the shim. Confirm with:

```bash
pkg-config --modversion uuid
```

### `Dependency "libgeoclue-2.0" not found`

Run `windows/build-gnome-calendar.sh`; it installs the stub. Confirm with:

```bash
pkg-config --modversion libgeoclue-2.0
```

### CMake iconv path error

The EDS branch contains the forward-slash fix. If you are building upstream EDS,
apply `windows/patches/evolution-data-server-windows.patch` and pass
`-DCMAKE_POLICY_DEFAULT_CMP0219=NEW`.

### Linker errors for `regcomp`, `regexec`, `regfree`

Install and link `libsystre`:

```bash
pacman -S mingw-w64-ucrt-x86_64-libsystre mingw-w64-ucrt-x86_64-libtre
```

The build script already passes `-DREGEX_LDFLAGS=systre`.

### Linker errors for `accept`, `recv`, `send`, `select`

The build script passes `-DSOCKET_LDFLAGS=ws2_32`. If you are configuring EDS by
hand, add it.

## Related pages

- [Bundle layout and startup](bundle-layout.md)
- [Evolution Data Server on Windows](../architecture/evolution-data-server.md)
- [Windows patch catalog](../architecture/windows-patches.md)
- [Troubleshooting](../operations/troubleshooting.md)
- [Validation](../testing/validation.md)
