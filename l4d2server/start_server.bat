@echo off
cd /d "%~dp0"

echo Checking MariaDB (required for XPMod DB)...
tasklist /FI "IMAGENAME eq mysqld.exe" 2>nul | find /I "mysqld.exe" >nul
if errorlevel 1 (
    echo   MariaDB not running - starting it...
    start "MariaDB" /MIN "C:\Program Files\MariaDB 12.3\bin\mysqld.exe" --defaults-file="C:\Program Files\MariaDB 12.3\data\my.ini"
) else (
    echo   MariaDB already running.
)

echo   Waiting for MariaDB to accept connections on port 3306...
powershell -NoProfile -Command "$ok=$false; for ($i=0; $i -lt 20; $i++) { try { (New-Object System.Net.Sockets.TcpClient).Connect('127.0.0.1',3306); $ok=$true; break } catch { Start-Sleep -Seconds 1 } }; if ($ok) { Write-Host '  MariaDB is up, connections accepted.' } else { Write-Host '  WARNING: MariaDB did not respond within 20 seconds - starting server anyway.' }"

echo Starting L4D2 Dedicated Server...
srcds.exe -game left4dead2 -console -port 27017 +sv_setsteamaccount "B97F5EF9F16327FBA84897B7AD41B91F" +map c1m1_hotel +exec server.cfg
pause
