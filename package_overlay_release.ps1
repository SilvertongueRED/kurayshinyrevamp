[CmdletBinding()]
param(
    [string]$ReleaseName = "PIF-player-build-20260527-full-current-update1",
    [string]$PreviousManifestPath = "",
    [string]$OutputRoot = "",
    [switch]$KeepStage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}

$projectRoot = [System.IO.Path]::GetFullPath($scriptRoot)
$resolvedOutputRoot = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    Join-Path $projectRoot "dist"
} else {
    [System.IO.Path]::GetFullPath($OutputRoot)
}
$resolvedPreviousManifestPath = if ([string]::IsNullOrWhiteSpace($PreviousManifestPath)) {
    Join-Path $resolvedOutputRoot "PIF-player-build-20260422-no-csf.manifest.txt"
} else {
    [System.IO.Path]::GetFullPath($PreviousManifestPath)
}

$stageRoot = Join-Path $resolvedOutputRoot $ReleaseName
$packageRoot = Join-Path $stageRoot "PIF"
$archivePath = Join-Path $resolvedOutputRoot ("{0}.7z" -f $ReleaseName)
$manifestPath = Join-Path $resolvedOutputRoot ("{0}.manifest.txt" -f $ReleaseName)
$hashPath = Join-Path $resolvedOutputRoot ("{0}.sha256.txt" -f $ReleaseName)
$sevenZipPath = Join-Path $projectRoot "REQUIRED_BY_INSTALLER_UPDATER\7z.exe"

$includeDirectories = @(
    "Audio",
    "Data",
    "ExpansionLinks",
    "Fonts",
    "Graphics",
    "Libs",
    "Mods",
    "KIFM"
)

$includeFiles = @(
    "Game.exe",
    "Game-compatibility.exe",
    "Game.ini",
    "mkxp.json",
    "README.md",
    "PIF_readme.txt",
    "PIF_Credits.txt",
    "RGSS100J.dll",
    "RGSS104E.dll",
    "Shiny Finder.bat",
    "Shiny Finder.exe",
    "Shiny Finder.pck",
    "x64-msvcrt-ruby300.dll",
    "x64-msvcrt-ruby310.dll",
    "zlib1.dll"
)

$cleanupPaths = @(
    "Data\.idea",
    "Data\.DS_Store",
    "Data\Map418 1.rxdata",
    "Data\pokedex\rate_limit.log",
    "Data\sprites\sprites_rate_limit.log",
    "Data\sprites\updated_spritesheets_cache",
    "Data\sprites\updated_spritesheets_cache_full",
    "Mods\compat_report.txt",
    "Mods\mod_manager_state.json",
    "Mods\autoplay_bot\data\cache",
    "Mods\autoplay_bot\logs",
    "Mods\custom_species_framework\checkpoints",
    "Mods\custom_species_framework\framework_debug.log",
    "Mods\custom_species_framework\creator\_job_state.json",
    "Mods\custom_species_framework\creator\_creator_server_url.txt",
    "Mods\custom_species_framework\creator\edge_dom.txt",
    "Mods\custom_species_framework\importer\state\import_state.json",
    "Mods\custom_species_framework\importer\import_output\import.log",
    "Mods\zzz_gba_player\ROMs",
    "Mods\zzz_gba_player\Saves",
    "Mods\zzz_gba_player\mirror_runtime",
    "Mods\zzz_gba_player\launch.log",
    "Mods\zzz_gba_player\Emulator\mGBA-0.10.5-win64\qt.ini",
    "Mods\zzz_gba_player\native\corehost\bin",
    "Mods\zzz_gba_player\native\corehost\obj",
    "Mods\zzz_gba_player\native\mirror\bin",
    "Mods\zzz_gba_player\native\mirror\obj",
    "KIFM\platinum_uuids.txt",
    "KIFM\discord_ids.txt",
    "KIFM\pending_discord_link.txt",
    "KIFM\coop_debug.log",
    "KIFM\pvp_wins.txt",
    "KIFM\discord_link.log"
)

