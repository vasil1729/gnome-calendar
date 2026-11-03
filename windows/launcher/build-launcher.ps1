param(
    [Parameter(Mandatory = $true)]
    [string]$BundleDir,

    [switch]$CreateDesktopShortcut
)

$ErrorActionPreference = 'Stop'

$csc = 'C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) {
    throw "csc.exe not found at $csc. Install the .NET Framework 4.x developer tools."
}

$out = Join-Path $BundleDir 'GNOME Calendar.exe'
if (Test-Path $out) {
    Remove-Item $out -Force
}

& $csc /nologo /target:winexe /platform:anycpu `
    "/win32icon:$PSScriptRoot\icon.ico" `
    "/out:$out" `
    /r:System.dll /r:System.Windows.Forms.dll `
    "$PSScriptRoot\native-launcher.cs"

if ($LASTEXITCODE -ne 0) {
    throw "csc failed with exit code $LASTEXITCODE"
}

if ($CreateDesktopShortcut) {
    $ws = New-Object -ComObject WScript.Shell
    $desktop = [Environment]::GetFolderPath('Desktop')
    $lnk = $ws.CreateShortcut((Join-Path $desktop 'GNOME Calendar.lnk'))
    $lnk.TargetPath = $out
    $lnk.WorkingDirectory = $BundleDir
    $lnk.IconLocation = "$out,0"
    $lnk.Description = 'GNOME Calendar (native Windows build)'
    $lnk.Save()
}

Write-Output "Launcher created at $out"
