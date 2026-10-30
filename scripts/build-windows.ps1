<#
R.E.P.O. 0.5.0 in VR on a Meta Quest, standalone, built on Windows from your own Steam copy of the game.

    powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1
    powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -NoInstall
    powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -Game "D:\SteamLibrary\steamapps\common\REPO"
    powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -Force   (build even when the check of a new game version finds problems)
    powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -RepoXRDll <RepoXR.dll>   (your own RepoXR.dll instead
        of the kit's, docs/build-repoxr.md)
    powershell -ExecutionPolicy Bypass -File scripts\build-windows.ps1 -CodeOnly   (only the code changed: reuse the last
        APK's packed game data, about a third of the time; a full build when there is none)

What it does (work folder C:\RepoQuest; an ASCII path without spaces, Unity and Gradle break on others):
  1. checks Unity 6000.3.17f1 with Android Build Support (opens Unity Hub on it when it is missing)
  2. .NET 8 SDK into %LOCALAPPDATA%\Microsoft\dotnet (Microsoft's dotnet-install.ps1), if there is none yet
  3. the kit (scripts, Unity tooling, prebuilt RepoXR/SteamShim/Standalone; no game files) from this fork's kit branch,
     checked against its SHA-256
  4. the builder from this checkout (builder\QuestBuilder.Cli); a game version the kit was not tested with is checked
     first (QuestBuilder.Cli check: patches, IL, references, packages; minutes, no Unity); then the build: AssetRipper export, RepoXR baked into
     the game's code, Unity -> APK. The game is found in your Steam libraries (or -Game). First build 1-1.5 hours on a
     fast PC, 3-5 hours on a slower one; about 60 GB of free space
  5. adb install on the headset (USB cable, developer mode)
Do not share the APK: it contains the game's files.
#>
param(
    [switch]$NoInstall,
    [switch]$Force,
    [switch]$CodeOnly,
    [string]$Game,
    [string]$RepoXRDll,
    [string]$Unity = "$env:ProgramFiles\Unity\Hub\Editor\6000.3.17f1",
    [string]$Workspace = "C:\RepoQuest"
)
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"   # Invoke-WebRequest is many times slower with the progress bar

$Version = "1.0.7-qc27"
$UnityVersion = "6000.3.17f1"
$UnityChangeset = "cf0352b38e81"
$KitUrl = "https://github.com/crimecock/repo-quest-vr/raw/kit/repoquest-kit-$Version.zip"
$KitSha = "f4a0aa1cc4f01cc41960d0c94bd1384b0bc0fecad217d5e680632e6017770128"
$Src = Split-Path -Parent $PSScriptRoot

function Say($text) { Write-Host "`n== $text" -ForegroundColor Cyan }
function Die($text) { Write-Host "ERROR: $text" -ForegroundColor Red; exit 1 }

if ($Workspace -notmatch '^[A-Za-z]:\\[A-Za-z0-9\\._-]*$') { Die "the work folder must be an ASCII path without spaces: $Workspace (use -Workspace)" }
New-Item -ItemType Directory -Force -Path $Workspace | Out-Null
$drive = (Get-Item $Workspace).PSDrive
if ($drive.Free -lt 60GB) { Write-Host "warning: only $([math]::Round($drive.Free / 1GB)) GB free on $($drive.Name):, the build needs about 60 GB" -ForegroundColor Yellow }

Say "Unity $UnityVersion with Android"
if (-not (Test-Path "$Unity\Editor\Unity.exe")) {
    Write-Host "   Unity $UnityVersion is not installed: opening Unity Hub on it. Tick Android Build Support with OpenJDK and"
    Write-Host "   Android SDK & NDK Tools, install, then run this script again"
    Start-Process "unityhub://$UnityVersion/$UnityChangeset" -ErrorAction SilentlyContinue
    Die "Unity $UnityVersion not found in $Unity (or pass -Unity <folder with Editor\Unity.exe>)"
}
if (-not (Test-Path "$Unity\Editor\Data\PlaybackEngines\AndroidPlayer")) {
    Die "Unity has no Android Build Support: Unity Hub > Installs > $UnityVersion > Add modules > Android Build Support (with OpenJDK and Android SDK & NDK Tools)"
}
Write-Host "   $Unity"

Say ".NET 8 SDK"
$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
$hasSdk = $dotnet -and ((& dotnet --list-sdks) -match '^8\.')
if (-not $hasSdk) {
    $dotnetDir = "$env:LOCALAPPDATA\Microsoft\dotnet"
    Invoke-WebRequest https://dot.net/v1/dotnet-install.ps1 -OutFile "$Workspace\dotnet-install.ps1"
    & powershell -ExecutionPolicy Bypass -File "$Workspace\dotnet-install.ps1" -Channel 8.0 -InstallDir $dotnetDir
    $env:PATH = "$dotnetDir;$env:PATH"
    $env:DOTNET_ROOT = $dotnetDir
}
$env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"; $env:DOTNET_NOLOGO = "1"
(& dotnet --list-sdks) -match '^8\.' | Select-Object -Last 1

Say "kit $Version"
$kitZip = "$Workspace\downloads\repoquest-kit-$Version.zip"
New-Item -ItemType Directory -Force -Path "$Workspace\downloads" | Out-Null
if (-not (Test-Path $kitZip)) { Invoke-WebRequest $KitUrl -OutFile "$kitZip.part"; Move-Item "$kitZip.part" $kitZip }
$got = (Get-FileHash $kitZip -Algorithm SHA256).Hash.ToLower()
if ($got -ne $KitSha) { Remove-Item $kitZip; Die "the kit zip is damaged (sha256 $got); run the script again" }
$kit = "$Workspace\kit-$Version"
if (-not (Test-Path "$kit\kit.json") -or ((Get-Content "$kit\.zip-sha" -ErrorAction SilentlyContinue) -ne $KitSha)) {
    if (Test-Path $kit) { Remove-Item -Recurse -Force $kit }
    Expand-Archive $kitZip -DestinationPath $kit
    Set-Content "$kit\.zip-sha" $KitSha
}
Write-Host "   $kit"
if ($RepoXRDll) {
    # Your own RepoXR.dll (the PC fork's build, or scripts/prepare-repoxr.sh): a copy of the kit with it
    if (-not (Test-Path $RepoXRDll)) { Die "-RepoXRDll: $RepoXRDll not found" }
    $custom = "${kit}-custom"
    if (Test-Path $custom) { Remove-Item -Recurse -Force $custom }
    Copy-Item -Recurse $kit $custom
    Copy-Item -Force $RepoXRDll "$custom\prebuilt\repoxr\RepoXR.dll"
    $kit = $custom
    Write-Host "   with your RepoXR.dll: $RepoXRDll"
}

Say "builder (QuestBuilder.Cli)"
& dotnet build -c Release -nologo -v quiet "$Src\builder\QuestBuilder.Cli"
if ($LASTEXITCODE -ne 0) { Die "the builder did not build (see the messages above)" }
$cli = "$Src\builder\QuestBuilder.Cli\bin\Release\net8.0\QuestBuilder.Cli.exe"

$common = @("--kit", $kit, "--workspace", "$Workspace\work", "--unity", $Unity)
if ($Game) { $common += @("--game", $Game) }
# A game version the kit was not tested with: check it first (a few minutes, no Unity) instead of finding out an hour
# into the build. -Force builds anyway
& $cli check --quick @common
if ($LASTEXITCODE -ne 0) {
    Say "this game version is new to kit ${Version}: checking it first (a few minutes, no Unity)"
    & $cli check @common
    if ($LASTEXITCODE -ne 0) {
        if (-not $Force) { Die "the check found problems with this game version (report: $Workspace\work\check-report.md). Wait for an update of this repository, or add -Force to build anyway" }
        Write-Host "   -Force: building anyway"
    }
}

Say "building the APK (first time 1-1.5 hours or more; logs in $Workspace\work\logs)"
$buildArgs = @("build", "--headset", "quest") + $common
if ($CodeOnly) { $buildArgs += "--scripts-only" }
& $cli @buildArgs
if ($LASTEXITCODE -ne 0) { Die "the build failed (see $Workspace\work\logs\builder.log and unity-build.log)" }
$apk = Get-ChildItem "$Workspace\work\build\*.apk" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $apk) { Die "no APK in $Workspace\work\build (see $Workspace\work\logs)" }
Write-Host "   APK: $($apk.FullName)"

if ($NoInstall) { exit 0 }
Say "installing on the headset"
$adb = "$Unity\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\platform-tools\adb.exe"
if (-not (Test-Path $adb)) { $adb = (Get-Command adb -ErrorAction SilentlyContinue).Source }
if (-not $adb) { Die "adb not found; install the APK yourself: $($apk.FullName)" }
& $adb start-server | Out-Null
& $adb get-state 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "   no headset: connect the Quest by cable, allow USB debugging in the headset, then run:"
    Write-Host "   & `"$adb`" install -r `"$($apk.FullName)`""
    Write-Host "   problems: docs\install.md"
    exit 0
}
# a sleeping Quest accepts the APK but installs it only when it wakes
& $adb shell input keyevent KEYCODE_WAKEUP 2>$null | Out-Null
& $adb install -r $apk.FullName
if ($LASTEXITCODE -ne 0) {
    Write-Host "   install failed; the APK is built, install it by hand: docs\install.md"
    Write-Host "   (INSTALL_FAILED_UPDATE_INCOMPATIBLE: reinstall keeping the saves, as described there)"
    exit 1
}
Write-Host "   done: in the headset, Library > Unknown Sources > R.E.P.O."
