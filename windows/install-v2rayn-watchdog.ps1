#requires -version 5.1
<#
  Keeps an already-configured v2rayN client running while the user is logged in.
  Subscription URL and refresh interval must be configured IN v2rayN.
  Does not touch v2rayN databases, subscription secrets, or proxy settings.
#>
[CmdletBinding()]
param(
  [ValidateSet('Install','Status','Uninstall')]
  [string]$Mode = 'Install',
  [string]$V2rayNExe,
  [ValidateRange(1,60)]
  [int]$CheckMinutes = 5
)
$ErrorActionPreference = 'Stop'
$taskName = 'v2rayN-24h-Watchdog'
$watchdogDir = Join-Path $env:LOCALAPPDATA 'v2rayN-24h'
$watchdogFile = Join-Path $watchdogDir 'watchdog.ps1'
if ($Mode -eq 'Uninstall') {
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
  Write-Host '已删除 v2rayN 保活计划任务；不会删除 v2rayN 或任何订阅配置。'
  exit 0
}
if ($Mode -eq 'Status') {
  $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if ($null -eq $task) { Write-Host '尚未安装保活计划任务。'; exit 1 }
  $task | Select-Object TaskName,State | Format-Table
  Get-ScheduledTaskInfo -TaskName $taskName | Select-Object LastRunTime,LastTaskResult,NextRunTime | Format-List
  exit 0
}
if ($PSVersionTable.PSEdition -ne 'Desktop' -and -not $IsWindows) {
  throw '本脚本仅适用于 Windows PowerShell。'
}
if (-not $V2rayNExe) {
  $process = Get-Process -Name 'v2rayN' -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($process) { try { $V2rayNExe = $process.Path } catch {} }
}
if (-not $V2rayNExe) {
  $possible = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\v2rayN\v2rayN.exe'),
    (Join-Path $env:LOCALAPPDATA 'v2rayN\v2rayN.exe'),
    (Join-Path $env:USERPROFILE 'Desktop\v2rayN\v2rayN.exe'),
    'C:\v2rayN\v2rayN.exe',
    'D:\v2rayN\v2rayN.exe',
    'E:\v2rayN\v2rayN.exe'
  )
  $V2rayNExe = $possible | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $V2rayNExe) {
  $V2rayNExe = Read-Host '请输入 v2rayN.exe 的完整路径'
}
if (-not (Test-Path -LiteralPath $V2rayNExe -PathType Leaf)) {
  throw '找不到 v2rayN.exe；没有更改任何计划任务。'
}
$resolved = (Resolve-Path -LiteralPath $V2rayNExe).ProviderPath
if ([IO.Path]::GetFileName($resolved) -ine 'v2rayN.exe') {
  throw '指定的文件不是 v2rayN.exe，已停止安装。'
}
New-Item -ItemType Directory -Force -Path $watchdogDir | Out-Null
$watchdog = @'
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Executable)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Executable -PathType Leaf)) { exit 2 }
$running = Get-Process -Name 'v2rayN' -ErrorAction SilentlyContinue
if ($running) { exit 0 }
try {
  Start-Process -FilePath $Executable -WorkingDirectory (Split-Path -Parent $Executable)
  exit 0
} catch {
  exit 3
}
'@
Set-Content -LiteralPath $watchdogFile -Value $watchdog -Encoding UTF8
$arguments = '-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + $watchdogFile + '" -Executable "' + $resolved + '"'
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arguments
$trigger = New-ScheduledTaskTrigger -Daily -At '00:00'
$trigger.Repetition.Interval = 'PT' + $CheckMinutes + 'M'
$trigger.Repetition.Duration = 'P1D'
$loginTrigger = New-ScheduledTaskTrigger -AtLogOn
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger @($trigger,$loginTrigger) -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $taskName
Write-Host ('已安装保活任务：每 ' + $CheckMinutes + ' 分钟检查一次 v2rayN 是否运行，登录时也会启动。')
Write-Host ('程序位置：' + $resolved)
Write-Host '注意：请在 v2rayN 的【订阅分组设置】中配置正确的 VLESS/VMess 等订阅并开启更新，间隔设为 30 分钟。'
Write-Host '注意：任务只能在 Windows 开机且当前用户已登录时执行，不保证节点始终可用。'
