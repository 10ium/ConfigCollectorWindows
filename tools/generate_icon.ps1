Add-Type -AssemblyName System.Drawing

$sizes = @(256, 128, 64, 48, 32, 16)
$outPng = "G:\Ai project\10ium\Freedom Config Collector\app_icon.png"
$outIco = "G:\Ai project\10ium\Freedom Config Collector\app_icon.ico"

# Generate 256x256 Master Image
$master = New-Object System.Drawing.Bitmap 256, 256
$g = [System.Drawing.Graphics]::FromImage($master)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# Clear Transparent
$g.Clear([System.Drawing.Color]::Transparent)

# Outer Glow & Rounded Shield / Badge Background
$rect = New-Object System.Drawing.Rectangle 12, 12, 232, 232
$gradBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect,
    [System.Drawing.Color]::FromArgb(255, 15, 23, 42), # Deep Navy #0f172a
    [System.Drawing.Color]::FromArgb(255, 30, 41, 59), # Slate Blue #1e293b
    45.0
)

# Draw Rounded Container
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$r = 52 # Corner radius
$d = $r * 2
$arc = New-Object System.Drawing.Rectangle 12, 12, $d, $d
$path.AddArc($arc, 180, 90)
$arc.X = 12 + 232 - $d
$path.AddArc($arc, 270, 90)
$arc.Y = 12 + 232 - $d
$path.AddArc($arc, 0, 90)
$arc.X = 12
$path.AddArc($arc, 90, 90)
$path.CloseFigure()

$g.FillPath($gradBrush, $path)

# Neon Cyan/Azure Border
$cyanPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220, 0, 210, 255), 6) # Neon cyan
$g.DrawPath($cyanPen, $path)

# Inner Glow Arc
$innerPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(80, 56, 189, 248), 3)
$g.DrawPath($innerPen, $path)

# Symbol: Freedom Wings & Rocket / Speed Lightning
# Draw Wing/Shield Symbol in Electric Cyan & Gold gradient
$symbolBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle 40, 40, 176, 176),
    [System.Drawing.Color]::FromArgb(255, 0, 242, 254), # Electric Cyan
    [System.Drawing.Color]::FromArgb(255, 79, 172, 254), # Vivid Sky
    90.0
)

# Central Freedom Wing / Falcon Symbol
$wingPath = New-Object System.Drawing.Drawing2D.GraphicsPath

# Wing Left
$pLeft = @(
    (New-Object System.Drawing.Point 128, 48),
    (New-Object System.Drawing.Point 68, 92),
    (New-Object System.Drawing.Point 52, 148),
    (New-Object System.Drawing.Point 88, 142),
    (New-Object System.Drawing.Point 72, 176),
    (New-Object System.Drawing.Point 108, 168),
    (New-Object System.Drawing.Point 96, 204),
    (New-Object System.Drawing.Point 128, 182)
)
$wingPath.AddPolygon($pLeft)

# Wing Right
$pRight = @(
    (New-Object System.Drawing.Point 128, 48),
    (New-Object System.Drawing.Point 188, 92),
    (New-Object System.Drawing.Point 204, 148),
    (New-Object System.Drawing.Point 168, 142),
    (New-Object System.Drawing.Point 184, 176),
    (New-Object System.Drawing.Point 148, 168),
    (New-Object System.Drawing.Point 160, 204),
    (New-Object System.Drawing.Point 128, 182)
)
$wingPath.AddPolygon($pRight)

$g.FillPath($symbolBrush, $wingPath)

# Central Core Glow (Speed Diamond / Freedom Star)
$coreBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Rectangle 108, 90, 40, 60),
    [System.Drawing.Color]::FromArgb(255, 255, 255, 255),
    [System.Drawing.Color]::FromArgb(255, 0, 240, 255),
    90.0
)
$corePoints = @(
    (New-Object System.Drawing.Point 128, 76),
    (New-Object System.Drawing.Point 142, 120),
    (New-Object System.Drawing.Point 128, 156),
    (New-Object System.Drawing.Point 114, 120)
)
$g.FillPolygon($coreBrush, $corePoints)

# Save Master PNG
$master.Save($outPng, [System.Drawing.Imaging.ImageFormat]::Png)

# Build Multi-Resolution ICO File with embedded PNG images
$pngStreams = @()
foreach ($sz in $sizes) {
    $resized = New-Object System.Drawing.Bitmap $sz, $sz
    $rg = [System.Drawing.Graphics]::FromImage($resized)
    $rg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $rg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $rg.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $rg.DrawImage($master, 0, 0, $sz, $sz)
    $rg.Dispose()
    
    $ms = New-Object System.IO.MemoryStream
    $resized.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $resized.Dispose()
    $pngStreams += @{ Size = $sz; Bytes = $ms.ToArray() }
    $ms.Dispose()
}

$icoStream = New-Object System.IO.FileStream $outIco, ([System.IO.FileMode]::Create)
$writer = New-Object System.IO.BinaryWriter $icoStream

# ICO Header
$writer.Write([UInt16]0) # Reserved
$writer.Write([UInt16]1) # Type: 1 = ICO
$writer.Write([UInt16]$pngStreams.Count) # Number of images

# Calculate offset
$offset = 6 + ($pngStreams.Count * 16)

# Write Directory Entries
foreach ($item in $pngStreams) {
    $wByte = if ($item.Size -ge 256) { [byte]0 } else { [byte]$item.Size }
    $hByte = if ($item.Size -ge 256) { [byte]0 } else { [byte]$item.Size }
    $writer.Write($wByte) # Width
    $writer.Write($hByte) # Height
    $writer.Write([byte]0) # Color count
    $writer.Write([byte]0) # Reserved
    $writer.Write([UInt16]1) # Color planes
    $writer.Write([UInt16]32) # Bits per pixel
    $writer.Write([UInt32]$item.Bytes.Length) # Image size
    $writer.Write([UInt32]$offset) # Offset
    $offset += $item.Bytes.Length
}

# Write Image Bytes
foreach ($item in $pngStreams) {
    $writer.Write($item.Bytes)
}

$writer.Flush()
$writer.Close()
$icoStream.Close()
$g.Dispose()
$master.Dispose()

Write-Output "ICON_SUCCESS: $outIco and $outPng generated successfully"
