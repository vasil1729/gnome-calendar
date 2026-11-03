---
type: architecture
title: Evolution Data Server on Windows
description: The EDS services, libraries, module directories, D-Bus contracts, and Windows fixes that make the calendar backend work in the native bundle.
tags: [evolution-data-server, eds, dbus, caldav, windows]
---

# Evolution Data Server on Windows

GNOME Calendar does not store events itself. It is a client of Evolution Data
Server (EDS), a family of libraries and D-Bus services that manage calendars,
address books, and accounts. The Windows port keeps EDS and patches the pieces
that had drifted away from MinGW support.

## Services

Three long-lived EDS processes are relevant to the calendar:

| Process | D-Bus name | Responsibility |
| --- | --- | --- |
| `evolution-source-registry.exe` | `org.gnome.evolution.dataserver.Sources5` | Owns the `ESourceRegistry`: configured calendars, accounts, and source metadata. |
| `evolution-calendar-factory.exe` | `org.gnome.evolution.dataserver.Calendar8` | Owns `ECalClient` connections and loads calendar backend modules. |
| `evolution-addressbook-factory.exe` | `org.gnome.evolution.dataserver.AddressBook10` | Owns address-book clients; used by the birthday calendar and contact-backed sources. |

The calendar factory can spawn `evolution-calendar-factory-subprocess.exe` for a
backend, and the address-book factory has an equivalent subprocess. The
subprocess watches the factory's D-Bus name and exits if the factory dies.

The native launcher starts the source registry and the calendar factory
directly. The address-book factory is available for D-Bus activation through the
patched service files, so the birthday calendar can work without the launcher
having to start every possible factory eagerly.

## Libraries

The application links against:

- `libedataserver-1.2` — sources, credentials, D-Bus utilities, and the
  `ESourceRegistry` client.
- `libecal-2.0` — the calendar client and component API.
- `libedataserverui4-1.0` — the GTK4 credentials prompter and trust prompt used
  by `GcalManager`.
- `libedata-cal-2.0`, `libedata-book-1.2`, and `libebackend-1.2` — the factory
  and backend side used by the EDS executables.
- `libcamel-1.2` — pulled in by the UI/credential layer and the calendar
  factory; the Windows branch patches Camel enough to build, not to provide a
  full mail client.

The EDS libraries are installed into `/ucrt64/lib` and copied into the bundle's
`bin` directory by `windows/build-bundle.sh`.

## Module directories and environment overrides

EDS uses compiled-in module directories. On a normal Linux install those point
at `/usr/lib/evolution-data-server/...`; on the Windows build they point at
`/ucrt64/lib/evolution-data-server/...`. The launcher overrides them so the
bundle can live anywhere:

| Environment variable | Bundle path |
| --- | --- |
| `EDS_REGISTRY_MODULES` | `lib/evolution-data-server/registry-modules` |
| `EDS_CALENDAR_MODULES` | `lib/evolution-data-server/calendar-backends` |
| `EDS_ADDRESS_BOOK_MODULES` | `lib/evolution-data-server/addressbook-backends` |
| `EDS_SUBPROCESS_CAL_PATH` | `libexec/evolution-calendar-factory-subprocess.exe` |
| `EDS_SUBPROCESS_BOOK_PATH` | `libexec/evolution-addressbook-factory-subprocess.exe` |

The overrides are read by `e_source_registry_server_class_init()`,
`e_data_cal_factory_class_init()`, and `e_data_book_factory_class_init()`. If an
override is not a directory, EDS falls back to the compiled-in path.

The bundle also contains the registry modules, calendar backends, address-book
backends, and Camel providers under `lib/evolution-data-server/`. The calendar
backends include the local `file` backend, CalDAV/WebDAV, HTTP/webcal, weather,
and the other modules built by EDS.

## D-Bus startup

The native launcher creates a private session bus with `dbus-daemon.exe` on an
ephemeral loopback TCP port. It sets `DBUS_SESSION_BUS_ADDRESS` in its own
environment before starting the EDS services, so the services and the app all
use the same bus.

The service files under `share/dbus-1/services` are rewritten by
`windows/build-bundle.sh` to point at the bundle's `libexec` executables and to
append `.exe` where needed. The launcher starts the source registry and calendar
factory eagerly; D-Bus activation covers the address-book factory and the
GNOME Calendar `--gapplication-service` instance if they are needed.

