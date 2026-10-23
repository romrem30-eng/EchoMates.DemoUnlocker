# Echo Mates Demo - Full Game Unlocker Uninstaller
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

Write-Host "====================================================" -ForegroundColor Magenta
Write-Host "  Echo Mates Demo - Full Game Unlocker Uninstaller" -ForegroundColor Magenta
Write-Host "====================================================" -ForegroundColor Magenta
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
$packageRoot = Split-Path -Parent $PSScriptRoot
$candidates.Add((Split-Path -Parent $packageRoot))
$candidates.Add($packageRoot)

$steamReg = Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name 'SteamPath' -ErrorAction SilentlyContinue
if ($steamReg -and $steamReg.SteamPath) {
    $sp = $steamReg.SteamPath
    $candidates.Add((Join-Path $sp "steamapps\common\Echo Mates Demo"))

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

if (-not $gameDir) {
    Write-Host ""
    Write-Host "[!] Could not automatically find the game directory." -ForegroundColor Yellow
    Write-Host "Please drag and drop your 'Echo Mates Demo' folder here and press Enter:"
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
    Write-Host "[ERROR] Valid 'Echo Mates.exe' was not found." -ForegroundColor Red
    Write-Host "Uninstallation aborted." -ForegroundColor Red
    Write-Host ""
    Wait-Key
    exit 1
}

Write-Host ""
Write-Host "[+] Found game at: $gameDir" -ForegroundColor Green
Write-Host ""

# 3. Remove files
Write-Host "[*] Removing Mod and BepInEx loader..." -ForegroundColor Cyan

$filesToRemove = @(
    (Join-Path $gameDir "winhttp.dll"),
    (Join-Path $gameDir "doorstop_config.ini"),
    (Join-Path $gameDir ".doorstop_version"),
    (Join-Path $gameDir "BepInEx\plugins\DemoUnlockerMod.dll"),
    (Join-Path $gameDir "BepInEx\config\com.modder.echomates.sandbox.cfg")
)

foreach ($f in $filesToRemove) {
    if (Test-Path $f) {
        Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
        Write-Host "  [-] Removed: $(Split-Path -Leaf $f)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Do you want to completely delete the 'BepInEx' folder as well? (Y/N)" -ForegroundColor Yellow
$response = Read-Host "Choice"
if ($response -match "^[yY]") {
    $bepPath = Join-Path $gameDir "BepInEx"
    if (Test-Path $bepPath) {
        Remove-Item -LiteralPath $bepPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  [-] Removed entire BepInEx folder." -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "   [SUCCESS] Game restored to original state!        " -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Wait-Key
