---
type: testing
title: Validation
description: What was verified for the native Windows build, how to reproduce the checks, and which areas still need manual or automated coverage.
tags: [testing, validation, windows, bundle, evolution-data-server]
---

# Validation

The Windows port is experimental. This page records what was actually verified,
how to reproduce the checks, and what remains untested. It is intentionally
specific so a future contributor can distinguish "it built" from "it works".

## Verified

### Native build

- Evolution Data Server 3.63.1 configures, builds, and links with MinGW-w64.
  The build includes the calendar factory, source registry, calendar backends,
  address-book backends, and Camel.
- GNOME Calendar 50.0 configures and builds with Meson/Ninja against the native
  EDS, GTK 4.24.1, and libadwaita 1.10.0.
- The app links and starts without a Linux runtime. `ldd` resolves the bundled
  DLLs from the bundle's `bin` and `lib` directories.

### Application startup

- The native launcher starts a private D-Bus session, the source registry, and
  the calendar factory, then starts `gnome-calendar.exe`.
- The main window opens and renders the week view. The month/week/agenda UI,
  header bar, date chooser, and view switcher are visible.
- The app stays alive while the window is open and exits cleanly when the window
  closes. The launcher then stops the services.
- Maximize/restore returns the window to its exact pre-maximize rectangle. This
  was validated with the Win32 maximize/restore path; the window no longer
  drifts to a new position.
- With `window-maximized=true` saved in GSettings, the app still opened
  windowed, then maximize/restore returned to the exact pre-maximize
  rectangle.
- The pointer was placed at the maximized window's restore button; after
  restore it was moved back inside the restored window instead of being left
  far outside.
- Drag-to-restore from the header bar was validated: the restored window
  followed the drag position and the pointer ended inside it.
- Right-header drag was validated: dragging from `(1300,20)` to `(1000,300)`
  restored the window centered at `(616,280)-(1384,930)`, with the pointer
  `(1000,300)` inside it instead of the window being pushed off-screen left.

### Evolution Data Server

- `e_source_registry_new_sync()` succeeds against the bundled source registry.
- The registry enumerates the default sources (including the local/system
  calendar and the birthday calendar).
- `e_cal_client_connect_sync()` connects to the calendar factory for the
  calendar sources.
- `e_cal_client_get_object_list_sync()` returns successfully for the connected
  calendars (empty on a fresh profile).

This was checked with a small EDS test program linked against the same
libedataserver/libecal/GTK stack. The test created the registry, created an
`ECredentialsPrompter`, listed sources, connected to each calendar source, and
queried its object list.

### Persistence and time zones

- Events created in the app are written to
  `%LOCALAPPDATA%\evolution\calendar\system\calendar.ics` and survive an app
  restart.
- A timed event created at 08:00 in the local `India Standard Time` zone was
  stored as `02:30Z` and displayed at 08:00 after a restart. The UTC conversion
  is required because libical does not know the Windows timezone name.
- The source's `Selected` flag persists in the EDS `.source` file. A calendar
  that is unchecked in the sidebar is not displayed, even though its events are
  still stored.

### Bundle portability

- The bundle runs with the MSYS2 installation temporarily renamed. This confirms
  that the app, EDS services, D-Bus daemon, GTK, GSettings schemas, icons,
  GWeather database, and GdkPixbuf loaders all come from the bundle rather than
  from `C:\msys64`.
- The launcher regenerates the GdkPixbuf loader cache at startup, so the cache
  paths follow the bundle location.
- The Desktop shortcut (`GNOME Calendar.lnk`) launches the native launcher and
  the app.

### Build environment fixes

- The `blueprint-compiler` shebang fix is applied by the setup script.
- The UUID shim satisfies EDS's `uuid>=2.0` dependency.
- The GeoClue stub satisfies the app's `libgeoclue-2.0` dependency.
- `libsystre` supplies the POSIX regex symbols used by Camel.
- `ws2_32` supplies the winsock symbols used by Camel's message port and network
  utilities.

## Not yet verified

- **Event editor interaction.** The template types are registered and the event
  editor opens, but creating, editing, and deleting an event through the UI has
  not been automated. This is the highest-value manual test for a release.
- **Recurring events and reminders.** The UI paths exist, but alarm delivery and
  recurrence edge cases have not been exercised on Windows.
- **CalDAV/WebDAV end to end.** The backends are built and the GIO TLS modules
  are bundled, but a live remote calendar has not been tested in this
  environment.
- **Weather.** The GeoClue stub intentionally provides no location, so weather
  data is not expected to appear.
- **GNOME Online Accounts.** GOA and the WebKit OAuth prompters are not bundled.
- **Accessibility and input methods.** Native Win32 behavior is expected, but
  screen readers, IME composition, and complex DPI transitions have not been
  tested.
- **Long-running sessions.** Multi-day operation, sleep/resume, and clock changes
  have not been stress-tested.

## Reproducing the validation

1. Build the bundle with `windows/build-eds.sh`,
   `windows/build-gnome-calendar.sh`, and `windows/build-bundle.sh`.
2. Start the app through the launcher:

   ```text
   C:\Users\<you>\GNOME-Calendar-Native\GNOME Calendar.exe
   ```

3. Confirm the window renders and the log contains no fatal errors:

   ```text
   %LOCALAPPDATA%\GNOME Calendar\logs\app.log
   ```

4. Confirm the EDS services are alive while the window is open. The process list
   should contain `dbus-daemon.exe`, `evolution-source-registry.exe`,
   `evolution-calendar-factory.exe`, and `gnome-calendar.exe`.
5. Close the window and confirm the launcher stops the services.
6. To test relocatability, move the bundle folder, update the shortcut, and
   launch again. The launcher should regenerate the GdkPixbuf cache and start
   normally.

## Acceptance criteria for a "works on my machine" build

- The app window opens within a few seconds on a warm start.
- The week view shows the current month and the correct first weekday fallback.
- The calendar-management UI lists the local/system calendar.
- The event editor opens without GtkBuilder type errors.
- The logs contain no `Gtk-CRITICAL` template errors.
- Closing the window leaves no `gnome-calendar.exe`, `evolution-*-factory.exe`,
  or `dbus-daemon.exe` processes behind.

## Key source

- `windows/launcher/native-launcher.cs` — the process sequence used by the
  validation.
- `windows/build-bundle.sh` — the bundle that was tested with MSYS2 hidden.
- `WINDOWS.md` — the user-facing validation and troubleshooting notes.

## Related pages

- [Build the native Windows app](../build/windows-native.md)
- [Bundle layout and startup](../build/bundle-layout.md)
- [Troubleshooting](../operations/troubleshooting.md)
- [Native vs WSL](../decisions/native-vs-wsl.md)
