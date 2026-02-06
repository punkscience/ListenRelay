# This script builds a native Windows MSI installer using the WiX Toolset.
# It assumes candle.exe and light.exe are in your PATH.

$distDir = "dist"
if (-not (Test-Path $distDir)) { New-Item -ItemType Directory -Path $distDir }

Write-Host "Building Go binary..." -ForegroundColor Cyan
Set-Location ListenRelay
go build -ldflags "-H=windowsgui" -o ../ListenRelay.exe
Set-Location ..

Write-Host "Compiling WiX source..." -ForegroundColor Cyan
candle ListenRelay.wxs

Write-Host "Linking MSI..." -ForegroundColor Cyan
light -ext WixUIExtension ListenRelay.wixobj -o dist/ListenRelay.msi

# Cleanup
Remove-Item ListenRelay.wixobj
Remove-Item ListenRelay.wixpdb
Remove-Item ListenRelay.exe

Write-Host "MSI build complete! Check dist/ListenRelay.msi" -ForegroundColor Green
