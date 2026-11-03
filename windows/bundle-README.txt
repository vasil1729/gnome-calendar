GNOME Calendar for Windows (native build)
==========================================

How to run
----------
1. Extract this folder anywhere, for example:
       C:\Apps\GNOME-Calendar-Native
2. Double-click "GNOME Calendar.exe".
3. If Windows SmartScreen shows a warning, choose "More info" and then
   "Run anyway". The executable is not code-signed.

This is a portable folder. It does not need WSL, MSYS2, or an installer.
The launcher starts a private D-Bus session and the Evolution Data Server
services, then opens the calendar window. The folder can be moved or
renamed; the launcher regenerates its runtime cache from its own location.

Data and settings
-----------------
Calendars are stored in:
    %LOCALAPPDATA%\evolution
Settings are stored by GSettings in the Windows registry.
Logs are written to:
    %LOCALAPPDATA%\GNOME Calendar\logs

Known limitations
-----------------
- Weather location is not available. The GeoClue location provider is a
  stub, so the weather service has no automatic location.
- GNOME Online Accounts (Google/Outlook OAuth) is not bundled. Add remote
  calendars manually with CalDAV/WebDAV through the calendar-management UI.
- The desktop portal and logind are Linux desktop services. The app falls
  back to defaults and logs harmless warnings.
- The build is x86_64 Windows 10/11 only.

Source and license
------------------
GNOME Calendar is licensed under GPL-3.0-or-later. Evolution Data Server is
licensed under LGPL-2.1-or-later (with some GPL parts). The patched sources
and build instructions are available at:

    https://github.com/vasil1729/gnome-calendar/tree/windows-native-port
    https://github.com/vasil1729/evolution-data-server/tree/windows-native-port
    https://github.com/vasil1729/gnome-calendar/blob/windows-native-port/WINDOWS.md

If you redistribute this folder, keep this file and the COPYING file with it,
and make the corresponding source available.
