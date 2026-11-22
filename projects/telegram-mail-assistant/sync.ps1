# Копирует из рабочих папок в репозиторий только код, правила и настройки. Секреты и личные данные не копируются.
# Запуск: powershell -NoProfile -ExecutionPolicy Bypass -File sync.ps1
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$u = $env:USERPROFILE
$task = "$u\.claude\scheduled-tasks\university-mail-to-telegram"
$map = @(
    @("$task\SKILL.md",                                   'mail-task\SKILL.md'),
    @("$task\tg-send.ps1",                                'mail-task\tg-send.ps1'),
    @("$task\seen-add.ps1",                               'mail-task\seen-add.ps1'),
    @("$task\mail-index-add.ps1",                         'mail-task\mail-index-add.ps1'),
    @("$u\telegram-setup\CLAUDE.md",                      'study-bot\CLAUDE.md'),
    @("$u\telegram-setup\start-study.cmd",                'study-bot\start-study.cmd'),
    @("$u\telegram-setup\.claude\settings.json",          'study-bot\.claude\settings.json'),
    @("$u\telegram-setup\.claude\skills\telegram-reply\SKILL.md", 'study-bot\.claude\skills\telegram-reply\SKILL.md'),
    @("$u\personal-assistant\CLAUDE.md",                  'personal-assistant\CLAUDE.md'),
    @("$u\personal-assistant\start-assistant.cmd",        'personal-assistant\start-assistant.cmd'),
    @("$u\personal-assistant\BOTS.md",                    'personal-assistant\BOTS.md'),
    @("$u\personal-assistant\tasks.md",                   'personal-assistant\tasks.md'),
    @("$u\personal-assistant\.claude\settings.json",      'personal-assistant\.claude\settings.json'),
    @("$u\personal-assistant\.claude\skills\telegram-tasks\SKILL.md", 'personal-assistant\.claude\skills\telegram-tasks\SKILL.md')
)
$copied = 0
foreach ($m in $map) {
    if (Test-Path -LiteralPath $m[0]) {
        $dest = Join-Path $repo $m[1]
        New-Item -ItemType Directory -Force -Path (Split-Path $dest) | Out-Null
        Copy-Item -LiteralPath $m[0] -Destination $dest -Force
        $copied++
    } else { Write-Output "skipped (missing): $($m[0])" }
}
Write-Output "copied $copied files"