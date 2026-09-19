# SteamIconFix.ps1
# Steam 桌面快捷方式白图标修复工具

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"


$BannerBig = @(
'    ██  ▄█▄  ██            ██            █▄   ▄▄▄▄▄▄▄▄▄▄     ▄▄▄  ▄▄▄',
'▄█████████████████▄ ▄▄▄▄▄▄████▄▄▄▄▄▄     ██   ██▀▀▀▀▀███     ███ ▄███▄▄▄▄▄▄▄',
'   ▀██▀ ███ ▀██▀    ███▀▀▀▀███▀▀▀███   ██████ █████████▀    ███ ▄███████████',
' ▄▄▄██▄▄███▄▄██▄▄▄  ███▄▄▄▄███▄▄▄███     ██  █████ █████▄  ████▄██▀ ██▄',
' ██▀▀▀▀▀███▀▀▀▀▀██  ███▀▀▀████▀▀▀███   ▄▄███▄██▄██ ██▄███ █████ █▀  ███████',
' ▀██▄▄▄▄███▄▄▄▄██▀  ███▄▄▄▄██▄▄▄▄███   ████▀ ▀▀▀▀█▄█▀▀▀▀  ▀▀███     ██▀',
'  ███▀▀▀███▀▀▀███   ████████████████▄▄   ██ █████████████   ███     ████████',
'  ███   ███ ▄▄███   ▀▀▀    ██▄   ▄▄███   ██  ▄▄███████▄▄    ███     ██▀▀▀▀▀▀',
'  ▀▀▀   ███ ▀▀▀▀           ▀████████▀  ████ ▀█▀▀ ███ ▀▀█▀   ███     ███'
)

$BannerSmall = @(
' ▄██▄ ████ ██▄▄ ▄██▄ ▄██▄ █  █',
'██  █ █▄▄  █▄▄█ █      ██ ▀██▀',
'▀█▄▄█ █▀   █▀▀  █▄▄▄ ▄██▄  ██'
)


# ---------- 控制台外观 ----------

try { $Host.UI.RawUI.WindowTitle = 'Steam 桌面图标修复工具' } catch { }

# 窗口尺寸由内容决定：宽度贴合横幅，高度留出表头 + 内容区
$artWidth   = ($BannerBig | Measure-Object -Property Length -Maximum).Maximum
$headerRows = 1 + 1 + 1 + $BannerBig.Count + 1 + $BannerSmall.Count + 1 + 1

try {
    $rawUI   = $Host.UI.RawUI
    $maxSize = $rawUI.MaxWindowSize
    $nowSize = $rawUI.BufferSize

    $wantW = [Math]::Min([Math]::Max($artWidth + 4, 60), $maxSize.Width)
    $wantH = [Math]::Min($headerRows + 14, $maxSize.Height)

    # 顺序有讲究：先把缓冲区撑够大，窗口才放得下；
    # 窗口就位后再把缓冲区收回与窗口一致，滚动区域才不会被视口偏移搞乱
    try {
        $growW = [Math]::Max($nowSize.Width,  $wantW)
        $growH = [Math]::Max($nowSize.Height, $wantH)
        $rawUI.BufferSize = New-Object System.Management.Automation.Host.Size($growW, $growH)
    }
    catch { }

    $rawUI.WindowSize = New-Object System.Management.Automation.Host.Size($wantW, $wantH)

    try {
        $rawUI.BufferSize = New-Object System.Management.Automation.Host.Size($wantW, $wantH)
    }
    catch { }
}
catch { }

try { Clear-Host } catch { }

$script:ConsoleWidth  = 80
$script:ConsoleHeight = 25
try {
    if ([Console]::WindowWidth  -gt 0) { $script:ConsoleWidth  = [Console]::WindowWidth }
    if ([Console]::WindowHeight -gt 0) { $script:ConsoleHeight = [Console]::WindowHeight }
}
catch { }