$excludedPackagePaths = @()

$cleanupWildcardRelativePatterns = @(
    "Mods\autoplay_bot\data\state*.json",
    "Mods\custom_species_framework\creator\*.log",
    "Mods\zzz_gba_player\native\*\publish\*.pdb",
    "Mods\zzz_gba_player\ROMs\*.gba",
    "Mods\zzz_gba_player\ROMs\*.gb",
    "Mods\zzz_gba_player\ROMs\*.gbc",
    "Mods\zzz_gba_player\ROMs\*.zip",
    "Mods\zzz_gba_player\ROMs\*.sav",
    "Mods\zzz_gba_player\ROMs\*.srm",
    "Mods\zzz_gba_player\Saves\*.sav",
    "Mods\zzz_gba_player\Saves\*.srm",
    "Mods\zzz_gba_player\Saves\*.sa1"
)

$cleanupRecursiveFileNames = @(
    ".DS_Store",
    "Thumbs.db"
)

$cleanupRecursiveDirectoryNames = @(
    ".idea",
    "__pycache__"
)

function Get-FullPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return [System.IO.Path]::GetFullPath($Path)
}

function Assert-UnderRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Root
    )

    $fullPath = Get-FullPath -Path $Path
    $fullRoot = Get-FullPath -Path $Root
    $comparisonRoot = if ($fullRoot.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $fullRoot
    } else {
        $fullRoot + [System.IO.Path]::DirectorySeparatorChar
    }

    if (($fullPath -ne $fullRoot) -and (-not $fullPath.StartsWith($comparisonRoot, [System.StringComparison]::OrdinalIgnoreCase))) {
        throw "Refusing to operate on path outside root. Path: $fullPath Root: $fullRoot"
    }
}

function Ensure-CleanDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = Get-FullPath -Path $Path
    Assert-UnderRoot -Path $fullPath -Root $resolvedOutputRoot

    if (Test-Path -LiteralPath $fullPath) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
}

function Normalize-RelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    return ($Path -replace '/', '\').TrimStart('\')
}

function Parse-ManifestCutoff {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Previous manifest not found: $Path"
    }

    $generatedLine = Get-Content -LiteralPath $Path | Where-Object { $_ -like 'Generated at:*' } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($generatedLine)) {
        throw "Could not find 'Generated at:' in previous manifest: $Path"
    }

    $timestampText = $generatedLine.Substring('Generated at:'.Length).Trim()
    return [DateTimeOffset]::Parse($timestampText)
}

