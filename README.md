<div align="center">
  <img src="data/icons/hicolor/scalable/apps/org.gnome.Calendar.svg" width="128" height="128">

  # GNOME Calendar

  Manage your schedule

  <img width="922" src="https://static.gnome.org/appdata/gnome-50/org.gnome.Calendar/month-view.png">
</div>

## Installation

[![Flatpak](https://flathub.org/api/badge?svg&locale=en)](https://flathub.org/apps/details/org.gnome.Calendar)

## Windows native build

This branch (`windows-native-port`) adds a native Windows port of GNOME
Calendar 50.0. It runs as a normal Win32 application with GTK4's Windows
backend, libadwaita, Evolution Data Server, and a private D-Bus session. It does
not use WSL.

- Full build and packaging guide: [WINDOWS.md](WINDOWS.md)
- OpenWiki architecture and build documentation: [openwiki/quickstart.md](openwiki/quickstart.md)
- Windows branch: <https://github.com/vasil1729/gnome-calendar/tree/windows-native-port>
- Evolution Data Server branch: <https://github.com/vasil1729/evolution-data-server/tree/windows-native-port>
- Prebuilt Windows zip: <https://github.com/vasil1729/gnome-calendar/releases/tag/windows-native-2026-11-03>
- Blog post: <https://vasil1729.github.io/blog/native-gnome-calendar-on-windows/>

Quick start from an MSYS2 UCRT64 shell:

```bash
bash windows/setup-msys2.sh
bash windows/build-eds.sh
bash windows/build-gnome-calendar.sh
bash windows/build-bundle.sh
```

The bundle is written to `C:\Users\<you>\GNOME-Calendar-Native` by default.
Double-click `GNOME Calendar.exe` in that folder to start it.

## Links

- Homepage: [apps.gnome.org/Calendar]
- Report an issue: [gitlab.gnome.org/GNOME/gnome-calendar/issues]
- Donate: [donate.gnome.org]
- Translate: [l10n.gnome.org/module/gnome-calendar]
- Contact: [matrix.to/#/#gnome-calendar:gnome.org]

## Contributing

For information on how to contribute, please check [CONTRIBUTING.md](CONTRIBUTING.md) and [HACKING.md](HACKING.md).


[apps.gnome.org/Calendar]: https://apps.gnome.org/Calendar
[gitlab.gnome.org/GNOME/gnome-calendar/issues]: https://gitlab.gnome.org/GNOME/gnome-calendar/issues/
[donate.gnome.org]: https://donate.gnome.org/
[l10n.gnome.org/module/gnome-calendar]: https://l10n.gnome.org/module/gnome-calendar/
[matrix.to/#/#gnome-calendar:gnome.org]: https://matrix.to/#/#gnome-calendar:gnome.org/
