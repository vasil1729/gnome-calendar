---
type: architecture
title: Windows patch catalog
description: A file-by-file catalog of the GNOME Calendar and Evolution Data Server changes that make the native Windows build possible.
tags: [patches, windows, mingw, evolution-data-server, gtk]
---

# Windows patch catalog

This page is the map of the Windows-specific changes. It is useful for review,
for rebasing onto a newer GNOME Calendar release, and for understanding why a
build error appears when a patch is missing.

## GNOME Calendar changes

| File | Problem | Fix |
| --- | --- | --- |
| `src/core/gcal-log.c` | `gcal_log_init()` installs a `GIOChannel` on `STDOUT_FILENO`. A Win32 GUI process has no reliable Unix-style stdout, and the handler can recurse while reporting its own failure. | Do not install the custom channel/handler on `G_OS_WIN32`; use GLib's default log handler. |
| `src/utils/gcal-utils.c` | Day/month names use glibc's `nl_langinfo()` and the `ABDAY_*`/`MON_*` tables. `ALTMON_*` is glibc-specific. | Use `strftime("%a")` and `strftime("%B")` with fixed dates; return static buffers to preserve the existing transfer-full API behavior. Remove the tables. |
| `src/utils/gcal-utils.c` | `gcal_util_translate_time_string()` uses POSIX `locale_t`, `newlocale()`, and `uselocale()`. | Remove the temporary-locale block; use `g_dpgettext()` with the current locale. |
| `src/gui/common/gcal-date-chooser.c` | `calendar_get_weekday_name()` uses `locale_t`, `newlocale()`, and `uselocale()` for the one-letter grid abbreviations. | Remove the POSIX locale block; the `C_()` translations work with the current locale. |
| `src/gui/event-editor/gcal-attendee-summary-row.c` | Uses the BSD `uint` type. | Use `guint`. |
| `src/gui/event-editor/gcal-schedule-section.c` | `GcalScheduleSection`'s template references `GcalDateChooserRow` and `GcalDateSelector`. The Windows static-library link can drop objects referenced only by a template, so the GTypes are not registered. | Add `g_type_ensure(GCAL_TYPE_DATE_CHOOSER_ROW)` and `g_type_ensure(GCAL_TYPE_DATE_SELECTOR)` in the class init before the template is built. |
| `src/core/gcal-event.c`, `src/utils/gcal-utils.c` | Windows reports the local timezone as a name such as `India Standard Time`, which is not in libical's built-in IANA database. The fallback stored the local wall time as UTC, shifting new events by the local offset. | When libical cannot resolve the zone, convert the `GDateTime` to UTC and store the event with the UTC timezone. |
| `src/gui/gcal-window.c` | GTK's Win32 backend does not restore the pre-maximize window geometry; the window can move to a new position when maximizing and restoring. | Track the normal window rectangle with `GetWindowRect()` while unmaximized and restore it with `SetWindowPos()` after unmaximizing. Skip minimized windows with `IsIconic()`, ignore the saved maximized state on Windows so the app always starts windowed, move the pointer back over the restored window if it would otherwise be left outside, skip the geometry override while the mouse is captured or the left button is held so drag-to-restore follows the pointer, and center the restored window on the pointer as soon as it is restored (with a short retry while the window settles) so the drag follows the pointer directly. |
| `src/gui/common/*.c`, `src/gui/event-editor/*.c` | Several files include `<langinfo.h>` unconditionally. | Guard the include with `#ifndef G_OS_WIN32`. |
| `src/meson.build` | Meson builds the executable as a console subsystem binary on Windows, which opens a terminal window. | Pass `win_subsystem: 'windows'` to the executable target so it is a GUI subsystem binary. |
| `windows/launcher/native-launcher.cs` | The launcher starts the app with `CreateNoWindow = false`. | Set `CreateNoWindow = true`; the app is also built as a GUI subsystem binary, so the shortcut opens only the calendar window. |
| `README.md` | The upstream README has no Windows information. | Add a Windows native build section linking to `WINDOWS.md` and the OpenWiki. |
| `WINDOWS.md` | No user-facing Windows build/packaging guide. | Add the full guide: rationale, changes, prerequisites, scripts, bundle layout, troubleshooting, licensing. |
| `windows/` | No reproducible Windows build assets. | Add setup/build/bundle scripts, the GeoClue stub, the UUID shim, the native launcher, the EDS patch, and a screenshot. |

### Why `g_type_ensure()` is needed

GNOME Calendar builds its private code as a static library
(`src/libgcal-private.a`). On Linux, the linker keeps every object because the
shared library contains all of them. On Windows, the linker only pulls in
objects that satisfy a referenced symbol. A widget class referenced solely by a
GtkBuilder/Blueprint template has no C symbol reference, so its object can be
dropped and its `GType` never registered. The template then fails with:

```text
Gtk-CRITICAL: Error building template class 'GcalScheduleSection':
Invalid object type 'GcalDateChooserRow'
```

The `g_type_ensure()` calls force the linker to include the objects and register
the types before the template is instantiated. If a future template adds another
type, add a matching `g_type_ensure()` in the same class init.

## Evolution Data Server changes

The full patch is `windows/patches/evolution-data-server-windows.patch` (about
750 lines, 30 files). The changes fall into these groups.

### File metadata