function New-PathSets {
    $excludedExact = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $excludedPrefixes = New-Object System.Collections.Generic.List[string]

    foreach ($path in $cleanupPaths + $excludedPackagePaths) {
        $normalized = Normalize-RelativePath $path
        if ([System.IO.Path]::GetExtension($normalized)) {
            [void]$excludedExact.Add($normalized)
        } else {
            $excludedPrefixes.Add(($normalized.TrimEnd('\') + '\'))
        }
    }

    $directoryNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $cleanupRecursiveDirectoryNames) {
        [void]$directoryNames.Add($name)
    }

    $fileNames = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in $cleanupRecursiveFileNames) {
        [void]$fileNames.Add($name)
    }

    return [PSCustomObject]@{
        ExcludedExact = $excludedExact
        ExcludedPrefixes = $excludedPrefixes
        DirectoryNames = $directoryNames
        FileNames = $fileNames
    }
}

function Test-PackagedRelativePath {
    param(
        [Parameter(Mandatory = $true)][string]$RelativePath,
        [Parameter(Mandatory = $true)]$PathSets
    )

    $normalized = Normalize-RelativePath $RelativePath
    if ($PathSets.ExcludedExact.Contains($normalized)) {
        return $false
    }

    foreach ($prefix in $PathSets.ExcludedPrefixes) {
        if ($normalized.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }

    foreach ($segment in $normalized.Split('\')) {
        if ($PathSets.DirectoryNames.Contains($segment)) {
            return $false
        }
    }

    $fileName = [System.IO.Path]::GetFileName($normalized)
    if ($PathSets.FileNames.Contains($fileName)) {
        return $false
    }

    foreach ($relativePattern in $cleanupWildcardRelativePatterns) {
        if ($normalized -like (Normalize-RelativePath $relativePattern)) {
            return $false
        }
    }

    return $true
}

function Convert-DescriptionToText {
    param([Parameter(Mandatory = $true)]$Description)

    if ($Description -is [System.Array]) {
        return (($Description | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ }) -join " ")
    }

    return $Description.ToString().Trim()
}

function New-ModCreditsContent {
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("Kuray Infinite Fusion Packaged Mod Credits")
    $lines.Add("")
    $lines.Add("This tester build bundles the current local mod stack plus the current KIF multiplayer files.")
    $lines.Add("Author labels below come from each included mod's own metadata when available.")
    $lines.Add("")
    $lines.Add("Included multiplayer")
    $lines.Add("- KIF multiplayer client scripts under Data\\Scripts\\659_Multiplayer and the KIFM companion server/runtime files are included in this build.")
    $lines.Add("")
    $lines.Add("Included mods")

    $modsRoot = Join-Path $projectRoot "Mods"
    if (Test-Path -LiteralPath $modsRoot) {
        $modEntries = Get-ChildItem -LiteralPath $modsRoot -Directory | ForEach-Object {
            $modJsonPath = Join-Path $_.FullName "mod.json"
            if (Test-Path -LiteralPath $modJsonPath) {
                try {
                    $manifest = Get-Content -LiteralPath $modJsonPath -Raw | ConvertFrom-Json
                    [PSCustomObject]@{
                        Name = if ($manifest.name) { $manifest.name.ToString() } else { $_.Name }
                        Id = if ($manifest.id) { $manifest.id.ToString() } else { $_.Name }
                        Version = if ($manifest.version) { $manifest.version.ToString() } else { "Unversioned" }
                        Author = if ($manifest.author) { $manifest.author.ToString() } else { "Unknown" }
                        Description = if ($manifest.description) { Convert-DescriptionToText -Description $manifest.description } else { "" }
                    }
                }
                catch {
                    [PSCustomObject]@{
                        Name = $_.Name
                        Id = $_.Name
                        Version = "Unreadable mod.json"
                        Author = "Unknown"
                        Description = ""
                    }
                }
            }
        } | Sort-Object Name

        foreach ($entry in $modEntries) {
            $descriptionText = if ([string]::IsNullOrWhiteSpace($entry.Description)) {
                ""
            } else {
                " | {0}" -f $entry.Description
            }
            $lines.Add(("- {0} ({1}, v{2}) | Author: {3}{4}" -f $entry.Name, $entry.Id, $entry.Version, $entry.Author, $descriptionText))
        }
    }

    $lines.Add("")
    $lines.Add("Third-party runtime credits")
    $lines.Add("- GBA Player bundles the mGBA 0.10.5 Windows runtime for public testing. See Mods\\zzz_gba_player\\Emulator\\mGBA-0.10.5-win64\\LICENSE.txt and the bundled licenses folder for upstream notices.")
    $lines.Add("- GBA Player also ships the mgba_libretro core and native helper runtime files used by its mirror/native bridge flow.")

    $importCreditsPath = Join-Path $projectRoot "Mods\custom_species_framework\importer\import_output\credits_manifest.json"
    if (Test-Path -LiteralPath $importCreditsPath) {
        try {
            $creditsManifest = Get-Content -LiteralPath $importCreditsPath -Raw | ConvertFrom-Json
            if ($creditsManifest.credits.Count -gt 0) {
                $lines.Add("")
                $lines.Add("Imported species pack credits")
                foreach ($credit in $creditsManifest.credits) {
                    $lines.Add(("- {0} | Creator: {1} | Source pack: {2} | Permission: {3}" -f $credit.species_name, $credit.creator, $credit.source_pack, $credit.usage_permission))
                    if ($credit.credit_text) {
                        $lines.Add(("  Release note credit: {0}" -f $credit.credit_text))
                    }
                }
            }
        }
        catch {
            $lines.Add("")
            $lines.Add("Imported species pack credits")
            $lines.Add("- The credits manifest under Mods\\custom_species_framework\\importer\\import_output\\credits_manifest.json could not be parsed during packaging.")
        }
    }

    $lines.Add("")
    $lines.Add("Project-wide credits")
    $lines.Add("- Full project/base-game credits remain in PIF_Credits.txt and README.md.")

    return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

function Get-PackagedFiles {
    param([Parameter(Mandatory = $true)]$PathSets)

    $packagedFiles = New-Object System.Collections.Generic.List[object]

    foreach ($relativeDirectory in $includeDirectories) {
        $fullDirectory = Join-Path $projectRoot $relativeDirectory
        if (-not (Test-Path -LiteralPath $fullDirectory)) {
            continue
        }

        Get-ChildItem -LiteralPath $fullDirectory -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $relativePath = $_.FullName.Substring($projectRoot.Length).TrimStart('\')
            if (Test-PackagedRelativePath -RelativePath $relativePath -PathSets $PathSets) {
                $packagedFiles.Add([PSCustomObject]@{
                    RelativePath = $relativePath
                    SourcePath = $_.FullName
                    Length = $_.Length
                    LastWriteTime = [DateTimeOffset]$_.LastWriteTime
                })
            }
        }
    }

    foreach ($relativeFile in $includeFiles) {
        $fullPath = Join-Path $projectRoot $relativeFile
        if (-not (Test-Path -LiteralPath $fullPath)) {
            continue
        }

        if (Test-PackagedRelativePath -RelativePath $relativeFile -PathSets $PathSets) {
            $item = Get-Item -LiteralPath $fullPath
            $packagedFiles.Add([PSCustomObject]@{
                RelativePath = $relativeFile
                SourcePath = $item.FullName
                Length = $item.Length
                LastWriteTime = [DateTimeOffset]$item.LastWriteTime
            })
        }
    }

    return $packagedFiles
}

function Copy-ChangedFilesToStage {
    param([Parameter(Mandatory = $true)][object[]]$Files)

    foreach ($file in $Files) {
        $destinationPath = Join-Path $packageRoot $file.RelativePath
        $destinationDirectory = Split-Path -Parent $destinationPath
        if ($destinationDirectory) {
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        }

        Copy-Item -LiteralPath $file.SourcePath -Destination $destinationPath -Force
    }
}

function Get-PublicGbaPlayerConfigContent {
    return @'
{
  "rom_roots": ["Mods/zzz_gba_player/ROMs"],
  "save_roots": ["Mods/zzz_gba_player/Saves", "Mods/zzz_gba_player/ROMs"],
  "emulator_path": "",
  "emulator_search_roots": ["Mods/zzz_gba_player/Emulator"],
  "emulator_args": "{rom}",
  "emulator_volume_percent": 25,
  "bridge_backend": "mirror",
  "native_core_enabled": false,
  "libretro_core_path": "Mods/zzz_gba_player/native/corehost/cores/mgba_libretro.dll",
  "native_frame_fps": 30,
  "native_audio_buffer_ms": 240,
  "display_mode": "pip",
  "mirror_embed": true,
  "mirror_lock_aspect": true,
  "mirror_fps": 30,
  "walkalong_size": "large",
  "walkalong_screen_width": 180,
  "walkalong_position": "top_right",
  "walkalong_x": null,
  "walkalong_y": null,
  "walkalong_pocketed": false,
  "keymap": {
    "up": "I",
    "down": "K",
    "left": "J",
    "right": "L",
    "a": "U",
    "b": "O",
    "l": "Y",
    "r": "P",
    "start": "H",
    "select": "G",
    "stop": "F12",
    "toggle_size": "F11"
  },
  "species_overrides": {},
  "move_overrides": {},
  "item_overrides": {},
  "favorites": [],
  "last_rom": ""
}
'@
}

function Apply-PublicPackageSanitization {
    param([Parameter(Mandatory = $true)][string]$RootPath)

    $gbaConfigPath = Join-Path $RootPath "Mods\zzz_gba_player\config.json"
    if (Test-Path -LiteralPath $gbaConfigPath) {
        Set-Content -LiteralPath $gbaConfigPath -Value (Get-PublicGbaPlayerConfigContent) -Encoding UTF8
    }

    $runtimeCleanupPaths = @(
        "Mods\zzz_gba_player\ROMs",
        "Mods\zzz_gba_player\Saves",
        "Mods\zzz_gba_player\mirror_runtime",
        "Mods\zzz_gba_player\launch.log",
        "Mods\zzz_gba_player\Emulator\mGBA-0.10.5-win64\qt.ini",
        "Mods\zzz_gba_player\native\corehost\bin",
        "Mods\zzz_gba_player\native\corehost\obj",
        "Mods\zzz_gba_player\native\mirror\bin",
        "Mods\zzz_gba_player\native\mirror\obj",
        "Mods\zzz_gba_player\native\corehost\publish\GBAPlayerCoreHost.pdb",
        "Mods\zzz_gba_player\native\mirror\publish\GBAPlayerMirror.pdb"
    )

    foreach ($relativePath in $runtimeCleanupPaths) {
        $fullPath = Join-Path $RootPath $relativePath
        if (Test-Path -LiteralPath $fullPath) {
            Assert-UnderRoot -Path $fullPath -Root $RootPath
            $item = Get-Item -LiteralPath $fullPath
            if ($item.PSIsContainer) {
                Remove-Item -LiteralPath $fullPath -Recurse -Force
            } else {
                Remove-Item -LiteralPath $fullPath -Force
            }
        }
    }
}

function New-OverlayPlayerReadme {
    param(
        [Parameter(Mandatory = $true)][DateTimeOffset]$Cutoff,
        [Parameter(Mandatory = $true)][int]$ChangedCount
    )

    $lines = @(
        "Kuray Infinite Fusion Overlay Update",
        "",
        "This package only contains files that changed after the base no-CSF player build generated at {0}." -f $Cutoff.ToString("yyyy-MM-dd HH:mm:ss zzz"),
        "It upgrades the existing 2026-04-22 no-CSF release into the current experimental full tester build.",
        "",
        "What this update expects",
        "- Fresh installs should use the updated WebSetup installer so it can download the base release first and then apply this overlay automatically.",
        "- Existing installs from the public 2026-04-22 no-CSF release can apply this update directly through the same updated WebSetup installer.",
        "- This overlay now carries the current custom species framework content, modded multiplayer content, travel expansion links, GBA Player scaffold content, and current packaged mod stack.",
        "- Local save data, GBA ROM/save content, and machine-specific cache/log files still stay out of the package.",
        "",
        "Changed packaged files in this overlay: {0}" -f $ChangedCount
    )

    return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

function New-OverlayManifest {
    param(
        [Parameter(Mandatory = $true)][DateTimeOffset]$Cutoff,
        [Parameter(Mandatory = $true)][object[]]$ChangedFiles,
        [Parameter(Mandatory = $true)][int64]$ChangedBytes
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("Overlay Build Manifest")
    $lines.Add("")
    $lines.Add(("Project root: {0}" -f $projectRoot))
    $lines.Add("Package root folder name: PIF")
    $lines.Add(("Generated at: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")))
    $lines.Add(("Base manifest cutoff: {0}" -f $Cutoff.ToString("yyyy-MM-dd HH:mm:ss zzz")))
    $lines.Add(("Changed file count: {0}" -f $ChangedFiles.Count))
    $lines.Add(("Changed payload size: {0:N3} MB" -f ($ChangedBytes / 1MB)))
    $lines.Add("")
    $lines.Add("Changed packaged files:")
    foreach ($file in $ChangedFiles) {
        $lines.Add((" - {0} ({1} bytes, {2})" -f $file.RelativePath, $file.Length, $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss zzz")))
    }

    return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

if (-not (Test-Path -LiteralPath $sevenZipPath)) {
    throw "7z.exe was not found at $sevenZipPath"
}

New-Item -ItemType Directory -Path $resolvedOutputRoot -Force | Out-Null
$pathSets = New-PathSets
$cutoff = Parse-ManifestCutoff -Path $resolvedPreviousManifestPath
$packagedFiles = Get-PackagedFiles -PathSets $pathSets
$changedFiles = @($packagedFiles | Where-Object { $_.LastWriteTime -gt $cutoff } | Sort-Object RelativePath)

if ($changedFiles.Count -eq 0) {
    throw "No packaged files changed after the previous manifest cutoff ($($cutoff.ToString('yyyy-MM-dd HH:mm:ss zzz')))."
}

$changedBytes = [int64](($changedFiles | Measure-Object -Property Length -Sum).Sum)

Write-Host ("Building overlay stage at {0}" -f $stageRoot)
Ensure-CleanDirectory -Path $stageRoot
New-Item -ItemType Directory -Path $packageRoot -Force | Out-Null
Copy-ChangedFilesToStage -Files $changedFiles
Apply-PublicPackageSanitization -RootPath $packageRoot

$playerReadmePath = Join-Path $packageRoot "PLAYER_RELEASE_README.txt"
$buildManifestPath = Join-Path $packageRoot "PACKAGED_BUILD_MANIFEST.txt"
$modCreditsPath = Join-Path $packageRoot "PACKAGED_MOD_CREDITS.txt"
Set-Content -LiteralPath $playerReadmePath -Value (New-OverlayPlayerReadme -Cutoff $cutoff -ChangedCount $changedFiles.Count) -Encoding UTF8
Set-Content -LiteralPath $buildManifestPath -Value (New-OverlayManifest -Cutoff $cutoff -ChangedFiles $changedFiles -ChangedBytes $changedBytes) -Encoding UTF8
Set-Content -LiteralPath $modCreditsPath -Value (New-ModCreditsContent) -Encoding UTF8
Set-Content -LiteralPath $manifestPath -Value (New-OverlayManifest -Cutoff $cutoff -ChangedFiles $changedFiles -ChangedBytes $changedBytes) -Encoding UTF8

if (Test-Path -LiteralPath $archivePath) {
    Remove-Item -LiteralPath $archivePath -Force
}

Write-Host ("Creating overlay archive at {0}" -f $archivePath)
Push-Location $stageRoot
try {
    & $sevenZipPath a -t7z -mx=3 -mmt=on $archivePath "PIF" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "7z archive creation failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

$archiveHash = Get-FileHash -LiteralPath $archivePath -Algorithm SHA256
Set-Content -LiteralPath $hashPath -Value ("{0} *{1}" -f $archiveHash.Hash.ToLowerInvariant(), (Split-Path -Leaf $archivePath)) -Encoding ASCII

if (-not $KeepStage) {
    Remove-Item -LiteralPath $stageRoot -Recurse -Force
}

Write-Host ""
Write-Host ("Changed packaged files: {0}" -f $changedFiles.Count)
Write-Host ("Changed payload size: {0:N3} MB" -f ($changedBytes / 1MB))
Write-Host ("Archive: {0}" -f $archivePath)
Write-Host ("SHA256: {0}" -f $hashPath)
