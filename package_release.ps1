[CmdletBinding()]
param(
    [string]$ReleaseName = "",
    [string]$OutputRoot = "",
    [ValidateSet("archive", "stage", "both")]
    [string]$Mode = "archive"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = if ($PSScriptRoot) {
    $PSScriptRoot
} else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}

$projectRoot = [System.IO.Path]::GetFullPath($scriptRoot)
$projectName = Split-Path -Leaf $projectRoot
$resolvedReleaseName = if ([string]::IsNullOrWhiteSpace($ReleaseName)) {
    "{0}-player-build-{1}" -f $projectName, (Get-Date -Format "yyyyMMdd-HHmmss")
} else {
    $ReleaseName
}
$resolvedOutputRoot = if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    Join-Path $projectRoot "dist"
} else {
    $OutputRoot
}

$outputRootFull = [System.IO.Path]::GetFullPath($resolvedOutputRoot)
$stageRoot = Join-Path $outputRootFull $resolvedReleaseName
$packageRoot = Join-Path $stageRoot $projectName
$archivePath = Join-Path $outputRootFull ("{0}.7z" -f $resolvedReleaseName)
$manifestPath = Join-Path $outputRootFull ("{0}.manifest.txt" -f $resolvedReleaseName)
$hashPath = Join-Path $outputRootFull ("{0}.sha256.txt" -f $resolvedReleaseName)
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

$temporaryMetadataFiles = @(
    "PLAYER_RELEASE_README.txt",
    "PACKAGED_BUILD_MANIFEST.txt",
    "PACKAGED_MOD_CREDITS.txt"
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
    Assert-UnderRoot -Path $fullPath -Root $outputRootFull

    if (Test-Path -LiteralPath $fullPath) {
        Remove-Item -LiteralPath $fullPath -Recurse -Force
    }

    New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
}

function Get-DirectorySizeBytes {
    param([Parameter(Mandatory = $true)][string[]]$RelativeDirectories)

    $sum = 0L
    foreach ($relativeDirectory in $RelativeDirectories) {
        $fullDirectory = Join-Path $projectRoot $relativeDirectory
        if (Test-Path -LiteralPath $fullDirectory) {
            $directoryBytes = (Get-ChildItem -LiteralPath $fullDirectory -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            if ($null -ne $directoryBytes) {
                $sum += [int64]$directoryBytes
            }
        }
    }

    foreach ($relativeFile in $includeFiles) {
        $fullFile = Join-Path $projectRoot $relativeFile
        if (Test-Path -LiteralPath $fullFile) {
            $sum += (Get-Item -LiteralPath $fullFile).Length
        }
    }

    return $sum
}

function Format-Bytes {
    param([Parameter(Mandatory = $true)][int64]$Bytes)

    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    }

    if ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    }

    if ($Bytes -ge 1KB) {
        return "{0:N2} KB" -f ($Bytes / 1KB)
    }

    return "{0} B" -f $Bytes
}

