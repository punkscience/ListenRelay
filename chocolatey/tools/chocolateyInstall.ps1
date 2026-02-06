$ErrorActionPreference = 'Stop'
$packageName = 'listenrelay'
$toolsDir    = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"
$url64       = 'https://github.com/punkscience/ListenRelay/releases/download/v1.0.0/listenrelay-windows-amd64.zip'

$packageArgs = @{
  packageName   = $packageName
  unzipLocation = $toolsDir
  url64bit      = $url64
  checksum64    = '5e95ded107a1112ee676464edbee6f035606e233aed890c9aa53c0cb90cf5e1e'
  checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

# Create a shim for the executable
Install-BinFile -Name 'ListenRelay' -Path "$toolsDir\ListenRelay.exe"

Write-Warning "ListenRelay installed!"
Write-Warning "To install the VLC extension, copy '$toolsDir\listenrelay.lua' to your VLC extensions folder:"
Write-Warning "  %APPDATA%\vlc\lua\extensions"
