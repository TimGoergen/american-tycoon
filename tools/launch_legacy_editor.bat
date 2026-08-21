@echo off
echo Starting American Tycoon Legacy Upgrades Studio...
start "" http://localhost:8766
python "%~dp0legacy_upgrade_editor_server.py"
pause
