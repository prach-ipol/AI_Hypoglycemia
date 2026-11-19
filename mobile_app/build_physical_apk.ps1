$ErrorActionPreference = 'Stop'

# Some Windows shells in this workspace resolve Gradle's user home to C:\.gradle,
# which is not writable. Reuse the normal per-user Gradle cache instead.
$env:GRADLE_USER_HOME = Join-Path $env:USERPROFILE '.gradle'

# Select the first private IPv4 address reported by Windows. This avoids
# accidentally shipping the Android-emulator-only 10.0.2.2 address to a phone.
$privateIp = ipconfig |
  Select-String -Pattern 'IPv4 Address' |
  ForEach-Object { ($_ -replace '^.*:\s*', '').Trim() } |
  Where-Object {
    $_ -match '^192\.168\.' -or
    $_ -match '^10\.' -or
    $_ -match '^172\.(1[6-9]|2[0-9]|3[0-1])\.'
  } |
  Select-Object -First 1

if (-not $privateIp) {
  throw 'No private IPv4 address was found. Connect this computer and phone to the same Wi-Fi network.'
}

$apiUrl = "http://${privateIp}:5000"
Write-Host "Building physical-device APK with API_BASE_URL=$apiUrl"
# Flutter/Gradle print harmless warnings on stderr; with 'Stop' Windows
# PowerShell 5.1 would treat them as fatal, so rely on the exit code instead.
$ErrorActionPreference = 'Continue'
flutter build apk --release "--dart-define=API_BASE_URL=$apiUrl"
if ($LASTEXITCODE -ne 0) { throw "flutter build failed with exit code $LASTEXITCODE" }

Write-Host ""
Write-Host "APK: $PSScriptRoot\build\app\outputs\flutter-apk\app-release.apk"
Write-Host "If the phone still cannot connect, allow port 5000 through Windows Firewall"
Write-Host "(run once in an Administrator PowerShell):"
Write-Host "  New-NetFirewallRule -DisplayName 'Glucose Companion backend' -Direction Inbound -Protocol TCP -LocalPort 5000 -Action Allow -Profile Any"
Write-Host "If your PC IP changes later, tap the gear icon in the app to update the server address."