function Get-FreeSpaceBytes {
    param([Parameter(Mandatory = $true)][string]$Path)

    $fullPath = Get-FullPath -Path $Path
    $driveRoot = [System.IO.Path]::GetPathRoot($fullPath)
    $driveName = $driveRoot.TrimEnd("\", "/").TrimEnd(":")
    $psDrive = Get-PSDrive -Name $driveName
    return [int64]$psDrive.Free
}

function Copy-DirectoryTree {
    param(
        [Parameter(Mandatory = $true)][string]$SourceRelative,
        [Parameter(Mandatory = $true)][string]$DestinationRoot
    )

    $source = Join-Path $projectRoot $SourceRelative
    $destination = Join-Path $DestinationRoot $SourceRelative
    New-Item -ItemType Directory -Path $destination -Force | Out-Null

    $arguments = @(
        $source,
        $destination,
        "/E",
        "/R:1",
        "/W:1",
        "/NFL",
        "/NDL",
        "/NJH",
        "/NJS",
        "/NP"
    )

    & robocopy @arguments | Out-Null
    $exitCode = $LASTEXITCODE
    if ($exitCode -gt 7) {
        throw "robocopy failed for $SourceRelative with exit code $exitCode"
    }
}

function Copy-IncludedFiles {
    param([Parameter(Mandatory = $true)][string]$DestinationRoot)

    foreach ($relativeFile in $includeFiles) {
        $source = Join-Path $projectRoot $relativeFile
        $destination = Join-Path $DestinationRoot $relativeFile
        $destinationDirectory = Split-Path -Parent $destination
        if (-not (Test-Path -LiteralPath $source)) {
            throw "Required file missing: $relativeFile"
        }

        if ($destinationDirectory) {
            New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        }

        Copy-Item -LiteralPath $source -Destination $destination -Force
    }
}

function Remove-CleanupPaths {
    param([Parameter(Mandatory = $true)][string]$RootPath)

    foreach ($relativePath in $cleanupPaths) {
        $fullPath = Join-Path $RootPath $relativePath
        if (Test-Path -LiteralPath $fullPath) {
            Assert-UnderRoot -Path $fullPath -Root $RootPath
            Remove-Item -LiteralPath $fullPath -Recurse -Force
        }
    }

    foreach ($relativePath in $excludedPackagePaths) {
        $fullPath = Join-Path $RootPath $relativePath
        if (Test-Path -LiteralPath $fullPath) {
            Assert-UnderRoot -Path $fullPath -Root $RootPath
            Remove-Item -LiteralPath $fullPath -Recurse -Force
        }
    }

    foreach ($relativePattern in $cleanupWildcardRelativePatterns) {
        $fullPattern = Join-Path $RootPath $relativePattern
        Get-ChildItem -Path $fullPattern -Force -ErrorAction SilentlyContinue | ForEach-Object {
            Assert-UnderRoot -Path $_.FullName -Root $RootPath
            Remove-Item -LiteralPath $_.FullName -Recurse -Force
        }
    }

    foreach ($fileName in $cleanupRecursiveFileNames) {
        Get-ChildItem -LiteralPath $RootPath -Recurse -Force -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ieq $fileName } |
            ForEach-Object {
                Assert-UnderRoot -Path $_.FullName -Root $RootPath
                Remove-Item -LiteralPath $_.FullName -Force
            }
    }

    foreach ($directoryName in $cleanupRecursiveDirectoryNames) {
        Get-ChildItem -LiteralPath $RootPath -Recurse -Force -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ieq $directoryName } |
            Sort-Object FullName -Descending |
            ForEach-Object {
                Assert-UnderRoot -Path $_.FullName -Root $RootPath
                Remove-Item -LiteralPath $_.FullName -Recurse -Force
            }
    }
}

function New-PlayerReadmeContent {
    $lines = @(
        "Kuray Infinite Fusion Experimental Player Build",
        "",
        "How to use this package",
        "1. Extract the archive into its own folder.",
        "2. Launch Game.exe. If that has compatibility issues on your machine, try Game-compatibility.exe.",
        "3. Keep the Audio, Data, Fonts, Graphics, Libs, Mods, and KIFM folders next to the game executable.",
        "",
        "What is included",
        "- Full game client data and graphics, including the packed sprite payload.",
        "- The current local Mods folder, modded multiplayer KIFM folder, Libs, and ExpansionLinks used by this build.",
        "- Custom Species Framework content, browser creator assets, imported species packs, and current travel expansion link definitions.",
        "- The experimental GBA Player scaffold, including its bundled emulator/runtime pieces needed for public testing.",
        "- Shiny Finder utility files that ship with the client.",
        "",
        "What was intentionally excluded",
        "- Personal configuration, local cache/state files, creator session leftovers, and bot runtime logs.",
        "- Savefile shortcuts, Discord link/account files, and machine-local multiplayer server state.",
        "- GBA Player ROMs, save files, local mirror frames, runtime logs, and local build/output folders.",
        "- ExpansionLibrary external game archives are not bundled in this package.",
        "",
        "Savefiles and user settings",
        "- Savefiles and some settings are stored outside this folder under %APPDATA%\\kurayinfinitefusion.",
        "- This package does not include personal save data.",
        "- The GBA Player scaffold also expects you to add your own ROMs and save files after installation.",
        "- This is an experimental merged tester build. Back up saves before using it on a real profile.",
        "",
        "Credits",
        "- Included mod and imported-species credits are summarized in PACKAGED_MOD_CREDITS.txt.",
        "- Third-party emulator/runtime credits for GBA Player are included in that file and in the bundled license files.",
        "- Base game and project-wide credits are still in PIF_Credits.txt and README.md.",
        "",
        ("Packaged on: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz"))
    )

    return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
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

