$packageName = 'listenrelay'
$toolsDir    = "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)"

Uninstall-BinFile -Name 'ListenRelay'
Uninstall-ChocolateyZipPackage -PackageName $packageName
