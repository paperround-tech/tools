@echo off
REM Portal Database SSH Tunnels - Batch File Version
REM QA: 5433, UAT: 5434, Staging: 5435, Production: 5436

setlocal EnableDelayedExpansion

if "%1"=="" (
    call :show_help
    exit /b 1
)

if /i "%1"=="start-qa" call :start_qa_tunnel
if /i "%1"=="start-uat" call :start_uat_tunnel  
if /i "%1"=="start-staging" call :start_staging_tunnel
if /i "%1"=="start-production" call :start_production_tunnel
if /i "%1"=="start-all" call :start_all_tunnels
if /i "%1"=="stop" call :stop_tunnel %2
if /i "%1"=="stop-all" call :stop_all_tunnels
if /i "%1"=="list" call :list_tunnels
if /i "%1"=="help" call :show_help
goto :eof

:start_qa_tunnel
echo Starting QA tunnel on port 5433...
start /B "" ssh -N -L 5433:portal-qa-cluster.cluster-ctvaf9l5ench.eu-west-2.rds.amazonaws.com:5432 -o ExitOnForwardFailure=yes ec2-user@35.179.170.3 -i %USERPROFILE%\.ssh\bastion_key_qa
echo QA tunnel started on port 5433
goto :eof

:start_uat_tunnel
echo Starting UAT tunnel on port 5434...
start /B "" ssh -N -L 5434:portal-uat-cluster.cluster-ctvaf9l5ench.eu-west-2.rds.amazonaws.com:5432 -o ExitOnForwardFailure=yes ec2-user@18.175.239.214 -i %USERPROFILE%\.ssh\bastion_key_uat
echo UAT tunnel started on port 5434
goto :eof

:start_staging_tunnel
echo Starting Staging tunnel on port 5435...
start /B "" ssh -N -L 5435:portal-staging-cluster.cluster-ctvaf9l5ench.eu-west-2.rds.amazonaws.com:5432 -o ExitOnForwardFailure=yes ec2-user@52.56.142.14 -i %USERPROFILE%\.ssh\bastion_key_staging
echo Staging tunnel started on port 5435
goto :eof

:start_production_tunnel
echo Starting Production tunnel on port 5436...
start /B "" ssh -N -L 5436:portal-production-cluster.cluster-ctvaf9l5ench.eu-west-2.rds.amazonaws.com:5432 -o ExitOnForwardFailure=yes ec2-user@18.170.58.57 -i %USERPROFILE%\.ssh\bastion_key_production
echo Production tunnel started on port 5436
goto :eof

:start_all_tunnels
echo Starting all portal tunnels...
call :start_qa_tunnel
call :start_uat_tunnel
call :start_staging_tunnel
call :start_production_tunnel
echo All tunnels started. Use 'portal-tunnels.bat list' to verify status.
goto :eof

:stop_tunnel
if "%2"=="" (
    echo Error: Please specify environment (qa/uat/staging/production)
    exit /b 1
)

set ENV=%2
if /i "%ENV%"=="qa" set PORT=5433
if /i "%ENV%"=="uat" set PORT=5434
if /i "%ENV%"=="staging" set PORT=5435
if /i "%ENV%"=="production" set PORT=5436

if "!PORT!"=="" (
    echo Error: Invalid environment. Use qa/uat/staging/production
    exit /b 1
)

echo Stopping %ENV% tunnel (port !PORT!)...
for /f "tokens=2" %%i in ('netstat -ano ^| findstr :!PORT! ^| findstr LISTENING') do (
    taskkill /PID %%i /F >nul 2>&1
    if !errorlevel! == 0 (
        echo %ENV% tunnel stopped (PID: %%i)
    )
)
goto :eof

:stop_all_tunnels
echo Stopping all portal tunnels...
call :stop_tunnel "" qa
call :stop_tunnel "" uat  
call :stop_tunnel "" staging
call :stop_tunnel "" production
goto :eof

:list_tunnels
echo Portal tunnel status:
call :check_tunnel_status qa 5433
call :check_tunnel_status uat 5434
call :check_tunnel_status staging 5435
call :check_tunnel_status production 5436
goto :eof

:check_tunnel_status
set ENV_NAME=%1
set PORT_NUM=%2
netstat -ano | findstr :%PORT_NUM% | findstr LISTENING >nul 2>&1
if !errorlevel! == 0 (
    for /f "tokens=2" %%i in ('netstat -ano ^| findstr :%PORT_NUM% ^| findstr LISTENING') do (
        echo %ENV_NAME%: running (PID: %%i)
    )
) else (
    echo %ENV_NAME%: not running
)
goto :eof

:show_help
echo.
echo Portal SSH Tunnel Commands:
echo.
echo Usage: portal-tunnels.bat [command] [environment]
echo.
echo Commands:
echo   start-qa           - Start QA tunnel on port 5433
echo   start-uat          - Start UAT tunnel on port 5434
echo   start-staging      - Start Staging tunnel on port 5435
echo   start-production   - Start Production tunnel on port 5436
echo   start-all          - Start all tunnels
echo   stop [env]         - Stop specific tunnel (qa/uat/staging/production)
echo   stop-all           - Stop all tunnels
echo   list               - Show tunnel status
echo   help               - Show this help
echo.
echo Examples:
echo   portal-tunnels.bat start-qa
echo   portal-tunnels.bat stop qa
echo   portal-tunnels.bat start-all
echo   portal-tunnels.bat list
echo.
goto :eof
