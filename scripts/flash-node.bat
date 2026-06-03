@echo off
:: =============================================================================
::  flash-node.bat — Firmware Flash Script (Windows)
::  Project : IoT Mesh Network on TP-Link TL-WA830RE v2
::  Authors : Bouazzi Yanis · Ranem Younes · Aoues Nassim · Yemi Mounir
:: =============================================================================
::
::  USAGE:
::    1. Place firmware-mesh.bin in the same folder as this script
::    2. Connect the router to your PC via Ethernet
::    3. Double-click this script or run it from cmd
::
::  PREREQUISITES:
::    - Router must be running OpenWrt (any version)
::    - If running stock TP-Link firmware, use factory.bin via the web UI instead
::    - OpenSSH must be installed on Windows (it is by default on Win10/11)
:: =============================================================================

setlocal
set ROUTER_IP=192.168.1.1
set FIRMWARE=firmware-mesh.bin
set REMOTE_PATH=/tmp/firmware-mesh.bin

echo.
echo =======================================================
echo   IEEE 802.11s Mesh -- Firmware Flash Script (Windows)
echo =======================================================
echo.

:: Check firmware file exists
if not exist "%FIRMWARE%" (
    echo [ERROR] %FIRMWARE% not found in current directory.
    echo         Place the firmware file next to this script.
    pause
    exit /b 1
)

echo [Step 1/4] Clearing old SSH host key for %ROUTER_IP%...
ssh-keygen -R %ROUTER_IP% >nul 2>&1
echo         Done.
echo.

echo [Step 2/4] Transferring firmware to router...
echo         Using legacy SCP protocol (-O flag) for Dropbear compatibility.
echo.
scp -O -o HostKeyAlgorithms=+ssh-rsa -o StrictHostKeyChecking=no ^
    %FIRMWARE% root@%ROUTER_IP%:%REMOTE_PATH%

if %ERRORLEVEL% neq 0 (
    echo.
    echo [ERROR] SCP transfer failed. Check:
    echo         - Router is powered on and connected via Ethernet
    echo         - Router IP is %ROUTER_IP%
    echo         - Router is running OpenWrt (not stock firmware)
    pause
    exit /b 1
)

echo.
echo [Step 3/4] Firmware transferred successfully.
echo.
echo [Step 4/4] Launching SSH session to flash the firmware...
echo.
echo -------------------------------------------------------
echo  Inside the SSH session, run:
echo.
echo    sysupgrade -n %REMOTE_PATH%
echo.
echo  The router will reboot automatically (2-3 minutes).
echo  Your SSH session will close -- that is normal.
echo -------------------------------------------------------
echo.
pause

ssh -o HostKeyAlgorithms=+ssh-rsa -o StrictHostKeyChecking=no root@%ROUTER_IP%

echo.
echo =======================================================
echo  Flash session ended.
echo  Wait 2-3 minutes for the router to fully reboot,
echo  then run node2-setup.sh via SSH to configure the mesh.
echo =======================================================
echo.
pause
