# PadCare 1-Click Automated Web & GitHub Pages Deployer
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path "$PSScriptRoot/..").Path

Write-Host "Building PadCare Web with --base-href /PadCare/..." -ForegroundColor Cyan
Push-Location $repoRoot
try {
    flutter build web --base-href /PadCare/

    Write-Host "Configuring GitHub Pages .nojekyll and 404.html..." -ForegroundColor Cyan
    New-Item -ItemType File -Path "build\web\.nojekyll" -Force | Out-Null
    $ts = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    (Get-Content "build\web\index.html") -replace 'flutter_bootstrap\.js', "flutter_bootstrap.js?v=$ts" | Set-Content "build\web\index.html"
    Copy-Item -Path "build\web\index.html" -Destination "build\web\404.html" -Force

    $originUrl = (git remote get-url origin)

    Write-Host "Deploying to GitHub Pages (gh-pages branch)..." -ForegroundColor Cyan
    $tempDir = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "padcare-ghpages-" + [System.Guid]::NewGuid().ToString())
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Get-ChildItem -Path "build\web" -Exclude "padcare.apk" | Copy-Item -Destination $tempDir -Recurse -Force

    Push-Location $tempDir
    try {
        git init | Out-Null
        git config user.name "PadCare Team"
        git config user.email "dev@padcare.org"
        git checkout -B gh-pages | Out-Null
        git add -A
        git commit -m "deploy: automated web build with auto-updated release APK integration" | Out-Null
        git remote add origin $originUrl
        git push -f origin gh-pages
        Write-Host "Successfully deployed to GitHub Pages!" -ForegroundColor Green
        Write-Host "Live Website: https://danmungufeni-dev.github.io/PadCare/" -ForegroundColor Green
        Write-Host "Direct Auto-Updated APK: https://github.com/danmungufeni-dev/PadCare/releases/latest/download/padcare.apk" -ForegroundColor Green
    } finally {
        Pop-Location
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} finally {
    Pop-Location
}