function New-ManifestContent {
    param(
        [Parameter(Mandatory = $true)][string]$SelectedMode,
        [Parameter(Mandatory = $true)][int64]$IncludedBytes
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("Packaged Build Manifest")
    $lines.Add("")
    $lines.Add(("Project root: {0}" -f $projectRoot))
    $lines.Add(("Package root folder name: {0}" -f $projectName))
    $lines.Add(("Packaging mode: {0}" -f $SelectedMode))
    $lines.Add(("Included source size: {0}" -f (Format-Bytes -Bytes $IncludedBytes)))
    $lines.Add(("Generated at: {0}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")))
    $lines.Add("")
    $lines.Add("Included directories:")
    foreach ($relativeDirectory in $includeDirectories) {
        $lines.Add((" - {0}" -f $relativeDirectory))
    }
    $lines.Add("")
    $lines.Add("Included root files:")
    foreach ($relativeFile in $includeFiles) {
        $lines.Add((" - {0}" -f $relativeFile))
    }
    $lines.Add("")
    $lines.Add("Cleanup removals after copy:")
    foreach ($relativePath in $cleanupPaths) {
        $lines.Add((" - {0}" -f $relativePath))
    }
    $lines.Add("")
    $lines.Add("Excluded package paths:")
    foreach ($relativePath in $excludedPackagePaths) {
        $lines.Add((" - {0}" -f $relativePath))
    }
    $lines.Add("")
    $lines.Add("Recursive cleanup file names:")
    foreach ($fileName in $cleanupRecursiveFileNames) {
        $lines.Add((" - {0}" -f $fileName))
    }
    $lines.Add("")
    $lines.Add("Recursive cleanup directory names:")
    foreach ($directoryName in $cleanupRecursiveDirectoryNames) {
        $lines.Add((" - {0}" -f $directoryName))
    }

    return ($lines -join [Environment]::NewLine) + [Environment]::NewLine
}

function Write-MetadataFiles {
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$SelectedMode,
        [Parameter(Mandatory = $true)][int64]$IncludedBytes
    )

    $playerReadmePath = Join-Path $RootPath "PLAYER_RELEASE_README.txt"
    $buildManifestPath = Join-Path $RootPath "PACKAGED_BUILD_MANIFEST.txt"
    $modCreditsPath = Join-Path $RootPath "PACKAGED_MOD_CREDITS.txt"

    Set-Content -LiteralPath $playerReadmePath -Value (New-PlayerReadmeContent) -Encoding UTF8
    Set-Content -LiteralPath $buildManifestPath -Value (New-ManifestContent -SelectedMode $SelectedMode -IncludedBytes $IncludedBytes) -Encoding UTF8
    Set-Content -LiteralPath $modCreditsPath -Value (New-ModCreditsContent) -Encoding UTF8
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

function Remove-TemporaryMetadataFiles {
    param([Parameter(Mandatory = $true)][string]$RootPath)

    foreach ($fileName in $temporaryMetadataFiles) {
        $fullPath = Join-Path $RootPath $fileName
        if (Test-Path -LiteralPath $fullPath) {
            Remove-Item -LiteralPath $fullPath -Force
        }
    }
}

function Build-StageDirectory {
    param(
        [Parameter(Mandatory = $true)][string]$StageRootPath,
        [Parameter(Mandatory = $true)][string]$PackageRootPath,
        [Parameter(Mandatory = $true)][int64]$IncludedBytes
    )

    Write-Host ("Creating staged package folder at {0}" -f $StageRootPath)
    Ensure-CleanDirectory -Path $StageRootPath
    New-Item -ItemType Directory -Path $PackageRootPath -Force | Out-Null

    foreach ($relativeDirectory in $includeDirectories) {
        Write-Host ("Copying directory: {0}" -f $relativeDirectory)
        Copy-DirectoryTree -SourceRelative $relativeDirectory -DestinationRoot $PackageRootPath
    }

    Write-Host "Copying root files"
    Copy-IncludedFiles -DestinationRoot $PackageRootPath
    Remove-CleanupPaths -RootPath $PackageRootPath
    Apply-PublicPackageSanitization -RootPath $PackageRootPath
    Write-MetadataFiles -RootPath $PackageRootPath -SelectedMode $Mode -IncludedBytes $IncludedBytes
}

