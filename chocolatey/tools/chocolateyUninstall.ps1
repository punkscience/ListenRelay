$packageName = 'listenrelay'
$toolsDir    = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"

Uninstall-BinFile -Name 'ListenRelay'

# 1. Remove Start Menu shortcut
$shortcutPath = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\ListenRelay.lnk"
if (Test-Path $shortcutPath) { Remove-Item $shortcutPath -Force }

# 2. Remove from "Add/Remove Programs" (Registry)
$registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ListenRelay"
if (Test-Path $registryPath) {
    Remove-Item -Path $registryPath -Recurse -Force
}

# 3. Remove from Startup (Registry - Current User)
$startupPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
if (Get-ItemProperty -Path $startupPath -Name "ListenRelay" -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $startupPath -Name "ListenRelay" -Force
}

# 4. Remove VLC extension (Optional, but clean)
$vlcExtensionDir = Join-Path $env:APPDATA "vlc\lua\extensions"
$luaFile = Join-Path $vlcExtensionDir "listenrelay.lua"
if (Test-Path $luaFile) {
    Remove-Item $luaFile -Force
}

# Chocolatey removes the tools directory automatically