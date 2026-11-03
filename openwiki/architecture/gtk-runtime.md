---
type: architecture
title: GTK and the Windows runtime
description: How GTK4, libadwaita, GSettings, icons, GdkPixbuf loaders, GIO modules, GWeather, and the native launcher cooperate in the Windows bundle.
tags: [gtk4, libadwaita, gsettings, gdkpixbuf, gio, gweather, windows]
---

# GTK and the Windows runtime

The Windows bundle is more than `gnome-calendar.exe`. GTK4 and libadwaita need
loadable modules, schemas, icon themes, fonts, and data files. Evolution Data
Server needs its own module directories and a D-Bus bus. The native launcher
sets the environment and starts the services; this page explains the runtime
pieces and why each one exists.

## GTK4 and libadwaita

GNOME Calendar 50.0 uses GTK4 and libadwaita. On Windows, GTK4 uses its Win32
backend (`GDK_BACKEND=win32`), which gives the app a normal HWND-backed window
with native DPI, input, clipboard, and taskbar behavior. libadwaita supplies
the Adwaita widgets and the light/dark styles.

The bundle includes the GTK4 and libadwaita DLLs in `bin`, the Adwaita and
hicolor icon themes in `share/icons`, and the GTK data in `share/gtk-4.0`. The
launcher sets `XDG_DATA_DIRS` to the bundle's `share` directory so GTK finds
the themes, icons, and translations.

## GSettings

The application and EDS use GSettings. On Windows, GLib's GSettings registry
backend stores values in the Windows registry. The schemas themselves are
compiled into `share/glib-2.0/schemas/gschemas.compiled` by the build. The
launcher sets:

```text
GSETTINGS_SCHEMA_DIR=<bundle>\share\glib-2.0\schemas
```

The bundle contains the GNOME Calendar schema, the EDS schemas, and the
`gsettings-desktop-schemas` package. The last one provides the desktop interface
keys the app uses for the clock format and first weekday.

## Icons and GdkPixbuf

GTK renders icons through the icon theme and loads raster images through
GdkPixbuf. GdkPixbuf uses loadable modules for PNG, JPEG, SVG, and other formats.
The bundle includes:

- `share/icons/Adwaita/` — the standard symbolic and full-color icons.
- `share/icons/hicolor/` — the GNOME Calendar application icon and related
  assets.
- `lib/gdk-pixbuf-2.0/2.10.0/loaders/` — the image loader DLLs.
- `bin/gdk-pixbuf-query-loaders.exe` — the tool that generates the loader cache.

`windows/launcher/native-launcher.cs` runs `gdk-pixbuf-query-loaders.exe` at
startup and writes `lib/gdk-pixbuf-2.0/2.10.0/loaders.cache` using the current
absolute bundle path. This is why the bundle can be moved: the cache is
regenerated instead of relying on a path from the build machine. The launcher
then sets:

```text
GDK_PIXBUF_MODULEDIR=<bundle>\lib\gdk-pixbuf-2.0\2.10.0\loaders
GDK_PIXBUF_MODULE_FILE=<bundle>\lib\gdk-pixbuf-2.0\2.10.0\loaders.cache
```

If the cache regeneration fails, the app still starts with whatever cache is
present; the failure is written to the launcher log.

## GIO modules

GIO loads optional modules for TLS, proxy resolution, and other platform
services. The bundle copies `lib/gio/modules` and the launcher sets:

```text
GIO_EXTRA_MODULES=<bundle>\lib\gio\modules
```

This matters for HTTPS CalDAV/WebDAV calendars. Without the module directory,
libsoup may not find a TLS backend and remote calendars can fail even though the
local calendar works.

## GWeather location database

The weather service and the timezone chooser use libgweather. libgweather
normally loads `Locations.bin` from its compiled-in data directory. On the
Windows build that path is `/ucrt64/lib/libgweather-4/Locations.bin`, which is
not valid on a machine without MSYS2. The bundle copies the file to
`lib/libgweather-4/Locations.bin` and the launcher sets:

```text
LIBGWEATHER_LOCATIONS_PATH=<bundle>\lib\libgweather-4\Locations.bin
```

The weather location provider itself is a stub (see
[Native vs WSL](../decisions/native-vs-wsl.md)); the database is still needed by
the timezone chooser and by any code that asks GWeather for the world location
tree.

## Fonts

GTK uses fontconfig on Windows. The bundle copies the MSYS2 fontconfig
configuration to `etc/fonts` and the launcher sets:

```text
FONTCONFIG_PATH=<bundle>\etc\fonts
```

The configuration includes the Windows font directory, so the app uses the
system fonts. The exact font set depends on the machine, which is expected for a
native Windows app.

## Translations

The bundle copies the selected locales from `share/locale`. The default build
script copies `en`, `en_GB`, and `bg`; set the `LOCALES` environment variable to
include more. The app falls back to English when a translation is missing.

## The launcher environment

The launcher (`windows/launcher/native-launcher.cs`) sets the complete runtime
environment before it starts any child process:

```text
PATH=<bundle>\bin;<bundle>\lib;%PATH%
XDG_DATA_DIRS=<bundle>\share
GSETTINGS_SCHEMA_DIR=<bundle>\share\glib-2.0\schemas
FONTCONFIG_PATH=<bundle>\etc\fonts
LIBGWEATHER_LOCATIONS_PATH=<bundle>\lib\libgweather-4\Locations.bin
GIO_EXTRA_MODULES=<bundle>\lib\gio\modules
GDK_PIXBUF_MODULEDIR=<bundle>\lib\gdk-pixbuf-2.0\2.10.0\loaders
GDK_PIXBUF_MODULE_FILE=<bundle>\lib\gdk-pixbuf-2.0\2.10.0\loaders.cache
EDS_REGISTRY_MODULES=<bundle>\lib\evolution-data-server\registry-modules
EDS_CALENDAR_MODULES=<bundle>\lib\evolution-data-server\calendar-backends
EDS_ADDRESS_BOOK_MODULES=<bundle>\lib\evolution-data-server\addressbook-backends
EDS_SUBPROCESS_CAL_PATH=<bundle>\libexec\evolution-calendar-factory-subprocess.exe
EDS_SUBPROCESS_BOOK_PATH=<bundle>\libexec\evolution-addressbook-factory-subprocess.exe
GDK_BACKEND=win32
```

The launcher also creates the private D-Bus session and sets
`DBUS_SESSION_BUS_ADDRESS` before starting the EDS services. See
[Bundle layout and startup](../build/bundle-layout.md) for the exact sequence.

## Why the runtime is bundled

A Windows app cannot assume that GTK, GLib, Adwaita, GWeather, or EDS are
installed system-wide. The bundle makes the app independent of MSYS2 and of any
other package manager. The trade-off is size: the bundle is roughly 180 MB with
three locales. Most of that is the GTK/GLib/ICU/NSS stack and the Adwaita icon
theme. The build script lets you choose the locales and the bundle path.

## Key source

- `windows/launcher/native-launcher.cs` — environment, D-Bus, EDS, cache
  regeneration, and app lifecycle.
- `windows/build-bundle.sh` — copies the runtime and collects DLLs.
- `windows/launcher/build-launcher.ps1` — compiles the native launcher.
- `WINDOWS.md` — the user-facing runtime and troubleshooting guide.

## Related pages

- [Bundle layout and startup](../build/bundle-layout.md)
- [Application architecture](overview.md)
- [Native vs WSL](../decisions/native-vs-wsl.md)
- [Troubleshooting](../operations/troubleshooting.md)
