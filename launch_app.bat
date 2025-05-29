@echo off
REM Launch CNV Shiny App
cd %~dp0
start "" "C:\Program Files\R\R-4.3.1\bin\Rscript.exe" -e "shiny::runApp('app', launch.browser = TRUE)"
pause