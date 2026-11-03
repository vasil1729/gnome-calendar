---
type: decision
title: Native Windows vs WSL
description: Why the native Windows bundle is a better runtime than launching the Linux app from WSL, including startup, memory, display, integration, and maintenance trade-offs.
tags: [decision, native, wsl, performance, windows]
---

# Native Windows vs WSL

The first version of this port was a Windows `.exe` that started GNOME Calendar
inside an Ubuntu WSL distribution and displayed it through WSLg. It worked, but
it was the wrong shape for a lightweight desktop calendar. This page records why
the native build is the better runtime and where WSL is still the right tool.

## The WSL path

A WSL launcher does roughly this:

1. `wsl.exe` starts or wakes a registered distribution.
2. WSL starts its Linux kernel/VM and the distribution's init.
3. WSLg starts the display server, PulseAudio bridge, and the Wayland/X11
   plumbing.
4. The Linux `gnome-calendar` process starts, connects to the Linux D-Bus
   session, and starts Evolution Data Server.
5. GTK renders through WSLg, which forwards the window to Windows.

That is a lot of machinery for a calendar. The cost is visible in:

- **Cold-start latency.** The first launch after a reboot has to start WSL,
  the distro, WSLg, D-Bus, and EDS. Even a warm launch crosses the Windows/WSL
  boundary and starts the Linux process tree.
- **Memory.** WSL 2 keeps a Linux kernel and a VM alive. The distro's D-Bus,
  EDS factories, and GTK libraries add to that. The native bundle uses the
  same GTK/EDS libraries, but it does not pay for a second kernel or a VM.
- **Disk.** A WSL distribution is a growing virtual disk. The native bundle is
  a folder of files and can be deleted like any other application.
- **Display translation.** WSLg is a compatibility layer. Native GTK4 uses the
  Win32 backend directly, so there is no Wayland/X11-to-Windows hop.
- **Filesystem boundary.** Files under `/mnt/c` cross a VM boundary. A native
  process reads and writes Windows files directly.
- **Desktop integration.** Native windows participate in the taskbar, Alt-Tab,
  snapping, DPI changes, clipboard, drag and drop, input methods, file dialogs,
  and accessibility tools in the normal Windows way. WSLg windows are Linux
  windows projected onto Windows.
- **Maintenance.** WSL needs a distribution, updates, a virtual disk, and the
  WSL feature enabled. The native bundle needs none of that at runtime.

The user-facing effect is simple: the native app feels like a Windows app. It
opens quickly, appears in the taskbar, and does not require a Linux environment
to be running in the background.

## The native path

The native build keeps the application and its backend:

- GNOME Calendar 50.0, GTK4, and libadwaita.
- Evolution Data Server 3.63 for local calendars and CalDAV/WebDAV.
- A private D-Bus session.
- The GWeather location database, GSettings schemas, icons, and translations.

It replaces only the platform-specific pieces:

- The GeoClue location provider becomes an API-compatible stub.
- The desktop portal and logind integrations fall back to defaults.
- The POSIX-only build assumptions in GNOME Calendar and EDS are patched for
  MinGW.
- The launcher starts and stops the private bus and EDS services.

The result is a normal Windows process tree:

```text
GNOME Calendar.exe (launcher)
├── dbus-daemon.exe
├── evolution-source-registry.exe
├── evolution-calendar-factory.exe
└── gnome-calendar.exe
```

No WSL, no Linux kernel, no WSLg, no distribution.

## Comparison

| Property | Native bundle | WSL launcher |
| --- | --- | --- |
| Runtime | Win32 process + GTK Win32 backend | Linux process + WSLg |
| Cold start | Direct process startup | WSL + distro + WSLg + app |
| Memory | GTK/EDS libraries only | GTK/EDS + Linux VM + WSLg |
| Disk | ~180 MB folder | WSL virtual disk + Linux packages |
| Window integration | Native HWND behavior | WSLg projection |
| Filesystem | Direct Windows I/O | `/mnt/c` VM boundary for Windows files |
| Updates | Replace the folder | Update the WSL distro |
| Offline | Yes | Yes, but WSL must still start |
| Maintenance | Build the bundle | Maintain a Linux userland |

The native bundle is larger on disk than a single `.exe`, but it is smaller than
a WSL distribution plus its packages, and it does not keep a VM alive. The
bundle size is mostly the GTK/GLib/ICU/NSS stack and the Adwaita icon theme,
which the WSL path also needs inside the distro.

## What the native path gives up

Honesty matters more than a slogan:

- **Weather location.** GeoClue has no Windows provider. The stub returns no
  location, so weather data is not shown. A future port could use the Windows
  location API, a manual city setting, or a different provider.
- **GNOME Online Accounts.** The OAuth setup for Google/Outlook depends on GOA
  and WebKit. The native bundle does not include them. Manual CalDAV/WebDAV
  calendars work through EDS.
- **Desktop portal.** The app falls back to a default clock format and first
  weekday. Windows users can still change the app's own preferences.
- **logind.** Suspend/resume integration is a Linux desktop feature. The clock
  logs a warning and continues.
- **GNOME Shell integration.** Search-provider and shell-calendar integration
  are Linux desktop features.

For a local-first calendar, those are acceptable trade-offs. The core value —
a fast, lightweight calendar that does not require a browser or a SaaS account
— is preserved.

## When WSL is still the right choice

WSL is the better option when:

- You need the full GNOME desktop integration (portal, GOA, Shell search,
  logind).
- You are developing or testing the Linux build and want the same environment
  as upstream.
- You already keep a WSL distribution running for other Linux tooling and do not
  mind the extra memory.
- You need a feature that depends on a Linux-only service.

The native port is not a replacement for upstream GNOME Calendar. It is a
pragmatic Windows build for people who want the lightweight calendar without a
Linux desktop.

## Decision summary

Use the native bundle when the goal is a fast, native Windows calendar. Use WSL
when the goal is the complete GNOME desktop experience or Linux development. The
two can coexist: the WSL launcher and the native bundle use the same upstream
application and can share calendar data through CalDAV if desired.

## Related pages

- [Application architecture](../architecture/overview.md)
- [GTK and the Windows runtime](../architecture/gtk-runtime.md)
- [Bundle layout and startup](../build/bundle-layout.md)
- [Known limitations](../../WINDOWS.md#known-limitations)
