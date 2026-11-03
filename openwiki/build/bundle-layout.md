---
type: build
title: Bundle layout and startup
description: The portable Windows folder, the native launcher's process sequence, D-Bus and EDS startup, relocatability, and log locations.
tags: [bundle, launcher, dbus, evolution-data-server, windows]
---

# Bundle layout and startup

The build output is a portable folder rather than a single monolithic `.exe`.
That is normal for GTK applications: the executable is small, and the runtime
lives in DLLs, loadable modules, schemas, icons, and data files. The folder can
be moved or copied as a unit.

## Layout

```text
GNOME-Calendar-Native/
  GNOME Calendar.exe        native launcher (WinExe)
  bin/
    gnome-calendar.exe      the GTK application
    dbus-daemon.exe
    gdk-pixbuf-query-loaders.exe
    libgeoclue-2.0.dll      GeoClue API stub
    *.dll                   GTK, GLib, Pango, Cairo, GdkPixbuf,
                            GWeather, libsoup, libical, NSS, ICU,
                            Evolution Data Server, and compiler runtimes
  libexec/
    evolution-source-registry.exe
    evolution-calendar-factory.exe
    evolution-calendar-factory-subprocess.exe
    evolution-addressbook-factory.exe
    evolution-addressbook-factory-subprocess.exe
    glib-pacrunner.exe
  lib/
    evolution-data-server/
      registry-modules/
      calendar-backends/
      addressbook-backends/
      camel-providers/
    gio/modules/
    gdk-pixbuf-2.0/2.10.0/loaders/
    libgweather-4/Locations.bin
  share/
    glib-2.0/schemas/       compiled GSettings schemas
    icons/                  Adwaita and hicolor themes
    gtk-4.0/
    dbus-1/                 service files and bus configuration
    locale/                 selected translations
  etc/fonts/                fontconfig configuration
```

`windows/build-bundle.sh` creates this layout. The `bin` directory is both the
application directory and the first entry in `PATH`, so the Windows loader finds
the bundled DLLs before any system copy.

## Launcher responsibilities

The launcher is `windows/launcher/native-launcher.cs`, compiled to
`GNOME Calendar.exe`. It is a WinExe, not a console application. Its job is to
make the GTK/EDS runtime look like a normal Windows application.

### 1. Detach inherited handles

The launcher calls `FreeConsole()` and closes its inherited standard handles.
This lets it run cleanly from Explorer, a shortcut, or a terminal without
holding the parent's pipes open.

### 2. Set the runtime environment

It sets the paths described in
[GTK and the Windows runtime](../architecture/gtk-runtime.md). The important
ones are `PATH`, `XDG_DATA_DIRS`, `GSETTINGS_SCHEMA_DIR`, `FONTCONFIG_PATH`,
`LIBGWEATHER_LOCATIONS_PATH`, `GIO_EXTRA_MODULES`, the GdkPixbuf module
variables, the EDS module variables, and `GDK_BACKEND=win32`.

### 3. Regenerate the GdkPixbuf cache

`RegeneratePixbufCache()` runs `bin/gdk-pixbuf-query-loaders.exe` with the
absolute paths of the loader DLLs in
`lib/gdk-pixbuf-2.0/2.10.0/loaders/`, captures its output, and writes
`lib/gdk-pixbuf-2.0/2.10.0/loaders.cache`. This is what makes the bundle
relocatable: the cache contains the current bundle path, not the build machine's
path.

If the tool is missing or fails, the launcher logs the error and continues with
the existing cache.

### 4. Start a private D-Bus session

The launcher picks an ephemeral loopback TCP port with a temporary
`TcpListener`, then starts:

```text
bin\dbus-daemon.exe --session --address=tcp:host=127.0.0.1,port=<port> --print-address=1 --print-pid=1
```

It reads the printed address, validates that it starts with `tcp:`, and sets
`DBUS_SESSION_BUS_ADDRESS` in its own environment. The EDS services and the app
inherit it.

The private bus means the app does not depend on a system D-Bus installation and
does not interfere with any other D-Bus session on the machine.

### 5. Start Evolution Data Server

The launcher starts:

```text
libexec\evolution-source-registry.exe
libexec\evolution-calendar-factory.exe
```

