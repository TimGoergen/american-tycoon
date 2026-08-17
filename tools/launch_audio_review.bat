@echo off
echo Starting American Tycoon Audio Refinement Studio...
start "" http://localhost:8765
python "%~dp0audio_review_server.py"
pause
