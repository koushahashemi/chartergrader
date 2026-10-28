@echo off
setlocal
cd /d "%~dp0"
set "OLLAMA_HOST=127.0.0.1:11434"
set "OLLAMA_NO_CLOUD=1"
set "CG_OLLAMA=ollama"
if exist "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" set "CG_OLLAMA=%LOCALAPPDATA%\Programs\Ollama\ollama.exe"
py -3.12 -c "import tkinter" >nul 2>nul
if errorlevel 1 (
  echo Python 3.12 is unavailable. Run Setup.bat first, then reopen this file.
  pause
  exit /b 1
)
powershell -NoProfile -Command "try{$null=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 3;exit 0}catch{exit 1}"
if not errorlevel 1 goto launch
start "Ollama local server" /min "%CG_OLLAMA%" serve
powershell -NoProfile -Command "for($i=0;$i -lt 30;$i++){try{$null=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2;exit 0}catch{Start-Sleep -Seconds 1}};exit 1"
if errorlevel 1 (
  echo Ollama did not start. Run Setup.bat or open the Ollama app and try again.
  pause
  exit /b 1
)
:launch
py -3.12 grader.py
if errorlevel 1 pause
