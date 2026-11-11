<#
.SYNOPSIS
  Builds the Android core (gomobile core.aar) and Flutter APKs locally on Windows.
.DESCRIPTION
  Redirects heavy Gradle/Pub/Go caches away from C:\ (when $ToolsRoot is on
  another drive such as E:\arman-dev-tools) so a tight system drive never fills up.
  Requires: Go 1.27+, gomobile/gobind, Flutter 3.47+, JDK 17/21, and Android SDK + NDK 30.0.16248370.
#>
param(
    [string]$ToolsRoot = "E:\arman-dev-tools"
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$match = Select-String -Path "$root\app\pubspec.yaml" -Pattern '^version:\s*(\d+\.\d+\.\d+)'
if (-not $match) { throw 'No version in app\pubspec.yaml' }
$version = $match.Matches[0].Groups[1].Value
$out = "$root\dist\Arman-VPN-Mobile-$version-android"

if (Test-Path $ToolsRoot) {
    if (-not $env:ANDROID_HOME -and (Test-Path "$ToolsRoot\android-sdk")) {
        $env:ANDROID_HOME = "$ToolsRoot\android-sdk"
    }
    if (-not $env:JAVA_HOME -and (Test-Path "$ToolsRoot\jdk")) {
        $env:JAVA_HOME = "$ToolsRoot\jdk"
    }
    if (-not $env:GOPATH) { $env:GOPATH = "$ToolsRoot\gopath" }
    if (-not $env:GOMODCACHE) { $env:GOMODCACHE = "$ToolsRoot\gomodcache" }
    if (-not $env:GOCACHE) { $env:GOCACHE = "$ToolsRoot\gocache" }
    if (-not $env:PUB_CACHE) { $env:PUB_CACHE = "$ToolsRoot\pub-cache" }
    if (-not $env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME = "$ToolsRoot\gradle" }
}

if (-not $env:ANDROID_HOME) { $env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk" }
$ndk = (Select-String -Path "$root\app\android\app\build.gradle.kts" -Pattern 'ndkVersion\s*=\s*"([^"]+)"').Matches[0].Groups[1].Value
if (-not $env:ANDROID_NDK_HOME) { $env:ANDROID_NDK_HOME = "$env:ANDROID_HOME\ndk\$ndk" }
if (-not $env:JAVA_HOME -and (Test-Path "$env:ProgramFiles\Android\Android Studio\jbr")) {
    $env:JAVA_HOME = "$env:ProgramFiles\Android\Android Studio\jbr"
}

foreach ($tool in @('go', 'flutter')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Required tool '$tool' not found on PATH. Either use the free GitHub Actions workflow (.github/workflows/build-apk.yml) or install Go + Flutter + Android SDK/NDK first."
    }
}

$env:PATH = "$(go env GOPATH)\bin;$env:JAVA_HOME\bin;$env:PATH"
if (-not $env:GOTOOLCHAIN) {
    $need = (Select-String -Path "$root\core\go.mod" -Pattern '^go\s+(\S+)').Matches[0].Groups[1].Value
    $env:GOTOOLCHAIN = 'local'
    $have = (go env GOVERSION) -replace '^go', ''
    if ([version]$have -lt [version]$need) { $env:GOTOOLCHAIN = "go$need+auto" }
}

New-Item -ItemType Directory -Force -Path "$root\app\android\app\libs" | Out-Null
$ldflags = "-s -w -X github.com/armanlife/arman-vpn-client/core/internal/version.Current=$version"

Push-Location "$root\core"
try {
    gomobile bind -target=android -androidapi 24 -trimpath `
        -ldflags $ldflags `
        -o ..\app\android\app\libs\core.aar ./mobile
    if ($LASTEXITCODE -ne 0) { throw 'gomobile bind failed' }
} finally { Pop-Location }

Push-Location "$root\app"
try {
    flutter pub get --offline
    if ($LASTEXITCODE -ne 0) { flutter pub get }
    if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
    flutter build apk --release --no-pub --split-per-abi --dart-define=APP_VERSION=$version
    if ($LASTEXITCODE -ne 0) { throw 'flutter build failed' }
    flutter build apk --release --no-pub --dart-define=APP_VERSION=$version
    if ($LASTEXITCODE -ne 0) { throw 'flutter universal build failed' }
} finally { Pop-Location }

New-Item -ItemType Directory -Force $out | Out-Null
foreach ($apk in Get-ChildItem "$root\app\build\app\outputs\flutter-apk\app-*-release.apk") {
    $name = $apk.Name -replace '^app-', "Arman-VPN-Mobile-$version-" -replace '-release', ''
    Copy-Item $apk.FullName (Join-Path $out $name) -Force
}
Copy-Item "$root\app\build\app\outputs\flutter-apk\app-release.apk" (Join-Path $out "Arman-VPN-Mobile-$version-universal.apk") -Force
Get-ChildItem $out | ForEach-Object { Write-Host ("Built {0} ({1:N1} MB)" -f $_.FullName, ($_.Length / 1MB)) }