## Windows fixes in the EDS branch

The companion EDS branch
[`vasil1729/evolution-data-server:windows-native-port`](https://github.com/vasil1729/evolution-data-server/tree/windows-native-port)
contains the build fixes. The full patch is mirrored at
`windows/patches/evolution-data-server-windows.patch`. The changes fall into
these groups:

### File metadata

GLib's `g_stat()` uses `GStatBuf` (`struct _stat64`) on Windows, while the C
runtime's `fstat()` uses `struct stat`. Code that mixed the two wrote 64-bit
metadata into a smaller buffer. The patch uses `GStatBuf` for `g_stat()` and
keeps `struct stat` for `fstat()`; the affected files are in `src/camel/`,
`src/calendar/libecal/`, `src/addressbook/libedata-book/`, and
`src/camel/providers/local/`.

### Networking and winsock

`src/camel/camel-msgport.c` uses sockets for its message port. The patch
includes `winsock2.h` before NSPR and links Camel with `ws2_32`. The CMake
option is passed by `windows/build-eds.sh` as `-DSOCKET_LDFLAGS=ws2_32`.

### Regular expressions

Camel's search code uses POSIX `regcomp()`/`regexec()`/`regfree()`. MinGW does
not provide those symbols directly, so the build links MSYS2's `libsystre`
(`-DREGEX_LDFLAGS=systre`).

### Time functions

`localtime_r()` is missing on Windows. The patch adds a fallback based on
`localtime()` in `e-reminder-watcher.c`, `e-cal-backend-intervaltree.c`, and the
Camel search utilities. `e-time-utils.c` already had a Windows fallback.

### Build system

- `CMakeLists.txt` uses a forward-slash build path for the iconv detection
  program, avoiding the trailing-backslash escaping problem.
- `data/CMakeLists.txt` uses a forward-slash path for the OAuth client ID helper
  output.
- The build uses `-DCMAKE_POLICY_DEFAULT_CMP0219=NEW` so CMake preserves the
  path arguments correctly.

### UUID

EDS requires `uuid>=2.0`. Windows has UUID generation in `rpcrt4.dll`, so the
build installs a tiny `libuuid` shim from `windows/uuid-shim/` that provides
`uuid_generate_random()` and `uuid_unparse_lower()`. The shim is only used for
EDS's Microsoft OAuth helper and is not on the critical calendar path.

### Camel and library portability

The remaining fixes add missing GLib includes, use `guint` instead of BSD
`uint`, guard Windows-only code, and keep Camel's GPG/S-MIME paths compiling
even though the native calendar bundle does not use mail or S/MIME.

## Runtime data and settings

- Calendar sources are stored under the user's Windows profile. EDS uses
  GLib's user data/config directories, which map to `%APPDATA%` and
  `%LOCALAPPDATA%` on Windows.
- GSettings schemas, including the EDS and GNOME Calendar schemas, are loaded
  from the bundle's `share/glib-2.0/schemas` directory through
  `GSETTINGS_SCHEMA_DIR`.
- The local calendar and manual CalDAV/WebDAV sources are the supported data
  paths. Google/Outlook OAuth setup depends on GNOME Online Accounts and WebKit,
  which are outside this port.

## Key source

- `src/libebackend/e-source-registry-server.c` — source registry service and
  `EDS_REGISTRY_MODULES`.
- `src/calendar/libedata-cal/e-data-cal-factory.c` — calendar factory and
  `EDS_CALENDAR_MODULES`/`EDS_SUBPROCESS_CAL_PATH`.
- `src/addressbook/libedata-book/e-data-book-factory.c` — address-book factory
  and the equivalent overrides.
- `src/calendar/libecal/` — the calendar client used by the app.
- `windows/patches/evolution-data-server-windows.patch` — the complete Windows
  patch set.
- `windows/build-eds.sh` — the reproducible EDS build.
- EDS `WINDOWS.md` — the backend-side summary.

## Related pages

- [Application architecture](overview.md)
- [Windows patch catalog](windows-patches.md)
- [Bundle layout and startup](../build/bundle-layout.md)
- [Troubleshooting](../operations/troubleshooting.md)
