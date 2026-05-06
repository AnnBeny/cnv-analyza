@echo off
REM Launch CNV Shiny App
cd /D "D:\cnv_analyza\app"
"C:\Program Files\R\R-4.3.0\bin\Rscript.exe" -e "shiny::runApp('.', launch.browser = TRUE)"
pause