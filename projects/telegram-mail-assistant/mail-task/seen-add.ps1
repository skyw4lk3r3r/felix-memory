# Безопасная работа со списком обработанных писем seen.json.
#   Добавить:   seen-add.ps1 -Keys "id:<ID>","отправитель|тема|дата"
#   Проверить:  seen-add.ps1 -Check -Keys "id:<ID>","отправитель|тема|дата"   (печатает SEEN или NEW для каждого ключа)
# Файл всегда остаётся плоским JSON-массивом строк. Никогда не записывай seen.json другим способом.
param(
    [string[]]$Keys,
    [string]$KeysFile,
    [switch]$Check
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = Join-Path $PSScriptRoot 'seen.json'
if ($KeysFile) { $Keys = @($Keys) + @([System.IO.File]::ReadAllLines($KeysFile, $utf8) | Where-Object { $_.Trim() }) }

function Get-Flat($x) {
    if ($null -eq $x) { return }
    if ($x -is [string]) { $t = $x.Trim(); if ($t) { $t }; return }
    if ($x -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in $x.PSObject.Properties) { if ($p.Name -eq 'value') { Get-Flat $p.Value } }
        return
    }
    if ($x -is [System.Collections.IEnumerable]) { foreach ($i in $x) { Get-Flat $i } }
}

$existing = New-Object System.Collections.Generic.List[string]
if (Test-Path -LiteralPath $file) {
    $raw = [System.IO.File]::ReadAllText($file, $utf8)
    if ($raw.Trim()) { foreach ($s in (Get-Flat ($raw | ConvertFrom-Json))) { if (-not $existing.Contains($s)) { $existing.Add($s) } } }
}

# Нормализованный ключ текстового ключа "отправитель|тема|дата": тема + время + день-месяц (без отправителя).
function Get-Norm([string]$k) {
    if ($k.StartsWith('id:')) { return $null }
    $parts = $k.Split('|')
    if ($parts.Count -lt 3) { return $null }
    $date = $parts[$parts.Count - 1]
    $subject = ($parts[1..($parts.Count - 2)] -join '|').ToLowerInvariant()
    $subject = ([regex]::Replace($subject, '\s+', ' ')).Trim()
    $time = ''
    $tm = [regex]::Match($date, '(\d{1,2}):(\d{2})')
    if ($tm.Success) { $time = '{0:00}:{1}' -f [int]$tm.Groups[1].Value, $tm.Groups[2].Value }
    $dm = ''
    $dmm = [regex]::Match($date, '(\d{1,2})-([A-Za-z]{3})')
    if ($dmm.Success) { $dm = ('{0}-{1}' -f [int]$dmm.Groups[1].Value, $dmm.Groups[2].Value.ToLowerInvariant()) }
    return [pscustomobject]@{ Subject = $subject; Time = $time; Dm = $dm }
}
$norms = New-Object System.Collections.Generic.List[object]
foreach ($e in $existing) { $n = Get-Norm $e; if ($n) { $norms.Add($n) } }
function Test-Seen([string]$key) {
    $k = $key.Trim()
    if ($existing.Contains($k)) { return $true }
    $n = Get-Norm $k
    if (-not $n -or -not $n.Time) { return $false }
    foreach ($x in $norms) {
        if ($x.Subject -eq $n.Subject -and $x.Time -eq $n.Time -and ((-not $x.Dm) -or (-not $n.Dm) -or $x.Dm -eq $n.Dm)) { return $true }
    }
    return $false
}
if ($Check) {
    foreach ($k in $Keys) { if (-not $k.Trim()) { continue }; if (Test-Seen $k) { "SEEN: $k" } else { "NEW: $k" } }
    exit 0
}

foreach ($k in $Keys) { $t = $k.Trim(); if ($t -and -not $existing.Contains($t)) { $existing.Add($t) } }
$lines = $existing | ForEach-Object { '    "' + $_.Replace('\', '\\').Replace('"', '\"') + '"' }
$json = "[`n" + ($lines -join ",`n") + "`n]`n"
[System.IO.File]::WriteAllText($file, $json, $utf8)
$back = [System.IO.File]::ReadAllText($file, $utf8) | ConvertFrom-Json
Write-Output "OK: $(@($back).Count) entries"