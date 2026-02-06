$ErrorActionPreference = 'Stop'
$packageName = 'listenrelay'
$toolsDir    = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"
$url64       = 'https://github.com/punkscience/ListenRelay/releases/download/v1.0.0/listenrelay-windows-amd64.zip'

$packageArgs = @{
  packageName   = $packageName
  unzipLocation = $toolsDir
  url64bit      = $url64
  checksum64    = '13b8889609418a5c60183e4111a754656b350ed8402d1ada062c479e2aa6b59f'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

# Create a shim for the executable
Install-BinFile -Name 'ListenRelay' -Path "$toolsDir\ListenRelay.exe"

Write-Warning "ListenRelay installed!"
Write-Warning "To install the VLC extension, copy '$toolsDir\listenrelay.lua' to your VLC extensions folder:"
Write-Warning "  %APPDATA%\vlc\lua\extensions"
