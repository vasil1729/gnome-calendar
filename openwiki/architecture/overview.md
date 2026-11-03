---
type: architecture
title: Application architecture
description: How GcalApplication, GcalContext, GcalManager, Evolution Data Server clients, and the Adwaita views fit together in the native Windows build.
tags: [architecture, gcalcontext, gcalmanager, gtk4, evolution-data-server]
---

# Application architecture

GNOME Calendar is a GTK4/libadwaita application whose data layer is Evolution
Data Server (EDS). The Windows port keeps that architecture; only the platform
integration points change. This page describes the object graph and the main
data flow so the Windows-specific changes in the rest of the wiki have context.

## Runtime entrypoint

`main()` in `src/main.c` creates a `GcalApplication` (an `AdwApplication`) and
runs it. The application's startup path is in `src/gui/gcal-application.c`:

1. Load the application resources and the GSettings schema.
2. Create a `GcalContext` with `gcal_context_new()`.
3. Call `gcal_context_startup()`.
4. Build the `GcalWindow` and connect the context to the window.

`GcalContext` is the central service locator. It owns:

- `GcalClock` — the wall clock and timer source that drives the UI.
- `GcalManager` — the calendar list, EDS source registry, and calendar clients.
- `GcalSearchEngine` — full-text search over events.
- `GcalWeatherService` — optional GWeather-backed forecasts.
- `GcalTimeZoneMonitor` — the local timezone and timezone-change notifications.
- `GSettings` — the `org.gnome.calendar` preferences.
- `GDBusProxy` — the `org.freedesktop.portal.Settings` proxy used for the
  desktop clock format and first weekday.

On Linux the portal and logind services are present. On Windows they are not,
so the context logs a warning and falls back to defaults. Those warnings are
expected and do not stop the application.

## Object graph

```text
GcalApplication
└── GcalContext
    ├── GcalClock
    ├── GSettings (org.gnome.calendar)
    ├── GcalTimeZoneMonitor
    ├── GcalWeatherService
    │   └── GWeatherInfo (optional)
    ├── GcalManager
    │   ├── ESourceRegistry  (D-Bus: org.gnome.evolution.dataserver.Sources5)
    │   ├── ECredentialsPrompter (libedataserverui4)
    │   ├── GcalCalendar[]  (one per calendar source)
    │   │   ├── ECalClient  (D-Bus: org.gnome.evolution.dataserver.Calendar8)
    │   │   └── GcalCalendarMonitor
    │   └── GcalTimeline
    └── GcalSearchEngine
```

The exact ownership is defined in `src/core/gcal-context.c` (the context fields
and `gcal_context_init`/`gcal_context_constructed`) and
`src/core/gcal-manager.c` (`gcal_manager_startup` and `load_source`).

## Calendar data flow

1. `GcalManager` creates an `ESourceRegistry` with
   `e_source_registry_new_sync()`. This is the client side of the EDS source
   registry service.
2. `e_source_registry_list_sources()` and
   `e_source_registry_list_enabled()` enumerate the configured sources. A source
   is a local calendar, a CalDAV/WebDAV calendar, a birthday calendar, or a
   collection source that groups several calendars.
3. For every enabled calendar source, `load_source()` creates a `GcalCalendar`.
   `GcalCalendar` implements `GInitable` and calls
   `e_cal_client_connect_sync()` with `E_CAL_CLIENT_SOURCE_TYPE_EVENTS`.
4. The `ECalClient` talks to the EDS calendar factory over D-Bus. The factory
   loads the appropriate backend module (`file`, `caldav`, `http`, `weather`,
   and so on) and exposes the calendar objects.
5. `GcalCalendarMonitor` subscribes to the client's view and turns the returned
   `ICalComponent` objects into `GcalEvent` objects.
6. `GcalTimeline` indexes events by date. The month, week, agenda, and schedule
   views subscribe to the timeline and render the events.
7. The event editor writes back through `ECalClient` methods such as
   `e_cal_client_create_object()` and `e_cal_client_modify_object()`.

The Windows port does not change this flow. The only difference is where the
D-Bus bus and the EDS services come from: the native launcher starts a private
session bus and the EDS executables, then passes the bus address to the app.

## UI composition

- `src/gui/gcal-window.c` builds the main Adwaita window. It contains the
  header bar, the sidebar/calendar list, the view switcher, and the month/week/
  agenda views.
- `src/gui/views/gcal-month-view.c`, `gcal-week-view.c`, and `gcal-agenda-view.c`
  render the calendar.
- `src/gui/event-editor/` contains the event editor dialog and its sections:
  summary, schedule, reminders, notes, attendees, and recurrence.
- `src/gui/common/` contains shared widgets such as the date chooser, calendar
  combo row, and multi-choice widgets.

Several of these widgets are referenced only from GtkBuilder `.ui`/Blueprint
templates. On Linux the linker keeps their GObject types alive because the
shared library contains every object. On Windows the app's private library is
static, so the linker can drop an object that is referenced only by a template.
The Windows branch adds `g_type_ensure()` calls for the affected template-only
types; see [Windows patch catalog](windows-patches.md).

## Lifecycle and shutdown

`gcal_context_startup()` reads the portal settings, starts the manager, and
creates the search engine. `gcal_manager_startup()` builds the source registry,
the credentials prompter, the client table, the timeline, and the initial
calendar clients. When the window closes, `gcal_context_finalize()` stops the
weather service and releases the manager, clock, settings, and monitor objects.

In the native bundle, the launcher waits for the `gnome-calendar.exe` process to
exit and then kills the EDS factories and the private D-Bus daemon. The EDS
subprocess watches the factory's D-Bus name and exits when the factory goes
away, so there is no orphaned calendar backend.

## Key source

- `src/main.c` — application entrypoint.
- `src/gui/gcal-application.c` — application startup and window creation.
- `src/core/gcal-context.c` — context services and startup/finalize.
- `src/core/gcal-manager.c` — EDS source registry, clients, and timeline.
- `src/core/gcal-calendar.c` — `ECalClient` connection and calendar metadata.
- `src/core/gcal-calendar-monitor.c` — ECalClient view subscription.
- `src/core/gcal-timeline.c` — event indexing by date.
- `src/gui/gcal-window.c` — main window and views.
- `windows/launcher/native-launcher.cs` — Windows process and D-Bus startup.

## Related pages

- [Evolution Data Server on Windows](evolution-data-server.md)
- [GTK and the Windows runtime](gtk-runtime.md)
- [Windows patch catalog](windows-patches.md)
- [Native vs WSL](../decisions/native-vs-wsl.md)
