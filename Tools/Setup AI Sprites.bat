@echo off
setlocal enabledelayedexpansion
title KIF NeuralFusion - AI Sprite Setup
echo ============================================================
echo   KIF NeuralFusion - AI fusion sprite setup
echo   Sets up an ISOLATED environment. Your other Python
echo   packages (torch, etc.) are NOT touched.
echo ============================================================
echo.

set "TOOLS=%~dp0"
set "PKG=%TOOLS%kif_neuralfusion"
set "LOGDIR=%PKG%\logs"
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
echo Setup progress is logged to: %LOGDIR%\latest.log
echo.

rem --- find Python (py launcher preferred, then python) ---
set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY ( where python >nul 2>nul && set "PY=python" )

if not defined PY (
  echo No Python found. Trying to install Python 3.12 via winget...
  winget install -e --id Python.Python.3.12 --accept-source-agreements --accept-package-agreements
  set "PATH=%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts;%PATH%"
  where py >nul 2>nul && set "PY=py -3"
  if not defined PY ( where python >nul 2>nul && set "PY=python" )
)
if not defined PY (
  echo.
  echo Could not find or install Python automatically.
  echo Install Python 3.10+ from https://www.python.org/downloads/  ^(tick "Add to PATH"^) then re-run this.
  echo.
  pause & exit /b 1
)
echo Using Python: %PY%
echo.

echo [1/2] Setting up the always-on sprite generator (isolated)...
%PY% "%PKG%\bootstrap.py" runtime
if errorlevel 1 ( echo. & echo Runtime setup failed. See %LOGDIR%\latest.log & pause & exit /b 1 )
echo.

where nvidia-smi >nul 2>nul
if "%errorlevel%"=="0" (
  echo An NVIDIA GPU was detected - you can train the high-quality neural model.
  set /p TRAIN="[2/2] Set up the GPU training environment now (separate isolated env, will NOT touch your global torch)? [y/N] "
  if /I "!TRAIN!"=="y" (
    %PY% "%PKG%\bootstrap.py" train
    if errorlevel 1 ( echo. & echo Training-env setup FAILED. See %LOGDIR%\latest.log & pause & exit /b 1 )
  ) else (
    echo Skipped. You can run it later with:  Train AI Sprites ^(GPU^).bat
  )
) else (
  echo No NVIDIA GPU detected - the always-on compositor will be used. No training needed.
)

echo.
echo ============================================================
echo   Done. Launch the game and press the Generate button on a
echo   fusion that has no custom sprite.
echo   (Setup log: %LOGDIR%\latest.log)
echo ============================================================
pause
