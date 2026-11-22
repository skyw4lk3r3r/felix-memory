# Номер письма в mail-index.json.
#   mail-index-add.ps1 -Id "<ID>" -From "Имя" -Address "a@b.c" -Subject "Тема" -Date "дата"
# Если письмо с таким ID уже есть, печатает его номер, иначе создаёт новый. Вывод: NUMBER: N
param(
    [string]$Id,
    [string]$DataFile,
    [string]$From,
    [string]$Address,
    [string]$Subject,
    [string]$Date
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$file = Join-Path $PSScriptRoot 'mail-index.json'
if ($DataFile) { $l = [System.IO.File]::ReadAllLines($DataFile, $utf8); $Id = $l[0]; $From = $l[1]; $Address = $l[2]; $Subject = $l[3]; $Date = $l[4] }
if (-not $Id) { Write-Output 'ERROR: no id'; exit 1 }
$entries = [ordered]@{}
if (Test-Path -LiteralPath $file) {
    $raw = [System.IO.File]::ReadAllText($file, $utf8)
    if ($raw.Trim()) {
        $obj = $raw | ConvertFrom-Json
        foreach ($p in $obj.PSObject.Properties) {
            $entries[$p.Name] = [ordered]@{ id = [string]$p.Value.id; from = [string]$p.Value.from; address = [string]$p.Value.address; subject = [string]$p.Value.subject; date = [string]$p.Value.date }
        }
    }
}
foreach ($k in $entries.Keys) { if ($entries[$k].id -eq $Id) { Write-Output "NUMBER: $k"; exit 0 } }
$max = 0
foreach ($k in $entries.Keys) { $n = 0; if ([int]::TryParse($k, [ref]$n) -and $n -gt $max) { $max = $n } }
$num = $max + 1
$entries["$num"] = [ordered]@{ id = $Id; from = $From; address = $Address; subject = $Subject; date = $Date }
[System.IO.File]::WriteAllText($file, ($entries | ConvertTo-Json -Depth 5), $utf8)
$null = [System.IO.File]::ReadAllText($file, $utf8) | ConvertFrom-Json
Write-Output "NUMBER: $num"