Add-Type -AssemblyName System.Drawing

function Generate-SpendoIcon {
    param(
        [int]$Size,
        [string]$OutputPath,
        [bool]$IsRound = $false,
        [bool]$Transparent = $false,
        [bool]$FullBleed = $false
    )

    $pixelFormat = if ($FullBleed) {
        [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    } else {
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    }
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, $pixelFormat)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    if ($FullBleed) {
        $g.Clear([System.Drawing.Color]::FromArgb(255, 12, 14, 13))
    } else {
        $g.Clear([System.Drawing.Color]::Transparent)
    }

    if (-not $Transparent) {
        $bgColor = [System.Drawing.Color]::FromArgb(255, 12, 14, 13) # #0C0E0D
        $bgBrush = New-Object System.Drawing.SolidBrush $bgColor
        $borderColor = [System.Drawing.Color]::FromArgb(255, 34, 38, 46) # #22262E
        $borderPen = New-Object System.Drawing.Pen $borderColor, ([Math]::Max(1, $Size * 0.015))

        if ($FullBleed) {
            $g.Clear($bgColor)
        } elseif ($IsRound) {
            $inset = $Size * 0.02
            $rect = New-Object System.Drawing.RectangleF $inset, $inset, ($Size - 2 * $inset), ($Size - 2 * $inset)
            $g.FillEllipse($bgBrush, $rect)
            $g.DrawEllipse($borderPen, $rect)
        } else {
            $radius = $Size * 0.22
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $d = $radius * 2
            $inset = $Size * 0.01
            $w = $Size - 2 * $inset
            $h = $Size - 2 * $inset
            $path.AddArc($inset, $inset, $d, $d, 180, 90)
            $path.AddArc($inset + $w - $d, $inset, $d, $d, 270, 90)
            $path.AddArc($inset + $w - $d, $inset + $h - $d, $d, $d, 0, 90)
            $path.AddArc($inset, $inset + $h - $d, $d, $d, 90, 90)
            $path.CloseFigure()

            $g.FillPath($bgBrush, $path)
            $g.DrawPath($borderPen, $path)
            $path.Dispose()
        }
        $bgBrush.Dispose()
        $borderPen.Dispose()
    }

    # Center and scale mark
    # SVG viewBox: 100x100
    # Bounding box of polygons: X: 22 to 78 (width 56), Y: 16 to 84 (height 68), Center (50, 50)
    $markScale = if ($IsRound) { $Size * 0.0056 } else { $Size * 0.0062 }
    $offsetX = ($Size / 2.0) - (50.0 * $markScale)
    $offsetY = ($Size / 2.0) - (50.0 * $markScale)

    function Map-Points($ptArray) {
        $pts = New-Object "System.Drawing.PointF[]" ($ptArray.Count)
        for ($i = 0; $i -lt $ptArray.Count; $i++) {
            $x = $ptArray[$i][0] * $markScale + $offsetX
            $y = $ptArray[$i][1] * $markScale + $offsetY
            $pts[$i] = New-Object System.Drawing.PointF $x, $y
        }
        return ,$pts
    }

    # 1. Top Polygon: #EAB308 (Yellow) - points="38,16 78,16 64,34 24,34"
    $topRaw = @(@(38,16), @(78,16), @(64,34), @(24,34))
    $topPts = Map-Points $topRaw
    $yellowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 234, 179, 8))
    $g.FillPolygon($yellowBrush, $topPts)
    $yellowBrush.Dispose()

    # 2. Middle Diagonal: #00A86B (Green) - points="24,34 45,34 76,66 55,66"
    $midRaw = @(@(24,34), @(45,34), @(76,66), @(55,66))
    $midPts = Map-Points $midRaw
    $greenBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 0, 168, 107))
    $g.FillPolygon($greenBrush, $midPts)
    $greenBrush.Dispose()

    # 3. Bottom Polygon: #F3F4F6 (White) - points="36,66 76,66 62,84 22,84"
    $botRaw = @(@(36,66), @(76,66), @(62,84), @(22,84))
    $botPts = Map-Points $botRaw
    $whiteBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 243, 244, 246))
    $g.FillPolygon($whiteBrush, $botPts)
    $whiteBrush.Dispose()

    $parentDir = [System.IO.Path]::GetDirectoryName($OutputPath)
    if (-not [System.IO.Directory]::Exists($parentDir)) {
        [System.IO.Directory]::CreateDirectory($parentDir) | Out-Null
    }

    $bmp.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Generated: $OutputPath ($Size x $Size)"
}

# Generate Asset Icons
Generate-SpendoIcon -Size 1024 -OutputPath "assets/icons/spendo_icon_1024.png"
Generate-SpendoIcon -Size 512  -OutputPath "assets/icons/spendo_icon_512.png"
Generate-SpendoIcon -Size 192  -OutputPath "assets/icons/spendo_icon.png"

# Generate Mipmap Icons
$mipmapSizes = @{
    "android/app/src/main/res/mipmap-mdpi" = 48
    "android/app/src/main/res/mipmap-hdpi" = 72
    "android/app/src/main/res/mipmap-xhdpi" = 96
    "android/app/src/main/res/mipmap-xxhdpi" = 144
    "android/app/src/main/res/mipmap-xxxhdpi" = 192
}

foreach ($entry in $mipmapSizes.GetEnumerator()) {
    $dir = $entry.Key
    $sz = $entry.Value
    Generate-SpendoIcon -Size $sz -OutputPath "$dir/ic_launcher.png" -IsRound $false
    Generate-SpendoIcon -Size $sz -OutputPath "$dir/ic_launcher_round.png" -IsRound $true
}

# Generate iOS AppIcon.appiconset Icons (FullBleed opaque square as required by Apple)
$iosDir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
$iosIcons = @{
    "Icon-App-20x20@1x.png"     = 20
    "Icon-App-20x20@2x.png"     = 40
    "Icon-App-20x20@3x.png"     = 60
    "Icon-App-29x29@1x.png"     = 29
    "Icon-App-29x29@2x.png"     = 58
    "Icon-App-29x29@3x.png"     = 87
    "Icon-App-40x40@1x.png"     = 40
    "Icon-App-40x40@2x.png"     = 80
    "Icon-App-40x40@3x.png"     = 120
    "Icon-App-60x60@2x.png"     = 120
    "Icon-App-60x60@3x.png"     = 180
    "Icon-App-76x76@1x.png"     = 76
    "Icon-App-76x76@2x.png"     = 152
    "Icon-App-83.5x83.5@2x.png" = 167
    "Icon-App-1024x1024@1x.png" = 1024
}

foreach ($entry in $iosIcons.GetEnumerator()) {
    $file = $entry.Key
    $sz = $entry.Value
    Generate-SpendoIcon -Size $sz -OutputPath "$iosDir/$file" -FullBleed $true
}

Write-Host "All icons generated successfully!"
