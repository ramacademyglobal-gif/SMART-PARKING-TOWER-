@echo off
:: Run as Administrator to allow phones on Wi-Fi to reach the API.
netsh advfirewall firewall delete rule name="MultiParking API 8000" >nul 2>&1
netsh advfirewall firewall add rule name="MultiParking API 8000" dir=in action=allow protocol=TCP localport=8000 profile=any
echo Allowed inbound TCP 8000 (MultiParking API).
pause
