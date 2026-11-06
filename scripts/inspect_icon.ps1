Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile("C:\Users\LAFE9\Downloads\spendo-icon-1024x1024.png")
$c00 = $bmp.GetPixel(0, 0)
$cCenter = $bmp.GetPixel(512, 512)
Write-Host "Pixel(0,0): A=$($c00.A) R=$($c00.R) G=$($c00.G) B=$($c00.B)"
Write-Host "Pixel(512,512): A=$($cCenter.A) R=$($cCenter.R) G=$($cCenter.G) B=$($cCenter.B)"
$bmp.Dispose()
