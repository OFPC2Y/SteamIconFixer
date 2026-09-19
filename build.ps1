# build.ps1 - build SteamIconFix.exe from SteamIconFix.ps1
#
# Usage:  powershell -ExecutionPolicy Bypass -File .\build.ps1

[CmdletBinding()]
param(
    [string]$Version = '1.0.0.0',
    [switch]$RegenerateIcon
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root    = $PSScriptRoot
$source  = Join-Path $root 'SteamIconFix.ps1'
$icoFile = Join-Path $root 'SteamIconFix.ico'
$outDir  = Join-Path $root 'dist'
$outExe  = Join-Path $outDir 'SteamIconFix.exe'


function New-IconBitmap {
    param([int]$Size)

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

    # rounded-square plate
    $radius = [Math]::Max(2.0, $Size * 0.22)
    $d      = $radius * 2
    $plate  = New-Object System.Drawing.Drawing2D.GraphicsPath
    $plate.AddArc(0, 0, $d, $d, 180, 90)
    $plate.AddArc($Size - $d, 0, $d, $d, 270, 90)
    $plate.AddArc($Size - $d, $Size - $d, $d, $d, 0, 90)
    $plate.AddArc(0, $Size - $d, $d, $d, 90, 90)
    $plate.CloseFigure()

    $rect  = New-Object System.Drawing.RectangleF(0, 0, $Size, $Size)
    $from  = [System.Drawing.Color]::FromArgb(255, 0x4E, 0x74, 0x94)
    $to    = [System.Drawing.Color]::FromArgb(255, 0x18, 0x24, 0x32)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $from, $to, 90.0)
    $g.FillPath($brush, $plate)

    # circular refresh arrow
    $c       = $Size / 2.0
    $r       = $Size * 0.255
    $penW    = [Math]::Max(1.4, $Size * 0.115)
    $start   = -58.0
    $sweep   = 286.0

    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, [single]$penW)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
    $g.DrawArc($pen, [single]($c - $r), [single]($c - $r), [single]($r * 2), [single]($r * 2), [single]$start, [single]$sweep)

    # arrowhead at the open end
    $endRad = ($start + $sweep) * [Math]::PI / 180.0
    $px = $c + $r * [Math]::Cos($endRad)
    $py = $c + $r * [Math]::Sin($endRad)
    $tx = -[Math]::Sin($endRad)
    $ty =  [Math]::Cos($endRad)
    $nx = -$ty
    $ny =  $tx

    $ah = $Size * 0.30   # arrow length
    $aw = $Size * 0.26   # arrow width

    $tipX = $px + $tx * $ah * 0.62
    $tipY = $py + $ty * $ah * 0.62
    $baseX = $px - $tx * $ah * 0.38
    $baseY = $py - $ty * $ah * 0.38

    $tri = @(
        (New-Object System.Drawing.PointF([single]$tipX, [single]$tipY)),
        (New-Object System.Drawing.PointF([single]($baseX + $nx * $aw / 2), [single]($baseY + $ny * $aw / 2))),
        (New-Object System.Drawing.PointF([single]($baseX - $nx * $aw / 2), [single]($baseY - $ny * $aw / 2)))
    )
    $g.FillPolygon((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)), $tri)

    $pen.Dispose(); $brush.Dispose(); $plate.Dispose(); $g.Dispose()
    return $bmp
}


function Get-BmpPayload {
    param([System.Drawing.Bitmap]$Bitmap)

    $w = $Bitmap.Width
    $h = $Bitmap.Height
    $rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)

    $locked = $Bitmap.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $locked.Stride
    $pixels = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($locked.Scan0, $pixels, 0, $pixels.Length)
    $Bitmap.UnlockBits($locked)

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)

    # BITMAPINFOHEADER: height is doubled to cover the XOR image plus the AND mask
    $bw.Write([uint32]40)
    $bw.Write([int32]$w)
    $bw.Write([int32]($h * 2))
    $bw.Write([uint16]1)
    $bw.Write([uint16]32)
    $bw.Write([uint32]0)
    $bw.Write([uint32]($w * $h * 4))
    $bw.Write([int32]0); $bw.Write([int32]0)
    $bw.Write([uint32]0); $bw.Write([uint32]0)

    # pixel rows are stored bottom-up
    for ($y = $h - 1; $y -ge 0; $y--) {
        $bw.Write($pixels, $y * $stride, $w * 4)
    }

    # AND mask, 1bpp rows padded to 4 bytes, all zero (alpha channel already carries transparency)
    $maskRow = [int]([Math]::Ceiling($w / 32.0) * 4)
    $mask = New-Object byte[] ($maskRow * $h)
    $bw.Write($mask, 0, $mask.Length)

    $bw.Flush()
    $bytes = $ms.ToArray()
    $bw.Dispose(); $ms.Dispose()
    return $bytes
}


function Write-IcoFile {
    param([string]$Path)

    # BMP payloads for small sizes, PNG for the large ones (both valid since Vista)
    $sizes = @(16, 24, 32, 48, 64, 128, 256)
    $images = @()

    foreach ($s in $sizes) {
        $bmp = New-IconBitmap -Size $s
        if ($s -ge 128) {
            $ms = New-Object System.IO.MemoryStream
            $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
            $payload = $ms.ToArray()
            $ms.Dispose()
        }
        else {
            $payload = Get-BmpPayload -Bitmap $bmp
        }
        $bmp.Dispose()
        $images += [pscustomobject]@{ Size = $s; Data = $payload }
    }

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)

    $bw.Write([uint16]0)
    $bw.Write([uint16]1)
    $bw.Write([uint16]$images.Count)

    $offset = 6 + 16 * $images.Count
    foreach ($img in $images) {
        $dim = if ($img.Size -ge 256) { 0 } else { $img.Size }
        $bw.Write([byte]$dim)
        $bw.Write([byte]$dim)
        $bw.Write([byte]0)
        $bw.Write([byte]0)
        $bw.Write([uint16]1)
        $bw.Write([uint16]32)
        $bw.Write([uint32]$img.Data.Length)
        $bw.Write([uint32]$offset)
        $offset += $img.Data.Length
    }

    foreach ($img in $images) {
        $bw.Write($img.Data, 0, $img.Data.Length)
    }

    $bw.Flush()
    [System.IO.File]::WriteAllBytes($Path, $ms.ToArray())
    $bw.Dispose(); $ms.Dispose()
}


# The icon is a maintained asset - only generate a placeholder set when it is
# missing, or when -RegenerateIcon is passed explicitly.
if ($RegenerateIcon -or !(Test-Path $icoFile)) {
    Write-Host "Generating icon: $icoFile"
    Write-IcoFile -Path $icoFile
}
else {
    Write-Host "Using existing icon: $icoFile"
}

if (!(Test-Path $icoFile)) { throw "Icon file not found: $icoFile" }
Write-Host ("Icon: {0} bytes" -f (Get-Item $icoFile).Length)

Write-Host "Compiling: $outExe"
if (!(Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

Import-Module ps2exe -ErrorAction Stop

Invoke-PS2EXE `
    -InputFile   $source `
    -OutputFile  $outExe `
    -IconFile    $icoFile `
    -Title       'Steam Shortcut Icon Fixer' `
    -Description 'Repair missing Steam desktop shortcut icons' `
    -Product     'Steam Icon Fixer' `
    -Company     'SteamIconFix' `
    -Version     $Version `
    -X64 `
    -SupportOS

Write-Host ("Done: {0} ({1} bytes)" -f $outExe, (Get-Item $outExe).Length)
