$adb = "D:\AndroidSDK\platform-tools\adb.exe"
$apkPath = "D:\flutter_build\sanad\app\outputs\apk\debug\app-debug.apk"
$deviceId = "R5CY43FZZDJ"

if (-not (Test-Path $apkPath)) {
    Write-Error "APK not found at $apkPath"
    exit 1
}

Write-Host "Installing APK to device $deviceId..."
& $adb -s $deviceId install -r $apkPath

Write-Host "Starting Spendo MainActivity..."
& $adb -s $deviceId shell am start -n com.finance.spendo/com.finance.spendo.MainActivity

Start-Sleep -Seconds 3

Write-Host "Capturing app screenshot..."
$screenPathLocal = "C:\Users\LAFE9\.gemini\antigravity\brain\b099b91b-48a0-4b4a-a8e2-541dea42cc28\spendo_installed.png"
& $adb -s $deviceId shell screencap -p /sdcard/spendo_screen.png
& $adb -s $deviceId pull /sdcard/spendo_screen.png $screenPathLocal
& $adb -s $deviceId shell rm /sdcard/spendo_screen.png

Write-Host "Done! Screenshot saved to $screenPathLocal"
