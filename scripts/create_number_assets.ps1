Add-Type -AssemblyName System.Drawing

$numbers = 0..9
$targetFolder = "assets/images/numbers"

if (-not (Test-Path $targetFolder)) {
    New-Item -ItemType Directory -Path $targetFolder | Out-Null
}

foreach ($n in $numbers) {
    $bmp = New-Object System.Drawing.Bitmap 64, 64
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::White)
    $font = New-Object System.Drawing.Font('Arial', 32, [System.Drawing.FontStyle]::Bold)
    $brush = [System.Drawing.Brushes]::Black
    $point = New-Object System.Drawing.PointF 10, 10
    $g.DrawString($n.ToString(), $font, $brush, $point)
    $g.Dispose()

    $filePath = Join-Path $targetFolder "number_$n.png"
    $bmp.Save($filePath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

Write-Output "Created number sprite images 0-9 in $targetFolder"