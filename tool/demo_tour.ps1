# Runs the automatic two-phone NABRA demo tour: patient on one emulator, caregiver on another.
# Run from the project folder (VS Code terminal opens there):
#   powershell -ExecutionPolicy Bypass -File tool/demo_tour.ps1               (video: smooth, no screenshots)
#   powershell -ExecutionPolicy Bypass -File tool/demo_tour.ps1 -Screenshots  (saves demo/screenshots/)
# Open two emulators side by side first (the first one started = patient, on the left).
# Start your screen recording when it says "Starting the tour", then don't touch anything until it says Done.
param([switch]$Screenshots)
$ErrorActionPreference = 'Continue'
$pkg = 'com.example.nabra'
# Profile build: much smoother than a debug build, and the tour can still drive the app.
$apk = 'build\app\outputs\flutter-apk\app-profile.apk'
$mode = if ($Screenshots) { 'shots' } else { 'video' }
$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
# adb usually isn't on PATH on Windows; use the Android SDK copy.
$adb = Join-Path $sdk 'platform-tools\adb.exe'
if (-not (Test-Path $adb)) { $adb = 'adb' }

function Get-Phones {
  & $adb devices | Select-String '^(\S+)\s+device$' | ForEach-Object { $_.Matches[0].Groups[1].Value } | Sort-Object
}

function Wait-Booted($serial) {
  & $adb -s $serial wait-for-device
  while ((& $adb -s $serial shell getprop sys.boot_completed 2>$null) -notmatch '1') { Start-Sleep 2 }
}

# ---------- two phones ----------
$phones = @(Get-Phones)
if ($phones.Count -eq 0) { Write-Host 'No emulator found. Open one in Android Studio first.'; exit 1 }
if ($phones.Count -eq 1) {
  $avd = (& $adb -s $phones[0] emu avd name | Select-Object -First 1).Trim()
  Write-Host "Opening a second emulator (temporary copy of $avd)..."
  Start-Process (Join-Path $sdk 'emulator\emulator.exe') -ArgumentList '-avd', $avd, '-read-only', '-no-boot-anim'
  for ($i = 0; $i -lt 60 -and @(Get-Phones).Count -lt 2; $i++) { Start-Sleep 2 }
  $phones = @(Get-Phones)
  if ($phones.Count -lt 2) {
    Write-Host 'The second emulator did not start. Open two emulators yourself (README "Demo tour") and run this again.'
    exit 1
  }
}
$patient = $phones[0]
$caregiver = $phones[1]
foreach ($p in $phones) { Wait-Booted $p }
Write-Host "Patient phone: $patient   Caregiver phone: $caregiver"

# Emulator only: give the patient a GPS position (Jeddah) so the alert shows a location.
& $adb -s $patient emu geo fix 39.1925 21.4858 2>$null | Out-Null

# ---------- build once, install on both ----------
Write-Host 'Building the app with the tour inside (2-4 minutes)...'
flutter build apk --profile --target=integration_test/demo_tour_test.dart
if ($LASTEXITCODE -ne 0) { Write-Host 'Build failed.'; exit 1 }
# The build leaves Gradle running in the background (often 1-2 GB). Free that memory for the emulators.
Push-Location android; & .\gradlew.bat --stop | Out-Null; Pop-Location

$run = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
foreach ($d in @(@($patient, 'patient'), @($caregiver, 'caregiver'))) {
  $serial, $role = $d
  & $adb -s $serial uninstall $pkg 2>$null | Out-Null
  & $adb -s $serial install $apk | Out-Null
  # Grant permissions up front so no system pop-up interrupts the tour.
  foreach ($p in 'POST_NOTIFICATIONS', 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION', 'CALL_PHONE') {
    & $adb -s $serial shell pm grant $pkg "android.permission.$p"
  }
  & $adb -s $serial shell appops set $pkg USE_FULL_SCREEN_INTENT allow
  # Tell the app which role it plays in the tour.
  & $adb -s $serial shell "run-as $pkg sh -c 'mkdir -p files && echo $role $run $mode > files/tour.txt'"
  $granted = (& $adb -s $serial shell dumpsys package $pkg | Select-String 'granted=true').Count
  Write-Host "  $role phone ready ($granted permissions granted)"
}

# Safety net: if a permission pop-up still appears on either phone, tap Allow.
$allow = Start-Job -ArgumentList $adb, $phones -ScriptBlock {
  param($adb, $phones)
  while ($true) {
    foreach ($s in $phones) {
      $focus = (& $adb -s $s shell dumpsys window 2>$null | Select-String 'mCurrentFocus') -join ''
      if ($focus -match 'permissioncontroller') {
        & $adb -s $s shell uiautomator dump /sdcard/ui.xml 2>$null | Out-Null
        $xml = (& $adb -s $s shell cat /sdcard/ui.xml) -join ''
        $m = [regex]::Match($xml, 'permission_allow_(foreground_only_)?button"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"')
        if ($m.Success) {
          $x = ([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2
          $y = ([int]$m.Groups[3].Value + [int]$m.Groups[5].Value) / 2
          & $adb -s $s shell input tap $x $y
        }
      }
    }
    Start-Sleep -Milliseconds 1500
  }
}

# Pass the patient's pairing code to the caregiver phone once the patient has paired.
$handoff = Start-Job -ArgumentList $adb, $pkg, $patient, $caregiver -ScriptBlock {
  param($adb, $pkg, $patient, $caregiver)
  while ($true) {
    $code = (& $adb -s $patient shell "run-as $pkg cat files/code.txt" 2>$null) -join ''
    if ($code -match '^[A-Za-z0-9]+$') {
      & $adb -s $caregiver shell "run-as $pkg sh -c 'echo $code > files/code.txt'"
      break
    }
    Start-Sleep 2
  }
}

# ---------- run both tours at the same time ----------
if ($Screenshots) { Remove-Item demo/screenshots -Recurse -Force -ErrorAction SilentlyContinue }
Write-Host "Starting the tour in $mode mode (about 4 minutes, hands off)..."
$driveArgs = @('drive', '--profile', '--driver=test_driver/integration_test.dart', '--target=integration_test/demo_tour_test.dart', "--use-application-binary=$apk")
$cgLog = Join-Path $env:TEMP 'nabra_tour_caregiver.log'
$cg = Start-Job -ArgumentList $PWD.Path, $caregiver, $driveArgs, $cgLog -ScriptBlock {
  param($dir, $serial, $driveArgs, $log)
  Set-Location $dir
  flutter @driveArgs -d $serial *> $log
  $LASTEXITCODE
}
Start-Sleep 5
# --use-application-binary: run the install above (keeps the permissions) instead of rebuilding.
flutter @driveArgs -d $patient
$patientOk = $LASTEXITCODE -eq 0
$caregiverOk = (Receive-Job $cg -Wait) -eq 0
Remove-Job $cg -Force
Stop-Job $allow, $handoff; Remove-Job $allow, $handoff -Force

Write-Host ''
Write-Host "Patient phone:   $(if ($patientOk) { 'passed' } else { 'FAILED' })"
Write-Host "Caregiver phone: $(if ($caregiverOk) { 'passed' } else { "FAILED (log: $cgLog)" })"
Write-Host $(if ($Screenshots) { 'Done. Screenshots are in demo/screenshots/' } else { 'Done.' })