function Build-ArchiveFromSource {
    param([Parameter(Mandatory = $true)][int64]$IncludedBytes)

    if (-not (Test-Path -LiteralPath $sevenZipPath)) {
        throw "7z.exe was not found at $sevenZipPath"
    }

    $parentDirectory = Split-Path -Parent $projectRoot
    $parentOutputRoot = if ($outputRootFull.StartsWith($parentDirectory, [System.StringComparison]::OrdinalIgnoreCase)) {
        $outputRootFull
    } else {
        $outputRootFull
    }

    Write-MetadataFiles -RootPath $projectRoot -SelectedMode $Mode -IncludedBytes $IncludedBytes

    $archiveItems = @()
    foreach ($relativeDirectory in $includeDirectories) {
        $archiveItems += ("{0}\{1}" -f $projectName, $relativeDirectory)
    }
    foreach ($relativeFile in $includeFiles) {
        $archiveItems += ("{0}\{1}" -f $projectName, $relativeFile)
    }
    foreach ($fileName in $temporaryMetadataFiles) {
        $archiveItems += ("{0}\{1}" -f $projectName, $fileName)
    }

    $excludeArgs = @(
        "-x!{0}\Data\.idea" -f $projectName,
        "-x!{0}\Data\.idea\*" -f $projectName,
        "-x!{0}\Data\.DS_Store" -f $projectName,
        "-x!{0}\Data\sprites\sprites_rate_limit.log" -f $projectName,
        "-x!{0}\Mods\mod_manager_state.json" -f $projectName,
        "-x!{0}\Mods\compat_report.txt" -f $projectName,
        "-x!{0}\Mods\autoplay_bot\data\cache" -f $projectName,
        "-x!{0}\Mods\autoplay_bot\data\cache\*" -f $projectName,
        "-x!{0}\Mods\autoplay_bot\logs" -f $projectName,
        "-x!{0}\Mods\autoplay_bot\logs\*" -f $projectName,
        "-x!{0}\Mods\autoplay_bot\data\state*.json" -f $projectName,
        "-x!{0}\Mods\custom_species_framework\checkpoints" -f $projectName,
        "-x!{0}\Mods\custom_species_framework\checkpoints\*" -f $projectName,
        "-x!{0}\Mods\custom_species_framework\framework_debug.log" -f $projectName,
        "-x!{0}\Mods\custom_species_framework\creator\*.log" -f $projectName,
        "-x!{0}\Mods\custom_species_framework\creator\_job_state.json" -f $projectName,
        "-x!{0}\Mods\custom_species_framework\creator\_creator_server_url.txt" -f $projectName,
        "-x!{0}\Mods\custom_species_framework\creator\edge_dom.txt" -f $projectName,
        "-x!{0}\Mods\custom_species_framework\importer\state\import_state.json" -f $projectName,
        "-x!{0}\Mods\custom_species_framework\importer\import_output\import.log" -f $projectName,
        "-x!{0}\KIFM\platinum_uuids.txt" -f $projectName,
        "-x!{0}\KIFM\discord_ids.txt" -f $projectName,
        "-x!{0}\KIFM\pending_discord_link.txt" -f $projectName,
        "-x!{0}\KIFM\coop_debug.log" -f $projectName,
        "-x!{0}\KIFM\pvp_wins.txt" -f $projectName,
        "-x!{0}\KIFM\discord_link.log" -f $projectName,
        "-xr!{0}\__pycache__" -f $projectName,
        "-xr!{0}\Thumbs.db" -f $projectName,
        "-xr!{0}\*.DS_Store" -f $projectName
    )

    New-Item -ItemType Directory -Path $parentOutputRoot -Force | Out-Null
    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }

    Write-Host ("Creating archive at {0}" -f $archivePath)

    Push-Location $parentDirectory
    try {
        & $sevenZipPath a -t7z -mx=3 -mmt=on $archivePath @archiveItems @excludeArgs | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "7z archive creation failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
        Remove-TemporaryMetadataFiles -RootPath $projectRoot
    }
}

