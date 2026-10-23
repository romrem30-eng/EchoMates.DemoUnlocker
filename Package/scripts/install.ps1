# Echo Mates Demo - Full Game Unlocker Installer
# Requires PowerShell 5.1+ (built into Windows 10/11)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Wait-Key {
    Write-Host "Press Enter to continue..." -ForegroundColor Gray
    if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
        try {
            $null = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            return
        } catch {}
    }
    $null = Read-Host
}

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "   Echo Mates Demo - Full Game Unlocker Installer" -ForegroundColor Cyan
Write-Host "                   Version 1.2.0" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check if game is running
$proc = Get-Process -Name "Echo Mates" -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host "[WARNING] 'Echo Mates.exe' is currently running!" -ForegroundColor Yellow
    Write-Host "Please close the game now, then:" -ForegroundColor Yellow
    Wait-Key
}

# 2. Locate Game Directory
Write-Host "[*] Searching for Echo Mates Demo installation..." -ForegroundColor Gray

$candidates = [System.Collections.Generic.List[string]]::new()

# Check parent of current script folder
$packageRoot = Split-Path -Parent $PSScriptRoot
$candidates.Add((Split-Path -Parent $packageRoot))
$candidates.Add($packageRoot)

# Check Steam registry
$steamReg = Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name 'SteamPath' -ErrorAction SilentlyContinue
if ($steamReg -and $steamReg.SteamPath) {
    $sp = $steamReg.SteamPath
    $candidates.Add((Join-Path $sp "steamapps\common\Echo Mates Demo"))

    # Parse libraryfolders.vdf
    $vdf = Join-Path $sp "steamapps\libraryfolders.vdf"
    if (Test-Path $vdf) {
        $lines = Get-Content -LiteralPath $vdf -ErrorAction SilentlyContinue
        foreach ($line in $lines) {
            if ($line -match '"path"\s+"([^"]+)"') {
                $libPath = $matches[1] -replace '\\\\', '\'
                $candidates.Add((Join-Path $libPath "steamapps\common\Echo Mates Demo"))
            }
        }
    }
}

# Check common drives
foreach ($drive in [System.IO.DriveInfo]::GetDrives()) {
    if ($drive.IsReady) {
        $root = $drive.RootDirectory.FullName
        $candidates.Add((Join-Path $root "SteamLibrary\steamapps\common\Echo Mates Demo"))
        $candidates.Add((Join-Path $root "Program Files (x86)\Steam\steamapps\common\Echo Mates Demo"))
        $candidates.Add((Join-Path $root "Program Files\Steam\steamapps\common\Echo Mates Demo"))
        $candidates.Add((Join-Path $root "Games\Steam\steamapps\common\Echo Mates Demo"))
        $candidates.Add((Join-Path $root "Games\Echo Mates Demo"))
    }
}

$gameDir = $null
foreach ($c in $candidates) {
    if ($c -and (Test-Path (Join-Path $c "Echo Mates.exe"))) {
        $gameDir = (Resolve-Path $c).Path
        break
    }
}

# If not found automatically, prompt user
if (-not $gameDir) {
    Write-Host ""
    Write-Host "[!] Could not automatically find the game directory." -ForegroundColor Yellow
    Write-Host "Please drag and drop your 'Echo Mates Demo' folder here (or paste the path) and press Enter:"
    $userInput = Read-Host "Game Path"
    if ($userInput) {
        $cleanPath = $userInput.Trim('"', "'", ' ')
        if (Test-Path (Join-Path $cleanPath "Echo Mates.exe")) {
            $gameDir = (Resolve-Path $cleanPath).Path
        } elseif (Test-Path $cleanPath -and ($cleanPath -match "Echo Mates\.exe$")) {
            $gameDir = (Split-Path -Parent (Resolve-Path $cleanPath).Path)
        }
    }
}

if (-not $gameDir -or -not (Test-Path (Join-Path $gameDir "Echo Mates.exe"))) {
    Write-Host ""
    Write-Host "[ERROR] Valid 'Echo Mates.exe' was not found in the specified path." -ForegroundColor Red
    Write-Host "Installation aborted." -ForegroundColor Red
    Write-Host ""
    Wait-Key
    exit 1
}

Write-Host ""
Write-Host "[+] Found game at: $gameDir" -ForegroundColor Green
Write-Host ""

# 3. Source files directory
$sourceDir = Join-Path $packageRoot "files"
if (-not (Test-Path $sourceDir)) {
    Write-Host "[ERROR] 'files' folder is missing from the package!" -ForegroundColor Red
    Write-Host "Make sure you extracted the full zip archive before running installer." -ForegroundColor Red
    Write-Host ""
    Wait-Key
    exit 1
}

# 4. Copying files
Write-Host "[*] Installing BepInEx and Demo Unlocker Mod..." -ForegroundColor Cyan

try {
    # Ensure target folders exist
    New-Item -ItemType Directory -Path (Join-Path $gameDir "BepInEx\core") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $gameDir "BepInEx\config") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $gameDir "BepInEx\plugins") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $gameDir "BepInEx\patchers") -Force | Out-Null

    # Root files
    Copy-Item (Join-Path $sourceDir "winhttp.dll") (Join-Path $gameDir "winhttp.dll") -Force
    Copy-Item (Join-Path $sourceDir "doorstop_config.ini") (Join-Path $gameDir "doorstop_config.ini") -Force
    if (Test-Path (Join-Path $sourceDir ".doorstop_version")) {
        Copy-Item (Join-Path $sourceDir ".doorstop_version") (Join-Path $gameDir ".doorstop_version") -Force
    }

    # BepInEx directories
    Copy-Item (Join-Path $sourceDir "BepInEx\core\*") (Join-Path $gameDir "BepInEx\core\") -Recurse -Force
    Copy-Item (Join-Path $sourceDir "BepInEx\config\*") (Join-Path $gameDir "BepInEx\config\") -Recurse -Force
    Copy-Item (Join-Path $sourceDir "BepInEx\plugins\DemoUnlockerMod.dll") (Join-Path $gameDir "BepInEx\plugins\DemoUnlockerMod.dll") -Force

    Write-Host "[+] All files copied successfully!" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "[ERROR] Failed to copy files: $_" -ForegroundColor Red
    Write-Host "Please ensure you have write permissions or run as Administrator." -ForegroundColor Yellow
    Write-Host ""
    Wait-Key
    exit 1
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "   [SUCCESS] Mod & BepInEx installed successfully!   " -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Features Unlocked:" -ForegroundColor White
Write-Host "  [x] Campaign unlocked up to Floor 99 (Endless Descent)" -ForegroundColor Gray
Write-Host "  [x] All Blueprints, Base Buildings & Upgrades unlocked" -ForegroundColor Gray
Write-Host "  [x] Research table & Chips restrictions removed" -ForegroundColor Gray
Write-Host "  [x] Game telemetry fully disabled (Stealth mode)" -ForegroundColor Gray
Write-Host "  [x] Optional Dev Menu (F1) available via config" -ForegroundColor Gray
Write-Host ""
Write-Host "Mod Config Location:" -ForegroundColor White
Write-Host "  BepInEx\config\com.modder.echomates.sandbox.cfg" -ForegroundColor Yellow
Write-Host ""
Write-Host "You can now launch 'Echo Mates Demo' directly from Steam!" -ForegroundColor Cyan
Write-Host ""
Wait-Key
