---
type: operations
title: Troubleshooting
description: Diagnose MSYS2 build failures, missing DLLs, D-Bus and EDS startup problems, missing calendars, and the expected Windows-only warnings.
tags: [troubleshooting, operations, windows, msys2, dbus, evolution-data-server]
---

# Troubleshooting

This page collects the failures that are specific to the native Windows build.
For the short version, see the troubleshooting section in `WINDOWS.md`.

## Build failures

### `blueprint-compiler` reports `bad interpreter`

Symptom:

```text
/ucrt64/bin/blueprint-compiler: D:\M\msys64\ucrt64\bin/python3.exe: bad interpreter
```

The MSYS2 package can contain a shebang from the package build machine. Run:

```bash
bash windows/setup-msys2.sh
```

or fix it directly:

```bash
sed -i '1s|.*|#!/ucrt64/bin/python3.exe|' /ucrt64/bin/blueprint-compiler
```

Confirm with:

```bash
blueprint-compiler --version
```

### `You need gperf to build evolution-data-server`

Install the MSYS package:

```bash
pacman -S gperf
```

### `Dependency "uuid" not found`

The EDS build needs the UUID shim. Run:

```bash
bash windows/build-eds.sh
pkg-config --modversion uuid
```

The shim installs `/ucrt64/lib/libuuid.a`, `/ucrt64/include/uuid/uuid.h`, and
`/ucrt64/lib/pkgconfig/uuid.pc`.

### `Dependency "libgeoclue-2.0" not found`

The app's Meson build requires libgeoclue. Run:

```bash
bash windows/build-gnome-calendar.sh
pkg-config --modversion libgeoclue-2.0
```

The stub installs `libgeoclue-2.0.dll`, its import library, header, and
pkg-config file.

### CMake fails in `CHECK_C_SOURCE_RUNS` with `Invalid character escape '\m'`

This is the iconv detection path on Windows. The EDS branch uses a forward-slash
build path. If you build upstream EDS, apply
`windows/patches/evolution-data-server-windows.patch` and configure with:

```bash
-DCMAKE_POLICY_DEFAULT_CMP0219=NEW
```

### Linker errors for `regcomp`, `regexec`, `regfree`, `regerror`

Install the regex packages and link `systre`:

```bash
pacman -S mingw-w64-ucrt-x86_64-libsystre mingw-w64-ucrt-x86_64-libtre
```

The EDS build script passes `-DREGEX_LDFLAGS=systre`.

### Linker errors for `accept`, `recv`, `send`, `select`, `closesocket`

The EDS build needs `ws2_32`. The script passes
`-DSOCKET_LDFLAGS=ws2_32`. If you configure by hand, add it.

### `struct stat` / `GStatBuf` warnings or heap corruption

This is the classic MinGW `g_stat()` mismatch: `g_stat()` writes
`struct _stat64` data, but the variable was declared as `struct stat`. The EDS
branch fixes the affected files. If you see this in a new file, use `GStatBuf`
for `g_stat()` and `struct stat` for `fstat()`.

## Runtime failures

### The app starts but shows no calendars

1. Check the logs:

   ```text
   %LOCALAPPDATA%\GNOME Calendar\logs\sources.log
   %LOCALAPPDATA%\GNOME Calendar\logs\calendar.log
   %LOCALAPPDATA%\GNOME Calendar\logs\app.log
   ```

2. Make sure you started the app through `GNOME Calendar.exe`, not by running
   `bin\gnome-calendar.exe` directly. The launcher sets the EDS module paths and
   starts the private D-Bus bus; a direct launch has neither.

3. Verify that the EDS services are running. The launcher starts
   `evolution-source-registry.exe` and `evolution-calendar-factory.exe`. If they
   exit immediately, the log usually shows a missing DLL or a module path.

4. Check that the EDS module environment variables point at the bundle:

   ```text
   EDS_REGISTRY_MODULES
   EDS_CALENDAR_MODULES
   EDS_ADDRESS_BOOK_MODULES
   EDS_SUBPROCESS_CAL_PATH
   EDS_SUBPROCESS_BOOK_PATH
   ```

### `dbus-launch.exe` is not recognized

This line can appear in `sources.log` or `calendar.log`:

```text
'dbus-launch.exe' is not recognized as an internal or external command
```

It comes from EDS's Windows initialization, which tries to ensure D-Bus is
running. The launcher has already started a private bus and set
`DBUS_SESSION_BUS_ADDRESS`, so the line is harmless. The services continue to
use the launcher's bus.

### Portal warning

```text
Failed to read the clock-format setting through the settings portal
```

Windows has no `xdg-desktop-portal`. The app falls back to its default clock
format and first weekday. This is expected.

### logind warning

