@echo off
rem Личный ассистент: бот @claudeworkerassistantbot. Не запускайте второе окно с этим ботом.
set "PATH=%USERPROFILE%\.bun\bin;%PATH%"
set "TELEGRAM_STATE_DIR=%USERPROFILE%\.claude\channels\telegram-personal"
cd /d "%USERPROFILE%\personal-assistant"
claude.cmd --channels plugin:telegram@claude-plugins-official
