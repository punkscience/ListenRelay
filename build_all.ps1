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

foreach ($t in $targets) {
    $os = $t.os
    $arch = $t.arch
    $ext = $t.ext
    $name = "listenrelay"
    $outputName = "$name$ext"
    
    $platformName = if ($os -eq "darwin") { "macos" } else { $os }
    $archiveName = "$name-$platformName-$arch"

    Write-Host "Building for $os/$arch..." -ForegroundColor Cyan
    
    $env:GOOS = $os
    $env:GOARCH = $arch
    
    # Prepare build arguments
    $buildArgs = @("build")
    if ($os -eq "windows") {
        $buildArgs += "-ldflags=-H=windowsgui"
    }
    $buildArgs += @("-o", "../$distDir/$outputName")

    Set-Location ListenRelay
    & go $buildArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed for $os/$arch"
        Set-Location ..
        continue
    }
    Set-Location ..

    # Package
    Set-Location $distDir
    if ($t.archive -eq "tar.gz") {
        tar -czf "$archiveName.tar.gz" $outputName "../listenrelay.lua"
        if (Test-Path $outputName) { Remove-Item $outputName }
        
        # Fallback for Get-FileHash if it fails
        try {
            $hash = (Get-FileHash "$archiveName.tar.gz" -Algorithm SHA256).Hash.ToLower()
        } catch {
            # Use certutil as fallback on Windows
            $certOut = certutil -hashfile "$archiveName.tar.gz" SHA256
            $hash = $certOut[1].Replace(" ", "").ToLower()
        }
        Write-Host "SHA256 ($archiveName.tar.gz): $hash" -ForegroundColor Yellow
    } else {
        # Check if icon exists, fallback if not
        $iconPath = "../ListenRelay/icon.ico"
        $zipFiles = @($outputName, "../listenrelay.lua")
        if (Test-Path $iconPath) { $zipFiles += $iconPath }
        
        Compress-Archive -Path $zipFiles -DestinationPath "$archiveName.zip" -Force
        if (Test-Path $outputName) { Remove-Item $outputName }
        
        # Calculate hash for ZIP
        try {
            $hash = (Get-FileHash "$archiveName.zip" -Algorithm SHA256).Hash.ToLower()
        } catch {
            $certOut = certutil -hashfile "$archiveName.zip" SHA256
            $hash = $certOut[1].Replace(" ", "").ToLower()
        }
        Write-Host "SHA256 ($archiveName.zip): $hash" -ForegroundColor Yellow
    }
    Set-Location ..
}

Write-Host "`nBuild Complete! Check the '$distDir' folder." -ForegroundColor Green