# 打开 VT 序列解析；没有它就用不了滚动区域，表头也就钉不住
$script:VtEnabled = $false
try {
    Add-Type -Namespace SifVT -Name Native -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
    $hOut = [SifVT.Native]::GetStdHandle(-11)
    $mode = [uint32]0
    if ([SifVT.Native]::GetConsoleMode($hOut, [ref]$mode)) {
        $script:VtEnabled = [SifVT.Native]::SetConsoleMode($hOut, $mode -bor 0x0004)
    }
}
catch { $script:VtEnabled = $false }


# ---------- 界面工具 ----------

function Show-Art {
    param([string[]]$Lines, [string]$Color)

    $wide = ($Lines | Measure-Object -Property Length -Maximum).Maximum
    $pad  = [int](($script:ConsoleWidth - $wide) / 2)
    if ($pad -lt 0) { $pad = 0 }
    $indent = ' ' * $pad

    foreach ($line in $Lines) {
        Write-Host ($indent + $line) -ForegroundColor $Color
    }
}

function Write-Vt {
    param([string]$Sequence)
    if (-not $script:VtEnabled) { return }
    try { [Console]::Write([char]27 + $Sequence) } catch { }
}

function Show-Banner {
    # 画表头，并返回它占用的控制台行数
    $artW  = ($BannerBig | Measure-Object -Property Length -Maximum).Maximum
    $inner = [Math]::Min($script:ConsoleWidth - 2, $artW + 8)
    if ($inner -lt 40) { $inner = 40 }

    $left = [int](($script:ConsoleWidth - $inner) / 2)
    if ($left -lt 0) { $left = 0 }
    $ind  = ' ' * $left

    $rows = 0
    Write-Host ''; $rows++
    Write-Host ($ind + '╔' + ('═' * ($inner - 2)) + '╗') -ForegroundColor DarkCyan; $rows++
    Write-Host ''; $rows++
    Show-Art -Lines $BannerBig   -Color Cyan; $rows += $BannerBig.Count
    Write-Host ''; $rows++
    Show-Art -Lines $BannerSmall -Color Gray; $rows += $BannerSmall.Count
    Write-Host ''; $rows++
    Write-Host ($ind + '╚' + ('═' * ($inner - 2)) + '╝') -ForegroundColor DarkCyan; $rows++
    return $rows
}

function Freeze-Header {
    param([int]$HeaderRows)

    $script:StickyActive = $false

    if (-not $script:VtEnabled) { return $false }
    if ($script:ConsoleHeight -lt ($HeaderRows + 5)) { return $false }

    $top    = $HeaderRows + 1
    $bottom = $script:ConsoleHeight

    Write-Vt ('[' + $top + ';' + $bottom + 'r')   # DECSTBM：只在表头下方滚动
    Write-Vt ('[' + $top + ';1H')
    Write-Vt '[0J'

    $script:StickyActive = $true
    return $true
}

function Release-Header {
    if ($script:StickyActive) {
        Write-Vt '[r'
        $script:StickyActive = $false
    }
}

function Read-Choice {
    param([string]$Prompt)

    while ($true) {
        Write-Host ''
        Write-Host ('  ' + $Prompt + '  ') -NoNewline -ForegroundColor White
        Write-Host '[Y/N]' -NoNewline -ForegroundColor DarkGray
        Write-Host ' > ' -NoNewline -ForegroundColor DarkGray

        $raw = Read-Host

        # stdin 到末尾时 Read-Host 返回 $null，这里必须退出，
        # 否则 .Trim() 抛错后在 while 里无限刷屏
        if ($null -eq $raw) { return $false }

        $answer = $raw.Trim().ToUpperInvariant()

        if ($answer -eq 'Y') { return $true }
        if ($answer -eq 'N') { return $false }

        Write-Host '  请输入 Y 或 N' -ForegroundColor DarkRed
    }
}


function Wait-Exit {
    Write-Host ''
    Write-Host '  按回车退出' -NoNewline -ForegroundColor DarkGray
    [void](Read-Host)
    Release-Header
}


# ---------- 主流程 ----------

$headerRows = Show-Banner
[void](Freeze-Header -HeaderRows $headerRows)

