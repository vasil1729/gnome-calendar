using System;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

class GnomeCalendarNativeLauncher
{
    static readonly object LogLock = new object();
    static string LogDir;

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool FreeConsole();

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern IntPtr GetStdHandle(int nStdHandle);

    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr handle);

    static void DetachStdHandles()
    {
        try
        {
            FreeConsole();
            IntPtr h = GetStdHandle(-11);
            if (h != IntPtr.Zero && h != (IntPtr)(-1))
                CloseHandle(h);
            h = GetStdHandle(-12);
            if (h != IntPtr.Zero && h != (IntPtr)(-1))
                CloseHandle(h);
        }
        catch
        {
        }
    }

    [STAThread]
    static void Main()
    {
        DetachStdHandles();

        bool createdNew;
        using (Mutex mutex = new Mutex(true, "GNOME_Calendar_Native_Launcher", out createdNew))
        {
            if (!createdNew)
                return;

            string baseDir = Path.GetDirectoryName(Application.ExecutablePath);
            string bin = Path.Combine(baseDir, "bin");
            string lib = Path.Combine(baseDir, "lib");
            string libexec = Path.Combine(baseDir, "libexec");
            string share = Path.Combine(baseDir, "share");
            string etc = Path.Combine(baseDir, "etc");

            LogDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "GNOME Calendar", "logs");
            Directory.CreateDirectory(LogDir);

            try
            {
                Environment.SetEnvironmentVariable("PATH",
                    bin + ";" + lib + ";" + Environment.GetEnvironmentVariable("PATH"));
                Environment.SetEnvironmentVariable("XDG_DATA_DIRS", share);
                Environment.SetEnvironmentVariable("GSETTINGS_SCHEMA_DIR",
                    Path.Combine(share, "glib-2.0", "schemas"));
                Environment.SetEnvironmentVariable("FONTCONFIG_PATH", Path.Combine(etc, "fonts"));
                Environment.SetEnvironmentVariable("LIBGWEATHER_LOCATIONS_PATH",
                    Path.Combine(lib, "libgweather-4", "Locations.bin"));
                Environment.SetEnvironmentVariable("GIO_EXTRA_MODULES",
                    Path.Combine(lib, "gio", "modules"));
                Environment.SetEnvironmentVariable("GDK_PIXBUF_MODULEDIR",
                    Path.Combine(lib, "gdk-pixbuf-2.0", "2.10.0", "loaders"));
                Environment.SetEnvironmentVariable("GDK_PIXBUF_MODULE_FILE",
                    Path.Combine(lib, "gdk-pixbuf-2.0", "2.10.0", "loaders.cache"));
                Environment.SetEnvironmentVariable("EDS_REGISTRY_MODULES",
                    Path.Combine(lib, "evolution-data-server", "registry-modules"));
                Environment.SetEnvironmentVariable("EDS_CALENDAR_MODULES",
                    Path.Combine(lib, "evolution-data-server", "calendar-backends"));
                Environment.SetEnvironmentVariable("EDS_SUBPROCESS_CAL_PATH",
                    Path.Combine(libexec, "evolution-calendar-factory-subprocess.exe"));
                Environment.SetEnvironmentVariable("EDS_ADDRESS_BOOK_MODULES",
                    Path.Combine(lib, "evolution-data-server", "addressbook-backends"));
                Environment.SetEnvironmentVariable("EDS_SUBPROCESS_BOOK_PATH",
                    Path.Combine(libexec, "evolution-addressbook-factory-subprocess.exe"));
                Environment.SetEnvironmentVariable("GDK_BACKEND", "win32");

                RegeneratePixbufCache(bin, lib);

                int port;
                TcpListener listener = new TcpListener(IPAddress.Loopback, 0);
                listener.Start();
                port = ((IPEndPoint)listener.LocalEndpoint).Port;
                listener.Stop();

                Process dbus = StartService(
                    Path.Combine(bin, "dbus-daemon.exe"),
                    "--session --address=tcp:host=127.0.0.1,port=" + port + " --print-address=1 --print-pid=1",
                    "dbus", true);

                string address = dbus.StandardOutput.ReadLine();
                if (String.IsNullOrEmpty(address) || !address.StartsWith("tcp:"))
                {
                    ShowError("Could not start the D-Bus session bus.\n\nSee logs in:\n" + LogDir);
                    TryKill(dbus);
                    return;
                }

                Environment.SetEnvironmentVariable("DBUS_SESSION_BUS_ADDRESS", address);

                Process sources = StartService(
                    Path.Combine(libexec, "evolution-source-registry.exe"), "", "sources", false);
                Process addressbook = StartService(
                    Path.Combine(libexec, "evolution-addressbook-factory.exe"), "", "addressbook", false);
                Process calendar = StartService(
                    Path.Combine(libexec, "evolution-calendar-factory.exe"), "", "calendar", false);

                Thread.Sleep(3000);

                Process app = new Process();
                app.StartInfo.FileName = Path.Combine(bin, "gnome-calendar.exe");
                app.StartInfo.WorkingDirectory = baseDir;
                app.StartInfo.UseShellExecute = false;
                app.StartInfo.CreateNoWindow = true;
                app.StartInfo.RedirectStandardOutput = true;
                app.StartInfo.RedirectStandardError = true;
                app.OutputDataReceived += delegate(object s, DataReceivedEventArgs e)
                {
                    if (e.Data != null) Log("app", e.Data);
                };
                app.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e)
                {
                    if (e.Data != null) Log("app", e.Data);
                };
                app.Start();
                app.BeginOutputReadLine();
                app.BeginErrorReadLine();
                app.WaitForExit();

                TryKill(calendar);
                TryKill(addressbook);
                TryKill(sources);
                TryKill(dbus);

                if (app.ExitCode != 0)
                    ShowError("GNOME Calendar exited with code " + app.ExitCode +
                              ".\n\nSee logs in:\n" + LogDir);
            }
            catch (Exception ex)
            {
                ShowError("Could not start GNOME Calendar:\n\n" + ex.Message +
                          "\n\nSee logs in:\n" + LogDir);
            }
        }
    }

    static void RegeneratePixbufCache(string bin, string lib)
    {
        try
        {
            string loadersDir = Path.Combine(lib, "gdk-pixbuf-2.0", "2.10.0", "loaders");
            string cacheFile = Path.Combine(lib, "gdk-pixbuf-2.0", "2.10.0", "loaders.cache");
            string tool = Path.Combine(bin, "gdk-pixbuf-query-loaders.exe");

            if (!File.Exists(tool) || !Directory.Exists(loadersDir))
                return;

            string[] dlls = Directory.GetFiles(loadersDir, "*.dll");
            if (dlls.Length == 0)
                return;

            StringBuilder args = new StringBuilder();
            foreach (string dll in dlls)
            {
                if (args.Length > 0)
                    args.Append(' ');
                args.Append('"').Append(dll).Append('"');
            }

            ProcessStartInfo psi = new ProcessStartInfo();
            psi.FileName = tool;
            psi.Arguments = args.ToString();
            psi.WorkingDirectory = loadersDir;
            psi.UseShellExecute = false;
            psi.CreateNoWindow = true;
            psi.RedirectStandardOutput = true;
            psi.RedirectStandardError = true;

            using (Process p = Process.Start(psi))
            {
                string output = p.StandardOutput.ReadToEnd();
                p.StandardError.ReadToEnd();
                p.WaitForExit();
                if (p.ExitCode == 0 && output.Length > 0)
                    File.WriteAllText(cacheFile, output.Replace("\r\n", "\n"));
            }
        }
        catch (Exception ex)
        {
            Log("launcher", "Could not regenerate pixbuf cache: " + ex.Message);
        }
    }

    static Process StartService(string exe, string args, string logName, bool captureStdout)
    {
        Process p = new Process();
        p.StartInfo.FileName = exe;
        p.StartInfo.Arguments = args;
        p.StartInfo.WorkingDirectory = Path.GetDirectoryName(exe);
        p.StartInfo.UseShellExecute = false;
        p.StartInfo.CreateNoWindow = true;
        p.StartInfo.RedirectStandardOutput = true;
        p.StartInfo.RedirectStandardError = true;
        if (captureStdout)
        {
            p.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e)
            {
                if (e.Data != null) Log(logName, e.Data);
            };
        }
        else
        {
            p.OutputDataReceived += delegate(object s, DataReceivedEventArgs e)
            {
                if (e.Data != null) Log(logName, e.Data);
            };
            p.ErrorDataReceived += delegate(object s, DataReceivedEventArgs e)
            {
                if (e.Data != null) Log(logName, e.Data);
            };
        }
        p.Start();
        if (!captureStdout)
            p.BeginOutputReadLine();
        p.BeginErrorReadLine();
        return p;
    }

    static void Log(string name, string text)
    {
        try
        {
            lock (LogLock)
            {
                File.AppendAllText(
                    Path.Combine(LogDir, name + ".log"),
                    DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "  " + text + "\r\n");
            }
        }
        catch
        {
        }
    }

    static void TryKill(Process p)
    {
        try
        {
            if (p != null && !p.HasExited)
                p.Kill();
        }
        catch
        {
        }
    }

    static void ShowError(string message)
    {
        Log("launcher", message);
        MessageBox.Show(message, "GNOME Calendar",
            MessageBoxButtons.OK, MessageBoxIcon.Error);
    }
}
