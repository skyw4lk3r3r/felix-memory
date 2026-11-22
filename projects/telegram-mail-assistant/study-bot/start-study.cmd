@echo off
rem Учебный бот @claudeunibot. Не запускайте второе окно с этим ботом.
set "PATH=%USERPROFILE%\.bun\bin;%PATH%"
set "TELEGRAM_STATE_DIR="
cd /d "%USERPROFILE%\telegram-setup"
claude.cmd --channels plugin:telegram@claude-plugins-official
