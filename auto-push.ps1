$ErrorActionPreference = "Stop"
$git = "C:\Program Files\Git\cmd\git.exe"
$files = @("app.js", "index.html", "styles.css")
$root = Get-Location

if (-not (Test-Path $git)) {
  throw "Git was not found at $git"
}

Write-Host "FORMIX auto-push started for $root" -ForegroundColor Green
Write-Host "Changes will be pushed 3 seconds after the last save." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop." -ForegroundColor Yellow

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $root
$watcher.Filter = "*.*"
$watcher.NotifyFilter = [IO.NotifyFilters]::LastWrite -bor [IO.NotifyFilters]::FileName
$watcher.EnableRaisingEvents = $true

$timer = New-Object System.Timers.Timer
$timer.Interval = 3000
$timer.AutoReset = $false

$pushChanges = {
  try {
    $status = & $git -C $root status --porcelain -- $files
    if (-not $status) { return }

    & $git -C $root add -- $files
    & $git -C $root commit -m "Auto update FORMIX"
    & $git -C $root push
    Write-Host "FORMIX pushed to GitHub: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Green
  } catch {
    Write-Host "Auto sync failed: $($_.Exception.Message)" -ForegroundColor Red
  }
}

$onChange = {
  $timer.Stop()
  $timer.Start()
}

Register-ObjectEvent -InputObject $watcher -EventName Changed -Action $onChange | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Created -Action $onChange | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Deleted -Action $onChange | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Renamed -Action $onChange | Out-Null
Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action $pushChanges | Out-Null

try {
  while ($true) {
    Wait-Event -Timeout 3600 | Out-Null
  }
} finally {
  $watcher.Dispose()
  $timer.Dispose()
  Get-EventSubscriber | Unregister-Event
}