function Build-ArchiveFromStage {
    if (-not (Test-Path -LiteralPath $sevenZipPath)) {
        throw "7z.exe was not found at $sevenZipPath"
    }

    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }

    Write-Host ("Creating archive from staged folder at {0}" -f $archivePath)

    Push-Location $stageRoot
    try {
        & $sevenZipPath a -t7z -mx=3 -mmt=on $archivePath $projectName | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "7z archive creation from staged folder failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        Pop-Location
    }
}

function Remove-ArchivePaths {
    param([Parameter(Mandatory = $true)][string]$ArchiveFilePath)

    if (-not (Test-Path -LiteralPath $ArchiveFilePath)) {
        throw "Archive does not exist: $ArchiveFilePath"
    }

    $archiveCleanupItems = @(
        ("{0}\Data\.idea" -f $projectName),
        ("{0}\Data\.idea\*" -f $projectName),
        ("{0}\Data\.DS_Store" -f $projectName),
        ("{0}\Data\sprites\sprites_rate_limit.log" -f $projectName),
        ("{0}\Mods\mod_manager_state.json" -f $projectName),
        ("{0}\Mods\compat_report.txt" -f $projectName),
        ("{0}\KIFM\platinum_uuids.txt" -f $projectName),
        ("{0}\KIFM\discord_ids.txt" -f $projectName),
        ("{0}\KIFM\pending_discord_link.txt" -f $projectName),
        ("{0}\KIFM\coop_debug.log" -f $projectName),
        ("{0}\KIFM\pvp_wins.txt" -f $projectName),
        ("{0}\KIFM\discord_link.log" -f $projectName),
        ("{0}\Mods\custom_species_framework" -f $projectName),
        ("{0}\Mods\custom_species_framework\*" -f $projectName),
        ("{0}\Data\encounters.json" -f $projectName),
        ("{0}\Data\starter_sets.json" -f $projectName),
        ("{0}\Data\trainer_hooks.json" -f $projectName),
        ("{0}\Data\species" -f $projectName),
        ("{0}\Data\species\*" -f $projectName),
        ("{0}\Graphics\Battlers\1202" -f $projectName),
        ("{0}\Graphics\Battlers\1202\*" -f $projectName),
        ("{0}\Graphics\Battlers\1203" -f $projectName),
        ("{0}\Graphics\Battlers\1203\*" -f $projectName),
        ("{0}\Graphics\Battlers\1204" -f $projectName),
        ("{0}\Graphics\Battlers\1204\*" -f $projectName),
        ("{0}\Graphics\Battlers\1205" -f $projectName),
        ("{0}\Graphics\Battlers\1205\*" -f $projectName),
        ("{0}\Graphics\Battlers\1206" -f $projectName),
        ("{0}\Graphics\Battlers\1206\*" -f $projectName),
        ("{0}\Graphics\CustomBattlers\indexed\1202" -f $projectName),
        ("{0}\Graphics\CustomBattlers\indexed\1202\*" -f $projectName),
        ("{0}\Graphics\CustomBattlers\indexed\1203" -f $projectName),
        ("{0}\Graphics\CustomBattlers\indexed\1203\*" -f $projectName),
        ("{0}\Graphics\CustomBattlers\indexed\1204" -f $projectName),
        ("{0}\Graphics\CustomBattlers\indexed\1204\*" -f $projectName),
        ("{0}\Graphics\CustomBattlers\indexed\1205" -f $projectName),
        ("{0}\Graphics\CustomBattlers\indexed\1205\*" -f $projectName),
        ("{0}\Graphics\CustomBattlers\indexed\1206" -f $projectName),
        ("{0}\Graphics\CustomBattlers\indexed\1206\*" -f $projectName),
        ("{0}\Graphics\Icons\icon1202.png" -f $projectName),
        ("{0}\Graphics\Icons\icon1203.png" -f $projectName),
        ("{0}\Graphics\Icons\icon1204.png" -f $projectName),
        ("{0}\Graphics\Icons\icon1205.png" -f $projectName),
        ("{0}\Graphics\Icons\icon1206.png" -f $projectName),
        ("{0}\Graphics\Pokemon\Back\CSF_AQUALITH.png" -f $projectName),
        ("{0}\Graphics\Pokemon\Back\CSF_CINDRAKE.png" -f $projectName),
        ("{0}\Graphics\Pokemon\Back\CSF_VERDALYK.png" -f $projectName),
        ("{0}\Graphics\Pokemon\Front\CSF_AQUALITH.png" -f $projectName),
        ("{0}\Graphics\Pokemon\Front\CSF_CINDRAKE.png" -f $projectName),
        ("{0}\Graphics\Pokemon\Front\CSF_VERDALYK.png" -f $projectName),
        ("{0}\Graphics\Pokemon\Icons\CSF_AQUALITH.png" -f $projectName),
        ("{0}\Graphics\Pokemon\Icons\CSF_CINDRAKE.png" -f $projectName),
        ("{0}\Graphics\Pokemon\Icons\CSF_VERDALYK.png" -f $projectName),
        ("{0}\Graphics\Pokemon\Icons\CSF_SANDSHREW_GLACIAL.png" -f $projectName),
        ("{0}\Graphics\Pokemon\Icons\CSF_SANDSLASH_GLACIAL.png" -f $projectName)
    )

    & $sevenZipPath d $ArchiveFilePath @archiveCleanupItems | Out-Null
    if (($LASTEXITCODE -ne 0) -and ($LASTEXITCODE -ne 1)) {
        throw "7z archive cleanup failed with exit code $LASTEXITCODE"
    }
}

