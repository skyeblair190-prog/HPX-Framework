@echo off
cd /d "%~dp0"
set "DB="
where mysql >nul 2>nul && set "DB=mysql"
if not defined DB where mariadb >nul 2>nul && set "DB=mariadb"
if not defined DB for /d %%D in ("%ProgramFiles%\MariaDB*" "%ProgramFiles%\MySQL\MySQL Server*") do if exist "%%~D\bin\mysql.exe" set "DB=%%~D\bin\mysql.exe"
if not defined DB (echo mysql client not found. Run setup.sql in HeidiSQL instead. & pause & exit /b 1)
"%DB%" -u root -p < setup.sql
if errorlevel 1 (echo Failed. & pause & exit /b 1)
echo Database "hpx" and user "hpx" are ready. Tables are created automatically when the server starts.
pause
