# BALLAL - permissions Android (version PowerShell, sans Python)
# A lancer UNE fois apres "flutter create", depuis le dossier apps\mobile :
#   powershell -ExecutionPolicy Bypass -File tool\setup_platforms.ps1

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$manifest = Join-Path $root "android\app\src\main\AndroidManifest.xml"

if (-not (Test-Path $manifest)) {
  Write-Host "AndroidManifest.xml introuvable. Lancez d'abord flutter create depuis apps\mobile." -ForegroundColor Red
  exit 1
}

$m = Get-Content $manifest -Raw -Encoding UTF8

$permissions = @"
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>

"@
$queries = @"
    <queries>
        <intent><action android:name="android.intent.action.DIAL"/><data android:scheme="tel"/></intent>
        <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
    </queries>

"@

if ($m -notmatch "RECORD_AUDIO") {
  $idx = $m.IndexOf("<application")
  $m = $m.Substring(0, $idx) + $permissions + "    " + $m.Substring($idx)
}
if ($m -notmatch "android.intent.action.DIAL") {
  $idx = $m.LastIndexOf("</manifest>")
  $m = $m.Substring(0, $idx) + $queries + $m.Substring($idx)
}
$m = $m.Replace('android:label="ballal"', 'android:label="BALLAL"')
[System.IO.File]::WriteAllText($manifest, $m, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "Android : permissions ajoutees" -ForegroundColor Green

$test = Join-Path $root "test\widget_test.dart"
if ((Test-Path $test) -and ((Get-Content $test -Raw) -match "MyApp")) {
  Remove-Item $test
  Write-Host "test\widget_test.dart (modele Flutter) supprime" -ForegroundColor Green
}
