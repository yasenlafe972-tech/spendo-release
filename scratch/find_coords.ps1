Add-Type -AssemblyName System.Drawing
$userProfile = [System.Environment]::GetFolderPath('UserProfile')
$path = "$userProfile\.gemini\antigravity\brain\b099b91b-48a0-4b4a-a8e2-541dea42cc28\spendo_screen_form_shown.png"
$bmp = [System.Drawing.Bitmap]::FromFile($path)
for ($y = 100; $y -lt 500; $y += 5) {
    for ($x = 750; $x -lt 960; $x += 5) {
        $c = $bmp.GetPixel($x, $y)
        if ($c.R -gt 230 -and $c.G -gt 230 -and $c.B -gt 230) {
            Write-Host "White pixel at X=$x Y=$y (R=$($c.R) G=$($c.G) B=$($c.B))"
            break
        }
    }
}
$bmp.Dispose()
