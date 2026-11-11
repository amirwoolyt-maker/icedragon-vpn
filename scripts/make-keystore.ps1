# Generates a permanent Android release signing keystore for IceDragon VPN and
# outputs base64/password values to add as GitHub Actions Secrets:
#   ANDROID_KEYSTORE_BASE64
#   ANDROID_KEYSTORE_PASSWORD
param(
    [string]$OutFile = 'android-release.jks',
    [string]$Password
)

$ErrorActionPreference = 'Stop'

if (-not $Password) {
    $bytes = New-Object byte[] 18
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $Password = [Convert]::ToBase64String($bytes) -replace '[^A-Za-z0-9]', 'A'
}

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool) {
    foreach ($candidate in @(
        "$env:JAVA_HOME\bin\keytool.exe",
        "$env:ProgramFiles\Android\Android Studio\jbr\bin\keytool.exe"
    )) {
        if (Test-Path $candidate) { $keytool = Get-Command $candidate; break }
    }
}
if (-not $keytool) {
    throw 'keytool not found. Install JDK 17/21 or Android Studio first.'
}

if (Test-Path $OutFile) {
    throw "Keystore file '$OutFile' already exists; delete or specify another -OutFile."
}

& $keytool.Source -genkeypair -v `
    -keystore $OutFile `
    -storetype PKCS12 `
    -storepass $Password `
    -alias release `
    -keypass $Password `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -dname 'CN=IceDragon VPN,O=IceDragon,C=US'

if ($LASTEXITCODE -ne 0) { throw 'keytool failed' }

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $OutFile)))
Write-Host ""
Write-Host "=== GitHub Repo -> Settings -> Secrets and variables -> Actions ===" -ForegroundColor Cyan
Write-Host "ANDROID_KEYSTORE_PASSWORD:" -ForegroundColor Yellow
Write-Host $Password
Write-Host ""
Write-Host "ANDROID_KEYSTORE_BASE64:" -ForegroundColor Yellow
Write-Host $b64
Write-Host ""
Write-Host "Keep '$OutFile' safe outside Git (never commit it)." -ForegroundColor Green
