@echo off
rem CanMV's own CLI connects the board and runs this file on startup.
start "" "E:\yolo\bin\canmvide.exe" -auto_connect -auto_run "%~dp0pinch_preview.py"
