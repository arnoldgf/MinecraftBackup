@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

REM ============================================================
REM  Бэкап мира Minecraft с остановкой/запуском сервера
REM  Автор: <ваше имя>
REM  Расписание: раз в неделю (Планировщик задач Windows)
REM ============================================================

REM === Настройки ===
set "SERVER_DIR=C:\mine_server"
set "WORLD_DIR=%SERVER_DIR%\world"
set "BACKUP_DIR=%SERVER_DIR%\backup"
set "LOG_FILE=%BACKUP_DIR%\backup.log"
set "RETENTION_DAYS=30"
set "SERVER_TITLE=Minecraft Server"
set "START_SERVER_BAT=%SERVER_DIR%\start_server.bat"
set "WAIT_JAVA_MAX=180"

REM === Формирование даты ===
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set "DT=%%I"
set "DATE=%DT:~0,4%-%DT:~4,2%-%DT:~6,2%_%DT:~8,2%-%DT:~10,2%-%DT:~12,2%"
set "ARCHIVE_NAME=world_%DATE%.zip"
set "ARCHIVE_PATH=%BACKUP_DIR%\%ARCHIVE_NAME%"

REM === Создание папки backup ===
if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

call :log "==================================================="
call :log "=== Запуск бэкапа мира Minecraft ==="
call :log "==================================================="

REM === Проверка папки world ===
if not exist "%WORLD_DIR%" (
    call :log "ОШИБКА: Папка %WORLD_DIR% не найдена. Бэкап прерван."
    endlocal
    exit /b 1
)

REM ============================================================
REM  ШАГ 1. Остановка сервера
REM ============================================================
call :log "Остановка Minecraft-сервера..."

REM Отправляем "stop" через имитацию нажатия клавиш в окно сервера
REM (мягкая остановка — сервер успевает сохранить мир)
powershell -NoProfile -Command ^
  "$wshell = New-Object -ComObject wscript.shell; " ^
  "if ($wshell.AppActivate('%SERVER_TITLE%')) { " ^
  "  Start-Sleep -Milliseconds 500; " ^
  "  $wshell.SendKeys('stop~'); " ^
  "  Write-Host 'STOP_SENT'; " ^
  "} else { Write-Host 'WINDOW_NOT_FOUND' }"

REM Ждём, пока java.exe завершится
set /a WAIT=0
:waitjava
tasklist /FI "IMAGENAME eq java.exe" 2>nul | find /I "java.exe" >nul
if not errorlevel 1 (
    timeout /t 2 /nobreak >nul
    set /a WAIT+=2
    if !WAIT! LSS %WAIT_JAVA_MAX% goto waitjava
    call :log "ПРЕДУПРЕЖДЕНИЕ: java.exe не завершился за %WAIT_JAVA_MAX% сек."
    call :log "Пробую принудительное завершение..."
    taskkill /IM java.exe /F >nul 2>&1
    timeout /t 3 /nobreak >nul
) else (
    call :log "Сервер остановлен корректно (java.exe завершён)."
)

REM Финальная проверка: остался ли java.exe
tasklist /FI "IMAGENAME eq java.exe" 2>nul | find /I "java.exe" >nul
if not errorlevel 1 (
    call :log "ОШИБКА: java.exe всё ещё работает. Бэкап прерван во избежание порчи мира."
    call :log "Запускаю сервер обратно..."
    start "" "%START_SERVER_BAT%"
    endlocal
    exit /b 1
)

REM ============================================================
REM  ШАГ 2. Создание архива
REM ============================================================
call :log "Создание архива: %ARCHIVE_NAME%"

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { " ^
  "  Compress-Archive -Path '%WORLD_DIR%\*' -DestinationPath '%ARCHIVE_PATH%' -Force -ErrorAction Stop; " ^
  "  exit 0 " ^
  "} catch { " ^
  "  Write-Host ('POWERSHELL: ' + $_.Exception.Message); " ^
  "  exit 1 " ^
  "}"

if not exist "%ARCHIVE_PATH%" (
    call :log "ОШИБКА: Архив не был создан! Смотрите сообщение POWERSHELL выше."
    call :log "Запускаю сервер обратно..."
    start "" "%START_SERVER_BAT%"
    endlocal
    exit /b 1
)

REM === Размер архива ===
for %%A in ("%ARCHIVE_PATH%") do set "SIZE=%%~zA"
set /a SIZE_MB=!SIZE!/1048576
call :log "Архив успешно создан: %ARCHIVE_NAME% (Размер: !SIZE_MB! МБ)"

REM ============================================================
REM  ШАГ 3. Удаление старых архивов
REM ============================================================
call :log "Удаление архивов старше %RETENTION_DAYS% дней..."
set "DELETED=0"
forfiles /p "%BACKUP_DIR%" /m "world_*.zip" /d -%RETENTION_DAYS% /c "cmd /c del @path & echo deleted" > "%TEMP%\deleted.txt" 2>nul
for /f %%C in ('find /c /v "" ^< "%TEMP%\deleted.txt"') do set "DELETED=%%C"
del "%TEMP%\deleted.txt" >nul 2>&1
call :log "Удалено старых архивов: %DELETED%"

REM ============================================================
REM  ШАГ 4. Запуск сервера обратно
REM ============================================================
if not exist "%START_SERVER_BAT%" (
    call :log "ПРЕДУПРЕЖДЕНИЕ: %START_SERVER_BAT% не найден. Сервер нужно запустить вручную!"
) else (
    call :log "Запуск сервера..."
    start "" "%START_SERVER_BAT%"
    timeout /t 3 /nobreak >nul
    call :log "Команда запуска отправлена."
)

call :log "==================================================="
call :log "=== Бэкап завершён успешно ==="
call :log "==================================================="

endlocal
exit /b 0

REM ============================================================
REM  Функция логирования
REM ============================================================
:log
echo [%DATE% %TIME:~0,8%] %~1>>"%LOG_FILE%"
echo [%DATE% %TIME:~0,8%] %~1
exit /b 0