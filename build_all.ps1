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
    # Use PascalCase for Windows, lowercase for others
    $name = if ($os -eq "windows") { "ListenRelay" } else { "listenrelay" }
    $outputName = "$name$ext"
    
    $platformName = if ($os -eq "darwin") { "macos" } else { $os }
    $archiveName = "$($name.ToLower())-$platformName-$arch"

    Write-Host "Building for $os/$arch..." -ForegroundColor Cyan
    
    $env:GOOS = $os
    $env:GOARCH = $arch
    
    # Prepare build arguments
    $buildArgs = @("build")
    if ($os -eq "windows") {
        $buildArgs += "-ldflags=-H=windowsgui"
        Set-Location ListenRelay
        & rsrc -manifest ListenRelay.exe.manifest -ico icon.ico -o rsrc.syso
        Set-Location ..
    }
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
    if ($t.archive -eq "tar.gz") {
        tar -czf "$archiveName.tar.gz" $outputName "../listenrelay.lua"
        if (Test-Path $outputName) { Remove-Item $outputName }
        
        try {
            $hash = (Get-FileHash "$archiveName.tar.gz" -Algorithm SHA256).Hash.ToLower()
        } catch {
            $certOut = certutil -hashfile "$archiveName.tar.gz" SHA256
            $hash = $certOut[1].Replace(" ", "").ToLower()
        }
        Write-Host "SHA256 ($archiveName.tar.gz): $hash" -ForegroundColor Yellow
    } else {
        $zipFiles = @($outputName, "../listenrelay.lua")
        
        # Add Windows specific assets
        if (Test-Path "../ListenRelay/icon.ico") { $zipFiles += "../ListenRelay/icon.ico" }
        if (Test-Path "../ListenRelay/ListenRelay.exe.manifest") { $zipFiles += "../ListenRelay/ListenRelay.exe.manifest" }
        
        Compress-Archive -Path $zipFiles -DestinationPath "$archiveName.zip" -Force
        if (Test-Path $outputName) { Remove-Item $outputName }
        
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
