# Боты и где что лежит

## 1. Учебный бот: @claudeunibot («Unibot»)
- Для чего: учёба и пересылка писем университета в Telegram.
- Токен: `C:\Users\User\.claude\channels\telegram\.env`. Его не нужно открывать или присылать в чат.
- Кто может писать: только ваш аккаунт (список `allowFrom` в `access.json`).
- Что его слушает: сессия `telegram-setup`.
- Задача по расписанию: «Университетская почта → Telegram», проверяет почту каждые 15 минут.

Запуск сессии, которая отвечает в боте:
```
cd C:\Users\User\telegram-setup
claude.cmd --channels plugin:telegram@claude-plugins-official
```

## 2. Личный ассистент (ещё не создан)
- Для чего: личные задачи, которые вы будете ставить из Telegram.
- Токен: пока нет. Создайте бота в @BotFather и сохраните токен в `C:\Users\User\.claude\channels\telegram-personal\.env` через `/telegram:configure` в отдельной сессии.
- Папка проекта: `C:\Users\User\personal-assistant`. Запуск будет через `start-assistant.cmd`, когда настроим.

## Файлы запуска и отправки
- Учебный бот: двойной клик по `C:\Users\User\telegram-setup\start-study.cmd`.
- Личный бот: двойной клик по `C:\Users\User\personal-assistant\start-assistant.cmd`.
- Отправка писем в Telegram из задачи по расписанию: скрипт `C:\Users\User\.claude\scheduled-tasks\university-mail-to-telegram\tg-send.ps1` (оформление, разбиение, фото и документы).
- Плагин Telegram включён только в проектах `telegram-setup` и `personal-assistant`, глобально он выключен.

## Памятка
- Один бот = одна сессия с каналом. Не запускайте два окна с одним и тем же ботом.
- Пока окно с каналом открыто, бот отвечает. Если закрыть окно, ответов не будет.
- Токен @claudeunibot уже был в чате. Когда всё заработает, сделайте `/revoke` в @BotFather и обновите `.env`.
