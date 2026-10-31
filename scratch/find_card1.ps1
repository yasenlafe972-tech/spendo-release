Add-Type -AssemblyName System.Drawing
$userProfile = [System.Environment]::GetFolderPath('UserProfile')
$path = "$userProfile\.gemini\antigravity\brain\b099b91b-48a0-4b4a-a8e2-541dea42cc28\spendo_screen_form_shown.png"
$bmp = [System.Drawing.Bitmap]::FromFile($path)
for ($y = 500; $y -lt 1000; $y += 10) {
    for ($x = 750; $x -lt 950; $x += 10) {
        $c = $bmp.GetPixel($x, $y)
        if ($c.R -gt 100 -and $c.R -lt 140 -and $c.G -gt 100 -and $c.G -lt 140) {
            Write-Host "Mono icon pixel at X=$x Y=$y (R=$($c.R) G=$($c.G) B=$($c.B))"
            break
        }
    }
}
$bmp.Dispose()