```text
Error acquiring logind DBus proxy: Could not connect
```

Windows has no logind. The clock component logs this and continues. It only
affects suspend/resume integration.

### GWeather database missing

Symptom:

```text
GWeather: Failed to open database /ucrt64/lib/libgweather-4/Locations.bin
```

The launcher must set `LIBGWEATHER_LOCATIONS_PATH` to the bundle's
`lib\libgweather-4\Locations.bin`. If you launch the app directly, set it
manually:

```text
LIBGWEATHER_LOCATIONS_PATH=C:\path\to\bundle\lib\libgweather-4\Locations.bin
```

### Icons or images are missing

1. Confirm `share/icons/Adwaita` and `share/icons/hicolor` exist in the bundle.
2. Confirm `GDK_PIXBUF_MODULE_FILE` points at the generated `loaders.cache`.
3. Re-run the launcher; it regenerates the cache. The launcher log reports a
   failure if `gdk-pixbuf-query-loaders.exe` cannot run.

### Remote CalDAV/WebDAV calendars fail

1. Confirm the GIO TLS module is available:

   ```text
   GIO_EXTRA_MODULES=<bundle>\lib\gio\modules
   ```

2. Confirm the bundle contains the GIO modules and their DLL dependencies.
3. Check the calendar factory log for TLS, proxy, or certificate errors.
4. The port includes the EDS CalDAV/WebDAV backends but not GNOME Online
   Accounts. Add remote calendars by URL through the calendar-management UI.

### The app exits immediately after launch

Open:

```text
%LOCALAPPDATA%\GNOME Calendar\logs\launcher.log
```

The launcher records the app exit code and the log path. A non-zero exit code
usually means a missing DLL, a missing schema, or a failed EDS service. The
`app.log` contains the app's stdout/stderr.

## Debugging from MSYS2

To run the app with a visible console and custom environment, use the launcher's
environment manually. A minimal example:

```bash
export PATH="/c/Users/<you>/GNOME-Calendar-Native/bin:/c/Users/<you>/GNOME-Calendar-Native/lib:$PATH"
export XDG_DATA_DIRS="C:/Users/<you>/GNOME-Calendar-Native/share"
export GSETTINGS_SCHEMA_DIR="C:/Users/<you>/GNOME-Calendar-Native/share/glib-2.0/schemas"
export FONTCONFIG_PATH="C:/Users/<you>/GNOME-Calendar-Native/etc/fonts"
export LIBGWEATHER_LOCATIONS_PATH="C:/Users/<you>/GNOME-Calendar-Native/lib/libgweather-4/Locations.bin"
export GIO_EXTRA_MODULES="C:/Users/<you>/GNOME-Calendar-Native/lib/gio/modules"
export GDK_PIXBUF_MODULEDIR="C:/Users/<you>/GNOME-Calendar-Native/lib/gdk-pixbuf-2.0/2.10.0/loaders"
export GDK_PIXBUF_MODULE_FILE="C:/Users/<you>/GNOME-Calendar-Native/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
export EDS_REGISTRY_MODULES="C:/Users/<you>/GNOME-Calendar-Native/lib/evolution-data-server/registry-modules"
export EDS_CALENDAR_MODULES="C:/Users/<you>/GNOME-Calendar-Native/lib/evolution-data-server/calendar-backends"
export EDS_ADDRESS_BOOK_MODULES="C:/Users/<you>/GNOME-Calendar-Native/lib/evolution-data-server/addressbook-backends"
export EDS_SUBPROCESS_CAL_PATH="C:/Users/<you>/GNOME-Calendar-Native/libexec/evolution-calendar-factory-subprocess.exe"
export EDS_SUBPROCESS_BOOK_PATH="C:/Users/<you>/GNOME-Calendar-Native/libexec/evolution-addressbook-factory-subprocess.exe"
export GDK_BACKEND=win32
```

Then start a bus and the EDS services in the same shell, set
`DBUS_SESSION_BUS_ADDRESS`, and run `gnome-calendar.exe`. This is useful for
capturing warnings, but the launcher is the supported path.

## Key source

- `windows/launcher/native-launcher.cs` — runtime setup and logs.
- `windows/build-eds.sh` — EDS build options and shims.
- `windows/build-gnome-calendar.sh` — GeoClue stub and Meson build.
- `windows/build-bundle.sh` — runtime assembly and service-file rewriting.
- `windows/patches/evolution-data-server-windows.patch` — backend fixes.

## Related pages

- [Build the native Windows app](../build/windows-native.md)
- [Bundle layout and startup](../build/bundle-layout.md)
- [Evolution Data Server on Windows](../architecture/evolution-data-server.md)
- [Validation](../testing/validation.md)
