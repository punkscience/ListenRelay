$packageName = 'listenrelay'
$toolsDir    = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"

Uninstall-BinFile -Name 'ListenRelay'

# Remove Start Menu shortcut
$shortcutPath = Join-Path $env:ProgramData "Microsoft\Windows\Start Menu\Programs\ListenRelay.lnk"
if (Test-Path $shortcutPath) { Remove-Item $shortcutPath -Force }

Uninstall-ChocolateyZipPackage -PackageName $packageName