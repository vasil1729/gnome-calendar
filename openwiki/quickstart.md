---
type: quickstart
title: Native Windows GNOME Calendar — documentation map
description: Entry point for the Windows-native GNOME Calendar fork, with routes into architecture, build, runtime, validation, and troubleshooting documentation.
tags: [quickstart, windows, gnome-calendar, openwiki]
---

# Native Windows GNOME Calendar

This wiki documents the `windows-native-port` branch of GNOME Calendar. The
branch takes GNOME Calendar 50.0 and Evolution Data Server 3.63 and turns them
into a self-contained, native 64-bit Windows application. There is no WSL
distribution, no Linux VM, and no X11/Wayland translation layer at runtime.

The port is intentionally narrow: it keeps the GNOME Calendar application and
its Evolution Data Server backend, and replaces only the pieces that do not
exist on Windows (GeoClue, the desktop portal, logind, and the POSIX-only build
assumptions). The resulting bundle is a normal Windows folder with an `.exe`,
DLLs, schemas, icons, and data files.

## Start here

| Goal | Read |
| --- | --- |
| Build the `.exe` from scratch | [Build the native Windows app](build/windows-native.md) |
| Understand the runtime folder and launcher | [Bundle layout and startup](build/bundle-layout.md) |
| Understand the application architecture | [Application architecture](architecture/overview.md) |
| Understand the calendar backend | [Evolution Data Server on Windows](architecture/evolution-data-server.md) |
| Understand GTK, GSettings, icons, and DLLs | [GTK and the Windows runtime](architecture/gtk-runtime.md) |
| See every Windows-specific source change | [Windows patch catalog](architecture/windows-patches.md) |
| Decide between native and WSL | [Native vs WSL](decisions/native-vs-wsl.md) |
| Fix a build or launch failure | [Troubleshooting](operations/troubleshooting.md) |
| See what was tested and what is missing | [Validation](testing/validation.md) |

## Repository map

- `src/core/` — `GcalContext`, `GcalManager`, the clock, the timeline, and the
  calendar model.
- `src/gui/` — the Adwaita application window, month/week/agenda views, the
  event editor, and the date chooser widgets.
- `src/utils/` — locale, date, color, and EDS helper functions.
- `src/weather/` — the optional GWeather-backed weather service.
- `windows/` — the Windows build scripts, GeoClue stub, UUID shim, native
  launcher, screenshot, and the Evolution Data Server patch.
- `WINDOWS.md` — the human-facing build and packaging guide.
- `openwiki/` — this generated-style documentation set.

## How the Windows branch differs from upstream

Upstream GNOME Calendar assumes a Linux desktop: glibc `langinfo`, POSIX
`locale_t`, a Unix `stdout` channel for logging, and a linker that keeps every
GObject type referenced from a GtkBuilder template. The branch makes those
assumptions explicit and portable:

- `src/utils/gcal-utils.c` uses `strftime()` for day and month names and drops
  the glibc-only `ABDAY_*`/`MON_*` tables.
- `src/gui/common/gcal-date-chooser.c` drops `newlocale()`/`uselocale()`.
- `src/core/gcal-log.c` does not install the Unix log channel on Windows.
- `src/gui/event-editor/gcal-schedule-section.c` uses `g_type_ensure()` so
  template-only widget types survive the Windows static-library link.
- Evolution Data Server receives the Windows build fixes documented in
  [Evolution Data Server on Windows](architecture/evolution-data-server.md).

The `windows/` directory contains the reproducibility layer: scripts that
install MSYS2 dependencies, build EDS, build the app, assemble the bundle, and
compile the native launcher.

## Status

The branch builds and runs on Windows 11 (26200) with MSYS2 UCRT64. The main
window renders the month/week/agenda UI and connects to the local Evolution Data
Server sources. Weather location, GNOME Online Accounts, the desktop portal, and
logind integration are deliberately out of scope; see
[Known limitations](../WINDOWS.md#known-limitations).

## The story

A narrative version of this work, including the native-vs-WSL comparison and
why a lightweight local-first calendar is worth the effort:

<https://vasil1729.github.io/blog/native-gnome-calendar-on-windows/>

## Maintaining this wiki

The pages use OpenWiki's OKF frontmatter (`type`, `title`, `description`, and
`tags`). With an OpenWiki provider configured, run `openwiki code --update` from
the repository root to let OpenWiki reconcile these pages with the current
source. Without a provider key, the pages are still readable as normal Markdown
and can be edited by hand.
