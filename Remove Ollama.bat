@echo off
setlocal
title Remove Charter Grader model and Ollama
echo This removes the qwen3:4b model and uninstalls Ollama.
echo Python, Charter Grader, documents, and feedback will be kept.
echo Other downloaded models will not be deliberately deleted.
echo Close Charter Grader before continuing.
echo.
pause

set "CG_OLLAMA="
set "CG_MODEL_FAILED=0"
where ollama >nul 2>nul
if not errorlevel 1 set "CG_OLLAMA=ollama"
if exist "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" set "CG_OLLAMA=%LOCALAPPDATA%\Programs\Ollama\ollama.exe"
set "OLLAMA_HOST=127.0.0.1:11434"
set "OLLAMA_NO_CLOUD=1"
if not defined CG_OLLAMA goto no_model_tool

echo Checking the local Ollama service...
powershell -NoProfile -Command "try { $null=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 3; exit 0 } catch { exit 1 }"
if not errorlevel 1 goto remove_model
start "Temporary local Ollama server" /min "%CG_OLLAMA%" serve
powershell -NoProfile -Command "for($i=0;$i -lt 20;$i++){try{$null=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2; exit 0}catch{Start-Sleep -Seconds 1}};exit 1"
if errorlevel 1 goto model_failed

:remove_model
echo Removing the grading model...
powershell -NoProfile -Command "$ErrorActionPreference='Stop'; try { $tags=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 10; if (@($tags.models | Where-Object { $_.name -eq 'qwen3:4b' }).Count -eq 0) { Write-Host 'The grading model is already absent.'; exit 0 }; $body=@{model='qwen3:4b'} | ConvertTo-Json; $null=Invoke-RestMethod 'http://127.0.0.1:11434/api/delete' -Method Delete -ContentType 'application/json' -Body $body -TimeoutSec 120; $after=Invoke-RestMethod 'http://127.0.0.1:11434/api/tags' -TimeoutSec 10; if (@($after.models | Where-Object { $_.name -eq 'qwen3:4b' }).Count -gt 0) { throw 'Model is still present.' }; Write-Host 'Grading model removed.'; exit 0 } catch { Write-Host $_.Exception.Message; exit 1 }"
if errorlevel 1 goto model_failed
goto uninstall

:no_model_tool
echo Ollama's command-line tool was not found. Model removal could not be checked.
set "CG_MODEL_FAILED=1"
goto uninstall

:model_failed
echo WARNING: The model could not be removed. Its downloaded files may remain.
set "CG_MODEL_FAILED=1"

:uninstall
echo Closing Ollama processes...
taskkill /IM "ollama app.exe" /F >nul 2>nul
taskkill /IM "ollama.exe" /T /F >nul 2>nul
echo Uninstalling Ollama...
if exist "%LOCALAPPDATA%\Programs\Ollama\unins000.exe" goto direct_uninstall
where winget >nul 2>nul
if errorlevel 1 goto manual_uninstall
winget uninstall --id Ollama.Ollama --exact --source winget
if errorlevel 1 goto manual_uninstall
goto finished

:direct_uninstall
start "" /wait "%LOCALAPPDATA%\Programs\Ollama\unins000.exe"
if errorlevel 1 goto manual_uninstall
if exist "%LOCALAPPDATA%\Programs\Ollama\ollama.exe" goto manual_uninstall
goto finished

:manual_uninstall
echo Automatic uninstall could not be confirmed.
echo In Windows Settings, choose Apps, select Ollama, then Uninstall.
start "" ms-settings:appsfeatures
echo No folders were forcibly deleted.
pause
exit /b 1

:finished
echo.
echo Ollama uninstallation finished.
if "%CG_MODEL_FAILED%"=="1" echo Model removal was NOT confirmed; downloaded model files may remain.
echo Other model files, if any, may remain in your user profile's .ollama folder.
echo Python, documents, and saved feedback were not removed.
pause
exit /b %CG_MODEL_FAILED%