It waits three seconds for the services to acquire their D-Bus names. The
address-book factory is not started eagerly; it is available through D-Bus
activation if the birthday calendar or another contact-backed source needs it.
The launcher sets `EDS_ADDRESS_BOOK_MODULES` and `EDS_SUBPROCESS_BOOK_PATH` so
that activated instance uses the bundle's files.

### 6. Start the app and wait

The launcher starts `bin\gnome-calendar.exe` with the same environment, captures
its stdout/stderr into the log directory, and waits for it to exit. The app is
built as a Windows GUI subsystem executable (`win_subsystem: 'windows'`) and is
started with `CreateNoWindow = true`, so the shortcut does not open a terminal
window. If the app exits with a non-zero code, the launcher logs the code and
shows an error message with the log path.

### 7. Clean up

After the app exits, the launcher kills the calendar factory, the source
registry, and the D-Bus daemon. The calendar subprocess watches the factory's
D-Bus name, so it exits when the factory dies. The app's normal close path
releases its ECalClients and the window.

## D-Bus service files

`share/dbus-1/services` contains:

- `org.gnome.evolution.dataserver.Sources5.service`
- `org.gnome.evolution.dataserver.Calendar8.service`
- `org.gnome.evolution.dataserver.AddressBook10.service`
- `org.gnome.Calendar.service`
- `org.gtk.GLib.PACRunner.service`

`windows/build-bundle.sh` rewrites the `Exec=` paths to the bundle's absolute
path and appends `.exe` when the executable name lacks it. This matters for
D-Bus activation: the source registry, calendar factory, address-book factory,
and the app's `--gapplication-service` instance can all be activated from the
bundle rather than from the build prefix.

The launcher starts the two critical services itself, so the app does not depend
on activation for the main calendar flow.

## Relocatability

The bundle is designed to be moved as a folder. The launcher computes every
runtime path from its own location (`Application.ExecutablePath`), and the
GdkPixbuf cache is regenerated. The D-Bus service files contain absolute paths
written at build time; if the bundle is moved, the manually started services
still work, but D-Bus activation of the address-book factory or the app service
would use stale paths. Re-run `windows/build-bundle.sh` at the new location or
regenerate the service files if you need activation after moving the folder.

The bundle was tested with the MSYS2 installation temporarily renamed, which
confirms that the app does not need `C:\msys64` at runtime.

## Sharing the bundle

The folder can be zipped and extracted on another Windows machine. The launcher
computes every path from its own location, regenerates the GdkPixbuf cache, and
starts the source registry, calendar factory, and address-book factory directly.
The recipient does not need MSYS2 or WSL.

The D-Bus service files under `share/dbus-1/services` contain absolute paths
written at build time. They are used for optional D-Bus activation; the launcher
starts the critical services itself, so the core calendar works after
relocation. Rebuild the bundle at the new location if activation of the optional
services is required.

The bundle includes a `README.txt` with run instructions, the SmartScreen note,
data locations, limitations, and source/license links. Windows may warn that the
executable is unsigned.

## Logs

The launcher writes one log per component:

```text
%LOCALAPPDATA%\GNOME Calendar\logs\launcher.log
%LOCALAPPDATA%\GNOME Calendar\logs\app.log
%LOCALAPPDATA%\GNOME Calendar\logs\dbus.log
%LOCALAPPDATA%\GNOME Calendar\logs\sources.log
%LOCALAPPDATA%\GNOME Calendar\logs\calendar.log
```

The EDS services also write their own warnings there. The `dbus-launch.exe` line
that can appear in the service logs is from EDS's Windows initialization routine;
it is harmless because the launcher has already provided a session bus.

## Key source

- `windows/launcher/native-launcher.cs` — the complete launcher.
- `windows/build-bundle.sh` — the bundle assembler and service-file rewriter.
- `windows/launcher/build-launcher.ps1` — the `csc.exe` build.
- `WINDOWS.md` — the user-facing build and troubleshooting guide.

## Related pages

- [GTK and the Windows runtime](../architecture/gtk-runtime.md)
- [Evolution Data Server on Windows](../architecture/evolution-data-server.md)
- [Build the native Windows app](windows-native.md)
- [Troubleshooting](../operations/troubleshooting.md)
