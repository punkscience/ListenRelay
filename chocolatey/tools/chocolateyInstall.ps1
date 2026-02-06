$ErrorActionPreference = 'Stop'
$packageName = 'listenrelay'
$toolsDir    = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"
$url64       = 'https://github.com/punkscience/ListenRelay/releases/download/v1.0.0/listenrelay-windows-amd64.zip'

$packageArgs = @{
  packageName   = $packageName
  unzipLocation = $toolsDir
  url64bit      = $url64
  checksum64    = '5832474e54624198ec4dd3efc08c4213f796fc85e73d61cf128d4cac7e436f55'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

# Create a shim for the executable
Install-BinFile -Name 'ListenRelay' -Path "$toolsDir\ListenRelay.exe"

# Create a Start Menu shortcut
$shortcutPath = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\ListenRelay.lnk"
Install-ChocolateyShortcut -shortcutFilePath $shortcutPath -targetPath "$toolsDir\ListenRelay.exe" -iconLocation "$toolsDir\icon.ico"

Write-Warning "ListenRelay installed!"

Write-Warning "A shortcut has been added to your Start Menu."



# Attempt to automate VLC extension installation

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

    Write-Warning "Please manualy copy '$luaSource' to:"

    Write-Warning "  $vlcExtensionDir"

}
