# Отправка в Telegram через Bot API (учебный бот). Токен и chat_id берутся из файлов, токен не выводится.
#
# Режимы:
#   Письмо (оформленное сообщение):
#     -Number 3 -From "Имя" -Subject "Тема" -Date "22 нояб, 23:18" -BodyFile тело.txt [-Attachments 2]
#   Файл-вложение:
#     -File путь [-Number 3]          (подпись «Вложение к письму №3» + имя файла)
#   Простой текст (с разбиением на части):
#     -TextFile путь.txt
#
# Запуск: powershell -NoProfile -ExecutionPolicy Bypass -File tg-send.ps1 <параметры>
param(
    [int]$Number,
    [string]$From,
    [string]$Subject,
    [string]$Date,
    [string]$BodyFile,
    [int]$Attachments = 0,
    [string]$File,
    [string]$MetaFile,
    [string]$TextFile
)

$ErrorActionPreference = 'Stop'
$base = Join-Path $env:USERPROFILE '.claude\channels\telegram'
$utf8 = New-Object System.Text.UTF8Encoding($false)
if ($MetaFile) { $m = [System.IO.File]::ReadAllLines($MetaFile, $utf8); $From = $m[0]; $Subject = $m[1]; $Date = $m[2] }
$envRaw = [System.IO.File]::ReadAllText((Join-Path $base '.env'), $utf8)
$token = [regex]::Match($envRaw, 'TELEGRAM_BOT_TOKEN=([^\r\n]+)').Groups[1].Value.Trim()
if (-not $token) { Write-Output 'ERROR: token not found'; exit 1 }
$access = [System.IO.File]::ReadAllText((Join-Path $base 'access.json'), $utf8) | ConvertFrom-Json
$chat = [string]@($access.allowFrom)[0]
if (-not $chat) { Write-Output 'ERROR: no allowed chat'; exit 1 }

Add-Type -AssemblyName System.Net.Http
$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromSeconds(120)

function Invoke-Telegram([string]$method, [hashtable]$fields, [string]$fileField, [string]$filePath) {
    $content = New-Object System.Net.Http.MultipartFormDataContent
    foreach ($k in $fields.Keys) {
        $content.Add((New-Object System.Net.Http.StringContent([string]$fields[$k], $utf8)), $k)
    }
    $stream = $null
    try {
        if ($filePath) {
            $stream = [System.IO.File]::OpenRead($filePath)
            $sc = New-Object System.Net.Http.StreamContent($stream)
            $content.Add($sc, $fileField, [System.IO.Path]::GetFileName($filePath))
        }
        $resp = $client.PostAsync("https://api.telegram.org/bot$token/$method", $content).Result
        return $resp.Content.ReadAsStringAsync().Result
    } finally {
        if ($stream) { $stream.Dispose() }
    }
}

