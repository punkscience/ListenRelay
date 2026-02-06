$ErrorActionPreference = 'Stop'
$packageName = 'listenrelay'
$toolsDir    = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"
$url64       = 'https://github.com/punkscience/ListenRelay/releases/download/v1.0.0/listenrelay-windows-amd64.zip'
$exePath     = Join-Path $toolsDir "ListenRelay.exe"

$packageArgs = @{
  packageName   = $packageName
  unzipLocation = $toolsDir
  url64bit      = $url64
  checksum64    = '024dc2d74d00287fe91ba4e94afdfe1a2440e8e5b74862099f720e19065ab5f7'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

# 1. Create a shim for the executable
Install-BinFile -Name 'ListenRelay' -Path $exePath

# 2. Create a Start Menu shortcut
$shortcutPath = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\ListenRelay.lnk"
Install-ChocolateyShortcut -shortcutFilePath $shortcutPath -targetPath $exePath -iconLocation (Join-Path $toolsDir "icon.ico")

# 3. Add to "Add/Remove Programs" (Registry)
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ListenRelay"
if (-not (Test-Path $registryPath)) {
    New-Item -Path $registryPath -Force | Out-Null
}
Set-ItemProperty -Path $registryPath -Name "DisplayName" -Value "ListenRelay"
Set-ItemProperty -Path $registryPath -Name "DisplayVersion" -Value "1.0.0"
Set-ItemProperty -Path $registryPath -Name "Publisher" -Value "Darryl G. Wright"
Set-ItemProperty -Path $registryPath -Name "DisplayIcon" -Value "$exePath,0"
Set-ItemProperty -Path $registryPath -Name "UninstallString" -Value "choco uninstall listenrelay -y"
Set-ItemProperty -Path $registryPath -Name "QuietUninstallString" -Value "choco uninstall listenrelay -y"
Set-ItemProperty -Path $registryPath -Name "InstallLocation" -Value "$toolsDir"
Set-ItemProperty -Path $registryPath -Name "URLInfoAbout" -Value "https://github.com/punkscience/ListenRelay"
Set-ItemProperty -Path $registryPath -Name "NoModify" -Value 1
Set-ItemProperty -Path $registryPath -Name "NoRepair" -Value 1

# 4. Add to Startup (Registry - Current User)
$startupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $startupPath -Name "ListenRelay" -Value "`"$exePath`" --minimized"

# 5. Automate VLC extension installation
$vlcExtensionDir = Join-Path $env:APPDATA "vlc\lua\extensions"
$luaSource = Join-Path $toolsDir "listenrelay.lua"

try {
    if (-not (Test-Path $vlcExtensionDir)) {
        New-Item -Path $vlcExtensionDir -ItemType Directory -Force | Out-Null
    }
    Copy-Item -Path $luaSource -Destination $vlcExtensionDir -Force
    Write-Host "Successfully installed VLC extension to: $vlcExtensionDir" -ForegroundColor Green
} catch {
    Write-Warning "Could not automatically install VLC extension."
}

Write-Warning "ListenRelay installed and added to Startup & Installed Apps!"