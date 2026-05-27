$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$coreDir = Join-Path $root "cores"
$zip = Join-Path $coreDir "mgba_libretro.dll.zip"
$url = "https://buildbot.libretro.com/nightly/windows/x86_64/latest/mgba_libretro.dll.zip"

New-Item -ItemType Directory -Force -Path $coreDir | Out-Null
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
Expand-Archive -Path $zip -DestinationPath $coreDir -Force
Remove-Item -LiteralPath $zip -Force

Write-Host "Installed $((Get-Item (Join-Path $coreDir 'mgba_libretro.dll')).FullName)"
