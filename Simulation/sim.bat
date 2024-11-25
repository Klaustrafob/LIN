@echo off
set path=%path%;C:\intelFPGA_lite\23.1std\questa_fse\win64

rem if /I .%QUARTUS_20_1_0_DIR%. == .. goto error

rem set QUARTUS_ROOTDIR=%QUARTUS_20_1_0_DIR%
rem set path=%QUARTUS_ROOTDIR%\bin64;%path%

rem set QSYS_ROOTDIR=%QUARTUS_ROOTDIR%/sopc_builder/bin

tasklist|find /i "vish.exe"
if %errorlevel% == 0 taskkill /f /im vish.exe

set DOPATH=%~dp0

cd /
%~d0
cd "%~p0"

rem %QSYS_ROOTDIR%/qsys-generate.exe  --simulation=VERILOG xd_scanner/OnChipFlash.qsys
rem if not %ERRORLEVEL%==0 goto error

rem echo "ip-generate complete"

questasim -do "%DOPATH%lin.do"
if not %ERRORLEVEL%==0 goto error
goto end

:error
	echo    **********
	echo      ERROR! errorlevel = %ERRORLEVEL% 
	echo    **********
	pause

:end
	