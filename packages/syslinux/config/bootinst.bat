@echo off
cls
set DISK=none
set BOOTFLAG=boot666s.tmp

echo This file is used to determine current drive letter. It should be deleted. >\%BOOTFLAG%
if not exist \%BOOTFLAG% goto readOnly

echo Wait please, searching for current drive letter.
for %%d in ( C D E F G H I J K L M N O P Q R S T U V W X Y Z ) do if exist %%d:\%BOOTFLAG% set DISK=%%d
cls
del \%BOOTFLAG%
if %DISK% == none goto DiskNotFound

echo =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
echo                          Welcome to OPENPCTV boot installer
echo =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
echo.
echo This installer will setup disk %DISK%: to boot only OPENPCTV.
echo.
echo Warning! Master Boot Record (MBR) of the device %DISK%: will be overwritten.
echo If %DISK%: is a partition on the same disk drive like your Windows installation,
echo then your Windows will not boot anymore. Be careful!
echo.
echo Press any key to continue, or kill this window [x] to abort...
pause > nul

cls
echo Setting up boot record for %DISK%:, wait please...

\boot\syslinux\syslinux.exe -maf -d \boot\syslinux %DISK%:

echo Disk %DISK%: should be bootable now. Installation finished.
goto pauseit

:readOnly
echo You're starting OPENPCTV installer from a read-only media, this will not work.
goto pauseit

:DiskNotFound
echo Error: can't find out current drive letter

:pauseit
echo.
echo Read the information above and then press any key to exit...
pause > nul

:end
