$src = "c:\Users\LAFE9\OneDrive\Desktop\my app"
$dst = "c:\Users\LAFE9\OneDrive\Desktop\Spendo_App_Source.zip"

if (Test-Path $dst) {
    Remove-Item -Force $dst
}

$sevenZip = "C:\Program Files\7-Zip\7z.exe"
if (Test-Path $sevenZip) {
    & $sevenZip a -tzip "$dst" "$src\*" -xr!.git -xr!build -xr!.dart_tool -xr!.gradle -xr!.idea -xr!*.ipa -xr!*.apk -xr!DerivedData
} else {
    Get-ChildItem -Path $src -Exclude ".git", "build", ".dart_tool", ".gradle", ".idea" | Compress-Archive -DestinationPath $dst -Force
}
Write-Output "ZIP_CREATED_SUCCESSFULLY"
