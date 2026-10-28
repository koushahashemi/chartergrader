@echo off
setlocal
cd /d "%~dp0"
echo Charter Grader - one-time setup. Internet is required for downloads only.
echo This installs Python 3.12 and Ollama using Windows Package Manager.
echo The local model download is several GB. Close other large programs when grading.
where winget >nul 2>nul
if errorlevel 1 (
  echo Windows Package Manager was not found.
  echo Install App Installer from Microsoft Store, then run this file again.
  echo Alternatively install Python 3.12 from python.org and Ollama from ollama.com,
  echo then open a NEW command prompt and run: ollama pull qwen3:4b
  pause
  exit /b 1
)
py -3.12 -c "import tkinter" >nul 2>nul
if errorlevel 1 (
  winget install --id Python.Python.3.12 --exact --source winget --accept-package-agreements --accept-source-agreements
  if errorlevel 1 goto failed
)
where ollama >nul 2>nul
if not errorlevel 1 goto model
if exist "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" goto model
winget install --id Ollama.Ollama --exact --source winget --accept-package-agreements --accept-source-agreements
if errorlevel 1 goto failed
:model
set "CG_OLLAMA=ollama"
if exist "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" set "CG_OLLAMA=%LOCALAPPDATA%\Programs\Ollama\ollama.exe"
set "OLLAMA_HOST=127.0.0.1:11434"
set "OLLAMA_NO_CLOUD=1"
powershell -NoProfile -Command "try { $null=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 3; exit 0 } catch { exit 1 }"
if not errorlevel 1 goto pull
start "Ollama local server" /min "%CG_OLLAMA%" serve
powershell -NoProfile -Command "for($i=0;$i -lt 30;$i++){try{$null=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2; exit 0}catch{Start-Sleep -Seconds 1}};exit 1"
if errorlevel 1 goto failed
:pull
"%CG_OLLAMA%" pull qwen3:4b
if errorlevel 1 goto failed
echo Setup finished. You can disconnect the internet and run Start Grader.bat.
pause
exit /b 0
:failed
echo Setup did not finish. Keep the error message above and ask for help.
echo No student documents were read or uploaded by this setup script.
pause
exit /b 1