Write-Host '  Steam 桌面快捷方式白图标修复工具' -ForegroundColor White
Write-Host '  从 Steam 官方 CDN 重新下载丢失的图标文件' -ForegroundColor DarkGray


if (-not (Read-Choice '是否开始扫描并修复？')) {
    Write-Host ''
    Write-Host '  已取消。' -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 900
    Release-Header
    exit
}


$success = 0
$failed  = 0
$skip    = 0

$desktop = [Environment]::GetFolderPath("Desktop")

Write-Host ''
Write-Host '  扫描桌面快捷方式' -ForegroundColor DarkCyan
Write-Host ('  ' + $desktop) -ForegroundColor DarkGray
Write-Host ''

$shortcuts = @(Get-ChildItem `
    $desktop `
    -Filter "*.url" `
    -ErrorAction SilentlyContinue)


if ($shortcuts.Count -eq 0) {

    Write-Host '  未找到任何快捷方式。' -ForegroundColor Yellow
    Wait-Exit
    exit

}


foreach ($file in $shortcuts) {

    Write-Host ('  ● ' + [System.IO.Path]::GetFileNameWithoutExtension($file.Name)) -ForegroundColor White

    $content = Get-Content `
        $file.FullName `
        -ErrorAction SilentlyContinue

    $iconLine = $content |
        Where-Object { $_ -like "IconFile=*" } |
        Select-Object -First 1

    $urlLine = $content |
        Where-Object { $_ -like "URL=*" } |
        Select-Object -First 1

    if (!$iconLine -or !$urlLine) {
        Write-Host '      跳过：非 Steam 快捷方式' -ForegroundColor DarkGray
        $skip++
        continue
    }

    $icon = $iconLine -replace "^IconFile=", ""

    if (Test-Path $icon) {
        Write-Host '      图标正常，无需修复' -ForegroundColor DarkGray
        $skip++
        continue
    }

    $hash = [System.IO.Path]::GetFileNameWithoutExtension($icon)

    if ($urlLine -match "rungameid/(\d+)") {
        $appid = $matches[1]
    }
    else {
        Write-Host '      无法识别 AppID，跳过' -ForegroundColor Yellow
        $failed++
        continue
    }

    Write-Host ('      图标缺失  AppID: ' + $appid) -ForegroundColor Yellow

    $folder = Split-Path $icon

    if (!(Test-Path $folder)) {
        New-Item `
        -ItemType Directory `
        -Path $folder `
        | Out-Null
    }

    $url = "https://cdn.cloudflare.steamstatic.com/steamcommunity/public/images/apps/$appid/$hash.ico"

    try {

        Invoke-WebRequest `
        -Uri $url `
        -OutFile $icon `
        -ErrorAction Stop

        Write-Host '      已修复' -ForegroundColor Green
        $success++

    }
    catch {

        Write-Host '      下载失败' -ForegroundColor Red
        $failed++

    }

}


Write-Host ''
Write-Host '  ' -NoNewline
Write-Host ('修复 ' + $success) -NoNewline -ForegroundColor Green
Write-Host '   ' -NoNewline
Write-Host ('跳过 ' + $skip) -NoNewline -ForegroundColor DarkGray
Write-Host '   ' -NoNewline
Write-Host ('失败 ' + $failed) -ForegroundColor Red


# ---------- 刷新 ----------

if ($success -gt 0) {

    if (Read-Choice '是否立即重启资源管理器以刷新桌面图标？') {

        Write-Host ''
        Write-Host '  正在重启资源管理器...' -ForegroundColor DarkCyan

        Stop-Process `
        -Name explorer `
        -Force `
        -ErrorAction SilentlyContinue

        Start-Sleep -Milliseconds 1500

        Start-Process explorer.exe

        Write-Host '  完成' -ForegroundColor Green

    }
    else {

        Write-Host ''
        Write-Host '  已跳过刷新，可稍后手动重启资源管理器。' -ForegroundColor DarkGray

    }

}
else {

    Write-Host ''
    Write-Host '  没有需要修复的图标。' -ForegroundColor DarkGray

}


Wait-Exit
