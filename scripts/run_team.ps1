<#
.SYNOPSIS
  家計のチームに、決まった依頼を自動で流します（タスクスケジューラから呼ぶ用）。

.DESCRIPTION
  - 雛形のフォルダ（このスクリプトの1つ上）で claude -p を実行します。
  - 許可するツールは、ファイルの読み書き（Read / Write / Edit / Glob / Grep）と
    サブエージェント（Agent）だけです。Bash / PowerShell / WebFetch / WebSearch は使わせません。
  - 結果は logs\YYYY-MM-DD_HHmm.log に保存します（家計の数字が入るので公開しないこと）。
  - 終わったら Windows の通知で知らせます（失敗したときも）。
  - 同じ期間（毎月なら同じ月、毎朝なら同じ日）にすでに成功していたら、何もせずに終わります。
    再実行のトリガーで2回目が動いても、二重に作業しないためです。

.PARAMETER Job
  Monthly：先月の資料を整理して、月次レポートを作る（毎月1日に動かす想定）
  Daily  ：今月の資料で、まだ台帳に入っていないものを整理する（毎朝動かす想定）

.PARAMETER Force
  同じ期間にすでに成功していても、もう一度実行します。

.EXAMPLE
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_team.ps1 -Job Monthly
#>
param(
    [ValidateSet('Monthly', 'Daily')]
    [string]$Job = 'Monthly',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# --- 場所 ---------------------------------------------------------------
$Root   = Split-Path -Parent $PSScriptRoot      # 雛形のフォルダ
$LogDir = Join-Path $Root 'logs'
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }

$Now     = Get-Date
$LogFile = Join-Path $LogDir ($Now.ToString('yyyy-MM-dd_HHmm') + '.log')

function Write-Log([string]$Message) {
    $line = '[' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + '] ' + $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

# --- Windows の通知（トースト） ------------------------------------------
function Show-Toast([string]$Title, [string]$Body) {
    try {
        [void][Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]
        [void][Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime]
        $esc  = [System.Security.SecurityElement]
        $xml  = New-Object Windows.Data.Xml.Dom.XmlDocument
        $xml.LoadXml('<toast><visual><binding template="ToastGeneric"><text>' + $esc::Escape($Title) +
                     '</text><text>' + $esc::Escape($Body) + '</text></binding></visual></toast>')
        # Windows PowerShell の名前で通知を出す
        $appId = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'
        $toast = New-Object Windows.UI.Notifications.ToastNotification $xml
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($appId).Show($toast)
    } catch {
        Write-Log ('通知を出せませんでした：' + $_.Exception.Message)
    }
}

# --- claude.exe を探す ---------------------------------------------------
function Find-Claude {
    # 1. PATH にあれば、それを使う
    $cmd = Get-Command 'claude' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }

    # 2. VS Code の拡張機能の中を探す。
    #    フォルダ名（anthropic.claude-code-<版>-...）は更新のたびに変わるので、いちばん新しい版を使う
    $extRoot = Join-Path $env:USERPROFILE '.vscode\extensions'
    if (Test-Path $extRoot) {
        $found = Get-ChildItem -Path $extRoot -Directory -Filter 'anthropic.claude-code-*' -ErrorAction SilentlyContinue |
            ForEach-Object {
                $exe = Join-Path $_.FullName 'resources\native-binary\claude.exe'
                if (Test-Path $exe) {
                    $ver = [version]'0.0.0'
                    if ($_.Name -match 'anthropic\.claude-code-(\d+\.\d+\.\d+)') { $ver = [version]$Matches[1] }
                    [pscustomobject]@{ Path = $exe; Version = $ver; Time = $_.LastWriteTime }
                }
            } |
            Sort-Object -Property Version, Time -Descending |
            Select-Object -First 1
        if ($found) { return $found.Path }
    }
    return $null
}

# --- 依頼の文と「同じ期間」の決め方 ---------------------------------------
switch ($Job) {
    'Monthly' {
        $target = $Now.AddMonths(-1)
        $period = $target.ToString('yyyy-MM')
        $Prompt = $target.ToString('yyyy') + '年' + $target.Month + '月の資料を整理して、月次レポートを作って。' +
                  'これは自動実行なので、家族への質問はせず、要確認は一覧にしてレポートに書いて。' +
                  '最後に、作ったファイルと要確認の件数を短くまとめて。'
    }
    'Daily' {
        $period = $Now.ToString('yyyy-MM-dd')
        $Prompt = $Now.ToString('yyyy') + '年' + $Now.Month + '月の資料フォルダに、まだ台帳に入っていない資料があれば整理して。' +
                  'これは自動実行なので、家族への質問はせず、要確認は一覧にして。' +
                  '新しい資料がなければ「新しい資料はありません」とだけ書いて。'
    }
}

$Marker = Join-Path $LogDir ('.last_success_' + $Job.ToLower() + '.txt')
if (-not $Force -and (Test-Path $Marker)) {
    $last = (Get-Content -Path $Marker -Encoding UTF8 -TotalCount 1)
    if ($last -eq $period) {
        Write-Log ($Job + '：' + $period + ' の分はすでに成功しています。何もせずに終わります。')
        exit 0
    }
}

# --- 実行 ---------------------------------------------------------------
$Claude = Find-Claude
if (-not $Claude) {
    Write-Log 'claude.exe が見つかりませんでした（PATH と VS Code の拡張機能のフォルダを探しました）。'
    Show-Toast '家計チーム：失敗' 'claude.exe が見つかりませんでした。ログを見てください。'
    exit 1
}

Write-Log ('開始：' + $Job + '（対象：' + $period + '）')
Write-Log ('claude：' + $Claude)
Write-Log ('依頼：' + $Prompt)

# 使えるツールを絞る（--tools）＋ 確認なしで使ってよいツール（--allowedTools）
# 確認が必要な操作は、だれも答えられないので断る（--permission-mode dontAsk）
$claudeArgs = @(
    '-p', $Prompt,
    '--tools', 'Read,Write,Edit,Glob,Grep,Agent',
    '--allowedTools', 'Read,Write,Edit,Glob,Grep,Agent',
    '--disallowedTools', 'Bash,PowerShell,WebFetch,WebSearch',
    '--permission-mode', 'dontAsk',
    '--output-format', 'text'
)

$exitCode = 1
try {
    Set-Location -Path $Root
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
    $ErrorActionPreference = 'Continue'
    $output = & $Claude @claudeArgs 2>&1 | ForEach-Object { "$_" }
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    Add-Content -Path $LogFile -Value $output -Encoding UTF8
} catch {
    $ErrorActionPreference = 'Stop'
    Write-Log ('実行中にエラー：' + $_.Exception.Message)
    $exitCode = 1
}

if ($exitCode -eq 0) {
    Set-Content -Path $Marker -Value $period -Encoding UTF8
    Write-Log ('終了：成功（終了コード 0）')
    Show-Toast '家計チーム：完了' ($Job + '（' + $period + '）が終わりました。ログ：' + (Split-Path -Leaf $LogFile))
} else {
    Write-Log ('終了：失敗（終了コード ' + $exitCode + '）')
    Show-Toast '家計チーム：失敗' ($Job + '（' + $period + '）が失敗しました。ログ：' + (Split-Path -Leaf $LogFile))
}
exit $exitCode