function Test-Ok([string]$body) { return ($body -match '"ok"\s*:\s*true') }
function Hide-Token([string]$s) { return ($s -replace [regex]::Escape($token), '<TOKEN>') }
function Esc([string]$s) { return $s.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;') }
function Strip-Tags([string]$s) {
    $t = [regex]::Replace($s, '<[^>]+>', '')
    return $t.Replace('&lt;', '<').Replace('&gt;', '>').Replace('&amp;', '&')
}

function Split-Text([string]$text, [int]$limit) {
    $chunks = New-Object System.Collections.Generic.List[string]
    $current = New-Object System.Text.StringBuilder
    foreach ($line in ($text -split "`r?`n")) {
        while ($line.Length -gt $limit) {
            if ($current.Length -gt 0) { $chunks.Add($current.ToString().TrimEnd()); [void]$current.Clear() }
            $chunks.Add($line.Substring(0, $limit))
            $line = $line.Substring($limit)
        }
        if (($current.Length + $line.Length + 1) -gt $limit) {
            $chunks.Add($current.ToString().TrimEnd()); [void]$current.Clear()
        }
        [void]$current.Append($line).Append("`n")
    }
    if ($current.ToString().Trim().Length -gt 0) { $chunks.Add($current.ToString().TrimEnd()) }
    return $chunks
}

# Отправка одного HTML-сообщения; при ошибке разметки отправляет чистый текст.
function Send-Message([string]$html) {
    $body = Invoke-Telegram 'sendMessage' @{ chat_id = $chat; text = $html; parse_mode = 'HTML'; disable_web_page_preview = 'true' } $null $null
    if (Test-Ok $body) { return $true }
    $body2 = Invoke-Telegram 'sendMessage' @{ chat_id = $chat; text = (Strip-Tags $html); disable_web_page_preview = 'true' } $null $null
    if (Test-Ok $body2) { return $true }
    Write-Output ('ERROR: sendMessage failed: ' + (Hide-Token $body2))
    return $false
}

try {
    if ($BodyFile -and $Number) {
        # --- оформленное письмо ---
        $text = [System.IO.File]::ReadAllText($BodyFile, $utf8).Trim()
        if (-not $text) { $text = '(пустое письмо)' }
        $head = "📩 <b>Письмо №$Number</b>`n<b>От:</b> $(Esc $From)`n<b>Тема:</b> $(Esc $Subject)`n<b>Дата:</b> $(Esc $Date)"
        if ($Attachments -gt 0) { $head += "`n📎 <b>Вложений:</b> $Attachments (идут следом)" }
        $footer = "↩️ <i>Ответить: напишите «ответ №$Number» и что сказать</i>"
        $chunks = @(Split-Text $text 3000)
        $total = $chunks.Count
        for ($i = 0; $i -lt $total; $i++) {
            if ($i -eq 0) { $msg = $head + "`n──────────`n" + (Esc $chunks[$i]) }
            else { $msg = "<i>Письмо №$Number, продолжение $($i + 1)/$total</i>`n──────────`n" + (Esc $chunks[$i]) }
            if ($i -eq ($total - 1)) { $msg += "`n`n" + $footer }
            if (-not (Send-Message $msg)) { exit 1 }
        }
        Write-Output "OK: mail №$Number sent in $total message(s)"
        exit 0
    }
    if ($File) {
        # --- файл (вложение) ---
        if (-not (Test-Path -LiteralPath $File)) { Write-Output 'ERROR: file not found'; exit 1 }
        $name = [System.IO.Path]::GetFileName($File)
        $fields = @{ chat_id = $chat; parse_mode = 'HTML' }
        if ($Number) { $fields['caption'] = "📎 <b>Вложение к письму №$Number</b>`n$(Esc $name)" }
        else { $fields['caption'] = "📎 $(Esc $name)" }
        $ext = [System.IO.Path]::GetExtension($File).ToLowerInvariant()
        $size = (Get-Item -LiteralPath $File).Length
        $mode = 'document'
        $body = $null
        if (($ext -in '.jpg', '.jpeg', '.png', '.webp', '.gif') -and $size -le 9MB) {
            $body = Invoke-Telegram 'sendPhoto' $fields 'photo' $File
            if (Test-Ok $body) { $mode = 'photo' } else { $body = $null }
        }
        if (-not $body) {
            $body = Invoke-Telegram 'sendDocument' $fields 'document' $File
            $mode = 'document'
        }
        if (-not (Test-Ok $body)) { Write-Output ('ERROR: file send failed: ' + (Hide-Token $body)); exit 1 }
        Write-Output "OK: sent file as $mode"
        exit 0
    }
    if ($TextFile) {
        # --- простой текст ---
        $text = [System.IO.File]::ReadAllText($TextFile, $utf8)
        if (-not $text.Trim()) { Write-Output 'ERROR: empty text'; exit 1 }
        $n = 0
        foreach ($chunk in (Split-Text $text 4000)) {
            if (-not (Send-Message (Esc $chunk))) { exit 1 }
            $n++
        }
        Write-Output "OK: sent $n text message(s)"
        exit 0
    }
    Write-Output 'ERROR: specify -BodyFile with -Number, or -File, or -TextFile'
    exit 1
} catch {
    Write-Output ('ERROR: ' + (Hide-Token $_.Exception.Message))
    exit 1
}