| Area | Files | Fix |
| --- | --- | --- |
| Camel block/data files | `src/camel/camel-block-file.c`, `camel-data-cache.c`, `camel-lock.c`, `camel-lock-helper.c`, `camel-uid-cache.c` | Use `GStatBuf` for `g_stat()` and keep `struct stat` for `fstat()`. |
| Local providers | `src/camel/providers/local/camel-*-store.c`, `camel-*-summary.c` | Same `GStatBuf` correction for the local mail providers. |
| Calendar/addressbook | `src/calendar/libecal/e-cal-system-timezone.c`, `src/addressbook/libedata-book/e-book-backend-summary.c` | Same `GStatBuf` correction. |

### Networking

| File | Fix |
| --- | --- |
| `src/camel/camel-msgport.c` | Include `winsock2.h` before NSPR; keep the WinSock `closesocket`/`recv`/`send` macros. |
| `src/camel/CMakeLists.txt` | Link `ws2_32` through `SOCKET_LDFLAGS`. |
| `src/camel/camel-net-utils.c` | Use the WinSock host/service APIs and `ws2_32` symbols. |

### Regular expressions

| File | Fix |
| --- | --- |
| `src/camel/camel-search-private.c`, `camel-search-utils.c` | Use the POSIX regex API supplied by `libsystre`; link `systre`. |

### Time functions

| File | Fix |
| --- | --- |
| `src/calendar/libecal/e-reminder-watcher.c` | Add a `localtime_r()` fallback. |
| `src/calendar/libedata-cal/e-cal-backend-intervaltree.c` | Add a `localtime_r()` fallback. |
| `src/camel/camel-search-utils.c` | Add a `localtime_r()` fallback. |
| `src/libedataserver/e-debug-log.c` | Use a `time_t` temporary before `localtime()` to avoid the `timeval.tv_sec` type mismatch. |
| `src/camel/camel-mime-utils.c`, `src/libedataserver/e-data-server-util.c` | Avoid `getgid()`/`getppid()` on Windows. |

### Build system

| File | Fix |
| --- | --- |
| `CMakeLists.txt` | Use a forward-slash build path for the iconv detection program. |
| `data/CMakeLists.txt` | Use a forward-slash path for the OAuth client ID helper output. |
| `src/libedataserver/e-data-server-util.c` | Cast the `GetProcAddress` result through `void *` before assigning to the `SetDllDirectoryA` function pointer. |
| `src/camel/camel-smime-context.c` | Include `<glib.h>` outside the `ENABLE_SMIME` guard so the non-S/MIME build sees `gchar`/`gint`. |

### Camel and library portability

| File | Fix |
| --- | --- |
| `src/camel/camel-iconv.c` | Pass a `const gchar *` temporary to `g_get_charset()`. |
| `src/camel/camel-gpg-context.c` | Cast the initial `GPid` to `(GPid) -1`; declare `local_error` outside the `#ifndef G_OS_WIN32` block. |
| `src/camel/camel-mime-utils.c` | Use `0` for `getgid()`/`getppid()` on Windows. |
| `src/calendar/libecal/e-cal-system-timezone.c` | Use `GStatBuf` for the `g_stat()` comparisons. |
| `src/addressbook/libedata-book/e-book-backend-summary.c` | Use `GStatBuf` for `g_stat()`. |

## Build-environment shims

These are not upstream source changes; they live in the GNOME Calendar
repository's `windows/` directory and are installed by the build scripts.

| Shim | Purpose |
| --- | --- |
| `windows/uuid-shim/` | Provides `uuid_generate_random()`/`uuid_unparse_lower()` backed by Windows `UuidCreate()` and `rpcrt4.dll`, satisfying EDS's `uuid>=2.0` check. |
| `windows/geoclue-stub/` | Provides the small `GClueSimple`/`GClueClient`/`GClueLocation` API used by the weather service. It returns no location, so weather data is not shown, but the app builds and the rest of the calendar works. |
| `windows/setup-msys2.sh` | Installs the UCRT64 packages and fixes the `blueprint-compiler` shebang. |
| `windows/build-eds.sh` | Clones/builds EDS, installs the UUID shim, and passes the Windows CMake options. |
| `windows/build-gnome-calendar.sh` | Builds the GeoClue stub and the app. |
| `windows/build-bundle.sh` | Copies the runtime, collects DLLs, rewrites D-Bus services, and builds the launcher. |
| `windows/launcher/` | The C# native launcher and its build script. |

## Regenerating the EDS patch

The patch was produced from the patched EDS checkout with:

```bash
git -c core.fileMode=false diff > windows/patches/evolution-data-server-windows.patch
```

`core.fileMode=false` is important on Windows-mounted filesystems: without it,
the diff contains mode changes for every file. The patch is applied by
`windows/build-eds.sh` when the checkout is an upstream tree and the patch
applies cleanly. The fork branch already contains the changes.

## Rebase checklist

When rebasing onto a newer GNOME Calendar or EDS release:

1. Re-apply the GNOME Calendar changes listed above. The `g_type_ensure()`
   additions and the locale changes are the most likely to conflict.
2. Rebuild EDS from the new base and re-run the patch generation command.
3. Rebuild the bundle and run the validation checklist.
4. Check for new `Gtk-CRITICAL` template errors. Add `g_type_ensure()` for any
   new template-only widget type.
5. Re-check the GWeather, GeoClue, and portal fallbacks. New GNOME Calendar
   releases may add new Linux-only service dependencies.

## Related pages

- [Application architecture](overview.md)
- [Evolution Data Server on Windows](evolution-data-server.md)
- [GTK and the Windows runtime](gtk-runtime.md)
- [Build the native Windows app](../build/windows-native.md)
