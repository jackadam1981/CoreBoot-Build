@echo off
:: 以管理员身份运行关机诊断脚本；报告生成在脚本所在目录
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0check-windows-shutdown.ps1\"' -Verb RunAs -Wait"
echo.
echo 报告已生成在: %~dp0check-windows-shutdown-report.txt
pause