$includedBytes = Get-DirectorySizeBytes -RelativeDirectories $includeDirectories
$freeBytes = Get-FreeSpaceBytes -Path $outputRootFull
$stageRequiresSpace = $true
$archiveRequiresSevenZip = $Mode -in @("archive", "both")

Write-Host ("Selected mode: {0}" -f $Mode)
Write-Host ("Included source size: {0}" -f (Format-Bytes -Bytes $includedBytes))
Write-Host ("Free space on output drive: {0}" -f (Format-Bytes -Bytes $freeBytes))

if ($stageRequiresSpace -and ($freeBytes -lt ($includedBytes + 2GB))) {
    throw "Not enough free space to safely create a staged build. Use -Mode archive or free more disk space."
}

if ($archiveRequiresSevenZip -and (-not (Test-Path -LiteralPath $sevenZipPath))) {
    throw "Archive mode requires 7z.exe at $sevenZipPath"
}

New-Item -ItemType Directory -Path $outputRootFull -Force | Out-Null
Set-Content -LiteralPath $manifestPath -Value (New-ManifestContent -SelectedMode $Mode -IncludedBytes $includedBytes) -Encoding UTF8

switch ($Mode) {
    "archive" {
        Build-StageDirectory -StageRootPath $stageRoot -PackageRootPath $packageRoot -IncludedBytes $includedBytes
        Build-ArchiveFromStage
        if (Test-Path -LiteralPath $stageRoot) {
            Remove-Item -LiteralPath $stageRoot -Recurse -Force
        }
    }
    "stage" {
        Build-StageDirectory -StageRootPath $stageRoot -PackageRootPath $packageRoot -IncludedBytes $includedBytes
    }
    "both" {
        Build-StageDirectory -StageRootPath $stageRoot -PackageRootPath $packageRoot -IncludedBytes $includedBytes
        Build-ArchiveFromStage
    }
}

if ($Mode -in @("archive", "both")) {
    $hash = Get-FileHash -LiteralPath $archivePath -Algorithm SHA256
    Set-Content -LiteralPath $hashPath -Value ("{0} *{1}" -f $hash.Hash.ToLowerInvariant(), (Split-Path -Leaf $archivePath)) -Encoding ASCII
}

$summaryLines = New-Object System.Collections.Generic.List[string]
$summaryLines.Add(("Packaging mode: {0}" -f $Mode))
$summaryLines.Add(("Manifest: {0}" -f $manifestPath))
if ($Mode -in @("stage", "both")) {
    $summaryLines.Add(("Staged build: {0}" -f $stageRoot))
}
if ($Mode -in @("archive", "both")) {
    $archiveItem = Get-Item -LiteralPath $archivePath
    $summaryLines.Add(("Archive: {0}" -f $archiveItem.FullName))
    $summaryLines.Add(("Archive size: {0}" -f (Format-Bytes -Bytes $archiveItem.Length)))
    $summaryLines.Add(("SHA256: {0}" -f $hashPath))
}

$summaryText = ($summaryLines -join [Environment]::NewLine)
Write-Host ""
Write-Host $summaryText
