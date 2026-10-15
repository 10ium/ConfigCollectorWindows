# Freedom Config Collector v2 - Windows System Tray Helper
param(
    [int]$Port = 18888,
    [string]$IconPath = ""
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BaseDir = Split-Path -Parent $ScriptDir

if (-not $IconPath -or -not (Test-Path $IconPath)) {
    $IconPath = Join-Path $BaseDir "app_icon.ico"
}

$notify = New-Object System.Windows.Forms.NotifyIcon
if (Test-Path $IconPath) {
    $notify.Icon = New-Object System.Drawing.Icon($IconPath)
} else {
    $notify.Icon = [System.Drawing.SystemIcons]::Application
}

$notify.Text = "Freedom Config Collector v2"
$notify.Visible = $true

# Context Menu
$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

$itemOpen = $contextMenu.Items.Add("🚀 باز کردن داشبورد Freedom Collector")
$itemOpen.Font = New-Object System.Drawing.Font($itemOpen.Font, [System.Drawing.FontStyle]::Bold)
$itemOpen.add_Click({
    $url = "http://127.0.0.1:$Port"
    $edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    if (Test-Path $edge) {
        Start-Process $edge -ArgumentList "--app=$url", "--window-size=1280,870"
    } else {
        Start-Process $url
    }
})

$contextMenu.Items.Add("-") | Out-Null

$itemRun = $contextMenu.Items.Add("▶️ اجرای فوری استخراج و آزمون‌ها")
$itemRun.add_Click({
    try {
        Invoke-RestMethod -Uri "http://127.0.0.1:$Port/api/run" -Method Post -TimeoutSec 3 | Out-Null
        $notify.ShowBalloonTip(3000, "Freedom Collector", "فرآیند استخراج و آزمون آغاز شد.", [System.Windows.Forms.ToolTipIcon]::Info)
    } catch {}
})

$contextMenu.Items.Add("-") | Out-Null

$itemExit = $contextMenu.Items.Add("❌ خروج کامل از نرم‌افزار")
$itemExit.add_Click({
    $notify.Visible = $false
    $notify.Dispose()
    [System.Windows.Forms.Application]::Exit()
    Stop-Process -Id $PID -Force
})

$notify.ContextMenuStrip = $contextMenu

# Double click action
$notify.add_DoubleClick({
    $url = "http://127.0.0.1:$Port"
    $edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
    if (Test-Path $edge) {
        Start-Process $edge -ArgumentList "--app=$url", "--window-size=1280,870"
    } else {
        Start-Process $url
    }
})

# Show startup notification balloon
$notify.ShowBalloonTip(4000, "Freedom Config Collector v2", "نرم‌افزار در پس‌زمینه و کنار ساعت ویندوز در حال اجراست.", [System.Windows.Forms.ToolTipIcon]::Info)

# Keep running
[System.Windows.Forms.Application]::Run()
