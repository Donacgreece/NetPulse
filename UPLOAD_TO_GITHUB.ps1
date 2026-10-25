$ErrorActionPreference = "Stop"
$source = $PSScriptRoot
$repo = "https://github.com/Donacgreece/NetPulse.git"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "Git is not installed." }
$target = Join-Path $env:TEMP "NetPulse-upload-0.0.2"
if (Test-Path $target) { Remove-Item $target -Recurse -Force }
git clone --branch main $repo $target
if ($LASTEXITCODE -ne 0) { throw "Git clone failed. Check GitHub authentication." }
$paths = @("NetPulse", ".github", "README.md", "project.yml", "UPLOAD_TO_GITHUB.ps1")
foreach ($item in $paths) {
    $src = Join-Path $source $item
    $dst = Join-Path $target $item
    if (-not (Test-Path $src)) { throw "Missing: $src" }
    if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
    Copy-Item -Path $src -Destination $dst -Recurse -Force
}
Push-Location $target
try {
    git add -A
    if ($LASTEXITCODE -ne 0) { throw "git add failed" }
    $changes = git status --porcelain
    if ($changes) {
        git -c user.name="Donacgreece" -c user.email="donacgreece@users.noreply.github.com" commit -m "NetPulse 0.0.2 redesigned Ethernet checker"
        if ($LASTEXITCODE -ne 0) { throw "git commit failed" }
        git push origin main
        if ($LASTEXITCODE -ne 0) { throw "git push failed" }
    }
    Write-Host "SUCCESS: NetPulse 0.0.2 uploaded" -ForegroundColor Green
} finally { Pop-Location }
Start-Process "https://github.com/Donacgreece/NetPulse/actions"
