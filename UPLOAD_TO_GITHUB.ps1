# Upload NetPulse source to your own GitHub repository.
# Run this script from the extracted NetPulse-iOS folder.
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git is not installed. Install Git for Windows first.' }
$repo = 'https://github.com/Donacgreece/NetPulse.git'
if (-not (Test-Path '.git')) { git init -b main }
if (git remote) { git remote set-url origin $repo } else { git remote add origin $repo }
git add .
git -c user.name='NetPulse Developer' -c user.email='netpulse@users.noreply.github.com' commit -m 'Initial NetPulse iOS 0.0.1 with unsigned IPA workflow'
if ($LASTEXITCODE -ne 0) { throw 'Git commit failed.' }
git push -u origin main
if ($LASTEXITCODE -ne 0) { throw 'Git push failed. Confirm GitHub authentication and repository access.' }
Write-Host 'Uploaded. Open https://github.com/Donacgreece/NetPulse/actions' -ForegroundColor Green
