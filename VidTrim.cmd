@echo off
set "PS51=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS51%" set "PS51=powershell"
"%PS51%" -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0VidTrim.ps1"
if errorlevel 1 (
  echo.
  echo VidTrim hit an error and exited early. This window is staying open
  echo so the message above can be read or screenshotted.
  pause
)
