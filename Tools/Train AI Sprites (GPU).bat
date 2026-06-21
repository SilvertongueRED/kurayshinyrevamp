@echo off
setlocal
title KIF NeuralFusion - Train the neural model (GPU)
set "TOOLS=%~dp0"
set "PKG=%TOOLS%kif_neuralfusion"
set "VPY=%PKG%\.venv-train\Scripts\python.exe"
set "LOGDIR=%PKG%\logs"

rem --- a fresh consolidated log for this whole run (per-stage logs are kept too)
if not exist "%LOGDIR%" mkdir "%LOGDIR%"
del /q "%LOGDIR%\latest.log" 2>nul
echo Diagnostic log for this run will be written to:
echo    %LOGDIR%\latest.log
echo (plus a timestamped copy per stage in that same folder)
echo.

rem --- EDIT THESE if your folders differ -------------------------------------
set "CORPUS=C:\Users\rolan\OneDrive\Desktop\Backups\KIF Backups\PIFFull Sprite pack 1-125 (April 2026)\CustomBattlers"
set "BASE1=C:\Users\rolan\OneDrive\Desktop\Backups\KIF Backups\PIFFull Sprite pack 1-125 (April 2026)\Other"
set "BASE2=C:\Program Files (x86)\Steam\steamapps\common\Kuray's Infinite Fusion (KIF)\kurayshinyrevamp"
rem Full-dex base sprites (EVERY pokemon, beyond PIF). Added as single-species
rem training targets so out-of-PIF fusions render real features, not guesses.
set "BASES=C:\Users\rolan\Games\Kuray Infinite Fusion\Graphics\BaseSprites"
rem Hand-made TRIPLE sprites (head.body.third). Trains the model on real triples
rem so it can generate new ones for any three Pokemon you pick.
set "TRIPLES=C:\Users\rolan\OneDrive\Desktop\Backups\KIF Backups\PIFFull Sprite pack 1-125 (April 2026)\Other\Triples"
set "TRIPLES2=C:\Users\rolan\Games\Kuray Infinite Fusion\Graphics\Battlers\special"
set "DATASET=%PKG%\dataset"
set "OUT=%PKG%\models\lora"
set "LIMIT=0"
set "BASELIMIT=0"
rem ---------------------------------------------------------------------------

rem --- ALWAYS ensure/repair the GPU training environment FIRST. This is what
rem --- fixes a training env that ended up with a CPU-only torch (which would
rem --- otherwise silently "train" on the CPU). Drive setup with a system Python.
set "BPY="
where py >nul 2>nul && set "BPY=py -3"
if not defined BPY ( where python >nul 2>nul && set "BPY=python" )
if not defined BPY ( if exist "%VPY%" set "BPY=%VPY%" )
if not defined BPY ( echo No Python found; run "Setup AI Sprites.bat" first. & pause & exit /b 1 )
echo Ensuring/repairing the GPU training environment (installs CUDA torch if needed)...
%BPY% "%PKG%\bootstrap.py" train
if errorlevel 1 ( echo. & echo Setup/repair of the training environment FAILED. & echo See the log: %LOGDIR%\latest.log & pause & exit /b 1 )
if not exist "%VPY%" ( echo Could not create the training environment. See %LOGDIR%\latest.log & pause & exit /b 1 )

echo.
echo Building dataset (compositor -^> human-custom pairs + base sprites + triples)...
"%VPY%" "%PKG%\train\prepare_dataset.py" --corpus "%CORPUS%" --base-roots "%BASE1%" "%BASE2%" "%BASES%" --base-dir "%BASES%" --base-limit %BASELIMIT% --triple-dir "%TRIPLES%" "%TRIPLES2%" --out "%DATASET%" --size 512 --limit %LIMIT% --val-split 0.02
if errorlevel 1 ( echo. & echo Dataset step FAILED - check the CORPUS/BASES/TRIPLES paths above and the log: & echo    %LOGDIR%\latest.log & pause & exit /b 1 )

echo.
echo Training LoRA (a few hours; checkpoints save every 1000 steps).
echo You can stop anytime with Ctrl+C - re-running this BAT auto-resumes
echo from the last checkpoint. To start over, delete the models\lora folder.
"%VPY%" "%PKG%\train\train_lora.py" --dataset "%DATASET%" --output "%OUT%" --resolution 512 --rank 32 --lr 1e-4 --batch 2 --grad-accum 4 --max-steps 120000 --mixed-precision fp16 --checkpoint-steps 2000 --resume auto
if errorlevel 1 ( echo. & echo Training FAILED. The full traceback + hints are in: & echo    %LOGDIR%\latest.log & pause & exit /b 1 )

echo.
echo ============================================================
echo   Done. Weights saved to:
echo   %OUT%
echo   Restart the game - the sidecar auto-upgrades to NEURAL.
echo   (Run log: %LOGDIR%\latest.log)
echo ============================================================
pause
