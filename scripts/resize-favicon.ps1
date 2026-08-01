# 从 assets/favicon-source.png 生成各尺寸 favicon 到 static/。
# 原始图是 1024x1024 / 1.38MB，直接当 favicon 用会让每个页面都拉一张大图。
# 改了源图后重跑：pwsh scripts/resize-favicon.ps1

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root "assets\favicon-source.png"
$outDir = Join-Path $root "static"

if (-not (Test-Path $src)) { throw "找不到源图: $src" }

$targets = @(
    @{ Name = "favicon.png";          Size = 32  },
    @{ Name = "favicon-16x16.png";    Size = 16  },
    @{ Name = "favicon-32x32.png";    Size = 32  },
    @{ Name = "apple-touch-icon.png"; Size = 180 }
)

$source = [System.Drawing.Image]::FromFile($src)
try {
    foreach ($t in $targets) {
        $size = $t.Size
        $bmp = New-Object System.Drawing.Bitmap($size, $size)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.Clear([System.Drawing.Color]::Transparent)
            $g.DrawImage($source, 0, 0, $size, $size)
        } finally {
            $g.Dispose()
        }
        $dest = Join-Path $outDir $t.Name
        $bmp.Save($dest, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        "{0,-22} {1,3}x{1,-3} {2,7} bytes" -f $t.Name, $size, (Get-Item $dest).Length
    }
} finally {
    $source.Dispose()
}
