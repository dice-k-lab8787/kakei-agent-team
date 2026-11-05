<#
.SYNOPSIS
  run_team.ps1 を Windows のタスクスケジューラに登録します（解除もできます）。

.DESCRIPTION
  登録するタスクの設定：
  - いつ：毎月1日 8:00（-Job Daily なら毎朝 8:00）。時刻は -At で変えられます
  - 再実行：同じ日の -RetryAfterMinutes 分後（標準は60分後）にもう1回動かすトリガーを足します。
    1回目が成功していれば、run_team.ps1 が「すでに成功」と判断して何もしません
  - スリープを解除して実行する：オン
  - 予定の時刻に動けなかったら、できるようになりしだい動かす：オン
  - 実行時間の上限：30分
  - バッテリーで動いているときも実行する
  - ログオンしているときだけ動く（パスワードを保存しない。通知を画面に出すため）

  管理者の権限は要りません。

.EXAMPLE
  .\scripts\register_task.ps1                  # 毎月1日 8:00 と 9:00 に登録
  .\scripts\register_task.ps1 -Job Daily       # 毎朝 8:00 と 9:00 に登録
  .\scripts\register_task.ps1 -Unregister      # 毎月のタスクを解除
  .\scripts\register_task.ps1 -Job Daily -Unregister
#>
param(
    [ValidateSet('Monthly', 'Daily')]
    [string]$Job = 'Monthly',
    [string]$At = '08:00',
    [int]$RetryAfterMinutes = 60,
    [switch]$Unregister
)

$ErrorActionPreference = 'Stop'

$TaskName  = 'kakei-agent-team ' + $Job
$Root      = Split-Path -Parent $PSScriptRoot
$RunScript = Join-Path $PSScriptRoot 'run_team.ps1'

$service = New-Object -ComObject 'Schedule.Service'
$service.Connect()
$folder = $service.GetFolder('\')

# --- 解除 ---------------------------------------------------------------
if ($Unregister) {
    try {
        $folder.DeleteTask($TaskName, 0)
        Write-Host ('タスク「' + $TaskName + '」を解除しました。')
    } catch {
        Write-Host ('タスク「' + $TaskName + '」は登録されていません。')
    }
    exit 0
}

if (-not (Test-Path $RunScript)) { throw ('run_team.ps1 が見つかりません：' + $RunScript) }

# --- 最初に動く日時 -------------------------------------------------------
$time  = [datetime]::ParseExact($At, 'HH:mm', [Globalization.CultureInfo]::InvariantCulture)
$today = (Get-Date).Date
if ($Job -eq 'Monthly') {
    $first = (Get-Date -Year $today.Year -Month $today.Month -Day 1).Date.AddMonths(1)   # 来月の1日
} else {
    $first = $today.AddDays(1)                                                           # 明日
}
$start1 = $first.AddHours($time.Hour).AddMinutes($time.Minute)
$start2 = $start1.AddMinutes($RetryAfterMinutes)

# --- タスクの中身 ---------------------------------------------------------
$def = $service.NewTask(0)
$def.RegistrationInfo.Description = '家計のチーム（kakei-agent-team）を自動で動かします。中身：' + $RunScript
$def.Principal.LogonType = 3          # ログオンしているときだけ（パスワードを保存しない）
$def.Principal.RunLevel  = 0          # 管理者の権限なし

$s = $def.Settings
$s.Enabled                    = $true
$s.WakeToRun                  = $true     # スリープを解除して実行する
$s.StartWhenAvailable         = $true     # 予定の時刻を過ぎていたら、できるようになりしだい実行
$s.ExecutionTimeLimit         = 'PT30M'   # 実行時間の上限：30分
$s.DisallowStartIfOnBatteries = $false
$s.StopIfGoingOnBatteries     = $false
$s.MultipleInstances          = 2         # 前の実行が続いていたら、新しい実行はしない

foreach ($start in @($start1, $start2)) {
    if ($Job -eq 'Monthly') {
        $t = $def.Triggers.Create(4)       # 毎月
        $t.DaysOfMonth  = 1                # 1日（ビットで指定。1 = 1日）
        $t.MonthsOfYear = 4095             # 1〜12月すべて
    } else {
        $t = $def.Triggers.Create(2)       # 毎日
        $t.DaysInterval = 1
    }
    $t.StartBoundary = $start.ToString('yyyy-MM-ddTHH:mm:ss')
    $t.Enabled = $true
}

$action = $def.Actions.Create(0)
$action.Path             = 'powershell.exe'
$action.Arguments        = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $RunScript + '" -Job ' + $Job
$action.WorkingDirectory = $Root

# 6 = 作成または更新、3 = ログオンしているユーザーとして実行
[void]$folder.RegisterTaskDefinition($TaskName, $def, 6, $null, $null, 3)

Write-Host ('タスク「' + $TaskName + '」を登録しました。')
Write-Host ('  1回目：' + $start1.ToString('yyyy-MM-dd HH:mm') + ' から')
Write-Host ('  再実行：' + $start2.ToString('yyyy-MM-dd HH:mm') + ' から（1回目が成功していれば何もしません）')
Write-Host '  確認：タスク スケジューラ（taskschd.msc）の「タスク スケジューラ ライブラリ」'
Write-Host '  注意：スリープ解除には、電源オプションの「スリープ解除タイマーの許可」が有効になっている必要があります。'
