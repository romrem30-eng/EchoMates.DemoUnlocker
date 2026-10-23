# Echo Mates Demo - Mod Auto-Updater
# Queries GitHub Releases and updates DemoUnlockerMod.dll in seconds

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
Write-Host "      Echo Mates Demo - Mod Auto-Updater            " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Locate Game Directory
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
    Write-Host "Update aborted." -ForegroundColor Red
    Wait-Key
    exit 1
}

Write-Host "[+] Found game at: $gameDir" -ForegroundColor Green

$targetDll = Join-Path $gameDir "BepInEx\plugins\DemoUnlockerMod.dll"
$localVersion = "0.0.0"
if (Test-Path $targetDll) {
    $vi = (Get-Item $targetDll).VersionInfo
    if ($vi.FileVersion) {
        $localVersion = $vi.FileVersion.Trim()
    } elseif ($vi.ProductVersion) {
        $localVersion = $vi.ProductVersion.Trim()
    }
}
Write-Host "[*] Current installed mod version: v$localVersion" -ForegroundColor Gray
Write-Host ""

# 2. Check GitHub Releases
$repo = "romrem30-eng/EchoMates.DemoUnlocker"
$apiUrl = "https://api.github.com/repos/$repo/releases/latest"

Write-Host "[*] Checking for updates on GitHub ($repo)..." -ForegroundColor Cyan

$release = $null
try {
    # Use curl or Invoke-RestMethod with TLS 1.2+
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $headers = @{ "User-Agent" = "EchoMates-AutoUpdater" }
    $release = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10 -ErrorAction Stop
} catch {
    Write-Host "[WARNING] Could not check online release info: $_" -ForegroundColor Yellow
    Write-Host "Trying direct fallback download from GitHub..." -ForegroundColor Gray
}

$remoteTag = if ($release -and $release.tag_name) { $release.tag_name } else { "latest" }
$cleanRemote = $remoteTag.TrimStart('v').Trim()

$shouldUpdate = $false
if ($cleanRemote -ne "latest" -and $cleanRemote -ne $localVersion) {
    Write-Host "[!] A new version is available: $remoteTag (Current: v$localVersion)" -ForegroundColor Green
    $shouldUpdate = $true
} elseif ($localVersion -eq "0.0.0") {
    Write-Host "[!] Mod DLL is missing in plugins folder. Installing latest..." -ForegroundColor Yellow
    $shouldUpdate = $true
} else {
    Write-Host "[+] Your mod is up to date (v$localVersion)!" -ForegroundColor Green
    Write-Host "Do you want to re-download and force update anyway? (y/N)" -ForegroundColor Yellow
    $ans = Read-Host "Choice"
    if ($ans -match "^[yY]") {
        $shouldUpdate = $true
    }
}

if (-not $shouldUpdate) {
    Write-Host ""
    Write-Host "Everything is already up to date. Enjoy the game!" -ForegroundColor Green
    Write-Host ""
    Wait-Key
    exit 0
}

# 3. Check if game is running before replacing DLL
$proc = Get-Process -Name "Echo Mates" -ErrorAction SilentlyContinue
if ($proc) {
    Write-Host ""
    Write-Host "[WARNING] 'Echo Mates.exe' is currently running!" -ForegroundColor Yellow
    Write-Host "Please close the game now, then:" -ForegroundColor Yellow
    Wait-Key
}

# 4. Download latest DLL
Write-Host ""
Write-Host "[*] Downloading DemoUnlockerMod.dll ($remoteTag)..." -ForegroundColor Cyan

$downloadUrl = "https://github.com/$repo/releases/latest/download/DemoUnlockerMod.dll"
if ($release -and $release.assets) {
    $dllAsset = $release.assets | Where-Object { $_.name -eq "DemoUnlockerMod.dll" }
    if ($dllAsset -and $dllAsset.browser_download_url) {
        $downloadUrl = $dllAsset.browser_download_url
    }
}

$pluginDir = Split-Path -Parent $targetDll
if (-not (Test-Path $pluginDir)) {
    New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null
}

try {
    $tempFile = [System.IO.Path]::GetTempFileName()
    Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile -Headers @{ "User-Agent" = "EchoMates-AutoUpdater" } -ErrorAction Stop
    Copy-Item $tempFile $targetDll -Force
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
    Write-Host "[+] Download and replacement complete!" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "[ERROR] Failed to download update: $_" -ForegroundColor Red
    Write-Host "Direct download link: $downloadUrl" -ForegroundColor Yellow
    Write-Host ""
    Wait-Key
    exit 1
}

if ($release -and $release.body) {
    Write-Host ""
    Write-Host "--- Release Notes ($remoteTag) ---" -ForegroundColor White
    Write-Host $release.body -ForegroundColor Gray
    Write-Host "----------------------------------" -ForegroundColor White
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Green
Write-Host "   [SUCCESS] Mod updated successfully to $remoteTag! " -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Green
Write-Host ""
Wait-Key
