param (
    [string]$Filename = "screenshot.png"
)

$adb = "D:\AndroidSDK\platform-tools\adb.exe"
$deviceId = "R5CY43FZZDJ"
$artifactDir = "C:\Users\LAFE9\.gemini\antigravity\brain\b099b91b-48a0-4b4a-a8e2-541dea42cc28"
$screenPathLocal = Join-Path $artifactDir $Filename

& $adb -s $deviceId shell screencap -p /sdcard/spendo_screen.png
& $adb -s $deviceId pull /sdcard/spendo_screen.png $screenPathLocal
& $adb -s $deviceId shell rm /sdcard/spendo_screen.png

Write-Host "Screenshot saved to $screenPathLocal"
