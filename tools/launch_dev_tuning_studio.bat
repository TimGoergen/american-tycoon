@echo off
echo Starting American Tycoon Developer Tuning Studio...
start "" http://localhost:8767
python "%~dp0dev_tuning_studio_server.py"
pause
