$version = "1.0.0"
$distDir = "dist"

if (Test-Path $distDir) { Remove-Item -Recurse -Force $distDir }
New-Item -ItemType Directory -Path $distDir

$targets = @(
    @{ os = "windows"; arch = "amd64"; ext = ".exe"; archive = "zip" },
    @{ os = "darwin";  arch = "amd64"; ext = "";     archive = "tar.gz" },
    @{ os = "darwin";  arch = "arm64"; ext = "";     archive = "tar.gz" },
    @{ os = "linux";   arch = "amd64"; ext = "";     archive = "tar.gz" }
)

$hashes = @{}

foreach ($t in $targets) {
    $os = $t.os
    $arch = $t.arch
    $ext = $t.ext
    $name = if ($os -eq "windows") { "ListenRelay" } else { "listenrelay" }
    $outputName = "$name$ext"
    
    $platformName = if ($os -eq "darwin") { "macos" } else { $os }
    $archiveFileName = "$($name.ToLower())-$platformName-$arch"

    Write-Host "`n--- Building for $os/$arch ---" -ForegroundColor Cyan
    
    $env:GOOS = $os
    $env:GOARCH = $arch
    
    if ($os -eq "windows") {
        Set-Location ListenRelay
        & rsrc -manifest ListenRelay.exe.manifest -ico icon.ico -o rsrc.syso
        Set-Location ..
    }

    $buildArgs = @("build", "-ldflags", "-s -w")
    if ($os -eq "windows") { $buildArgs += "-ldflags=-H=windowsgui -s -w" }
    $buildArgs += @("-o", "../$distDir/$outputName")

    Set-Location ListenRelay
    & go $buildArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed for $os/$arch"
        if ($os -eq "windows") { Remove-Item rsrc.syso -ErrorAction SilentlyContinue }
        Set-Location ..
        continue
    }
    if ($os -eq "windows") { Remove-Item rsrc.syso -ErrorAction SilentlyContinue }
    Set-Location ..

    # Package
    Set-Location $distDir
    $hash = ""
    if ($t.archive -eq "tar.gz") {
        tar -czf "$archiveFileName.tar.gz" $outputName "../listenrelay.lua"
        Remove-Item $outputName
        
        $hashFile = "$archiveFileName.tar.gz"
        try { $hash = (Get-FileHash $hashFile -Algorithm SHA256).Hash.ToLower() } catch {
            $hash = (certutil -hashfile $hashFile SHA256)[1].Replace(" ", "").ToLower()
        }
    } else {
        $zipFiles = @($outputName, "../listenrelay.lua")
        if (Test-Path "../ListenRelay/icon.ico") { $zipFiles += "../ListenRelay/icon.ico" }
        if (Test-Path "../ListenRelay/ListenRelay.exe.manifest") { $zipFiles += "../ListenRelay/ListenRelay.exe.manifest" }
        
        Compress-Archive -Path $zipFiles -DestinationPath "$archiveFileName.zip" -Force
        Remove-Item $outputName
        
        $hashFile = "$archiveFileName.zip"
        try { $hash = (Get-FileHash $hashFile -Algorithm SHA256).Hash.ToLower() } catch {
            $hash = (certutil -hashfile $hashFile SHA256)[1].Replace(" ", "").ToLower()
        }
    }
    
    $hashes["$os-$arch"] = $hash
    Write-Host "SHA256: $hash" -ForegroundColor Yellow
    Set-Location ..
}

Write-Host "`n--- Updating Distribution Files ---" -ForegroundColor Cyan

# 1. Update Homebrew Formula
$brewPath = "Formula/listenrelay.rb"
if (Test-Path $brewPath) {
    $content = Get-Content $brewPath -Raw
    $content = $content -replace '(?<=macos.*intel\?.*\n\s*url.*v1\.0\.0\/listenrelay-macos-amd64\.tar\.gz.*\n\s*sha256\s*")[\da-f]+', $hashes["darwin-amd64"]
    $content = $content -replace '(?<=else.*\n\s*url.*v1\.0\.0\/listenrelay-macos-arm64\.tar\.gz.*\n\s*sha256\s*")[\da-f]+', $hashes["darwin-arm64"]
    $content = $content -replace '(?<=on_linux.*\n\s*url.*v1\.0\.0\/listenrelay-linux-amd64\.tar\.gz.*\n\s*sha256\s*")[\da-f]+', $hashes["linux-amd64"]
    $content | Set-Content $brewPath
    Write-Host "Updated $brewPath" -ForegroundColor Green
}

# 2. Update Chocolatey Script
$chocoScript = "chocolatey/tools/chocolateyInstall.ps1"
if (Test-Path $chocoScript) {
    $content = Get-Content $chocoScript -Raw
    $content = $content -replace "(?<=checksum64\s*=\s*')[\da-f]+", $hashes["windows-amd64"]
    $content | Set-Content $chocoScript
    Write-Host "Updated $chocoScript" -ForegroundColor Green
}

# 3. Build MSI (WiX)
if (Get-Command candle -ErrorAction SilentlyContinue) {
    Write-Host "`n--- Building MSI Installer ---" -ForegroundColor Cyan
    # Build a fresh binary for the MSI
    Set-Location ListenRelay
    go build -ldflags "-H=windowsgui -s -w" -o ../ListenRelay.exe
    Set-Location ..
    
    candle ListenRelay.wxs
    light -ext WixUIExtension ListenRelay.wixobj -o "$distDir/ListenRelay.msi"
    
    Remove-Item ListenRelay.wixobj, ListenRelay.wixpdb, ListenRelay.exe -ErrorAction SilentlyContinue
    Write-Host "Created dist/ListenRelay.msi" -ForegroundColor Green
} else {
    Write-Warning "WiX Toolset (candle/light) not found. Skipping MSI build."
}

# 4. Build Chocolatey Package
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "`n--- Packaging Chocolatey ---" -ForegroundColor Cyan
    Set-Location chocolatey
    if (Test-Path "*.nupkg") { Remove-Item *.nupkg }
    & choco pack
    Move-Item *.nupkg "../$distDir/"
    Set-Location ..
    Write-Host "Created dist/listenrelay.$version.nupkg" -ForegroundColor Green
} else {
    Write-Warning "Chocolatey not found. Skipping .nupkg build."
}

Write-Host "`nBuild All Complete! Check the '$distDir' folder for all artifacts." -ForegroundColor Green