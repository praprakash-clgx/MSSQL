@echo off
set cpath=R:\DBA\RES\reports\Backupreport
set spath=R:\DBA\RES\reports\Backupreport

move R:\DBA\RES\reports\Backupreport\RES-DiffBackup-Report* R:\DBA\RES\reports\Backupreport\Archive_Reports

echo. > %cpath%\success.txt
echo. > %cpath%\error.txt
echo. > %cpath%\cnt.txt

for /f "tokens=1,2,3,4,5 delims=," %%i in (%spath%\servers_diff.txt)   do call "%cpath%\check_diff.bat" %%i


echo. > %cpath%\RES-DiffBackup-Report.html
echo Diff BACKUP REPORT GENERATED ON %date% AT %time% >> %cpath%\RES-DiffBackup-Report.html
echo ^<br^>^<br^>^<br^> >> %cpath%\RES-DiffBackup-Report.html     
FIND "</font>" %cpath%\success.txt>nul
if errorlevel 1 GOTO ErrorConsolidate
echo ^<html^> >> %cpath%\RES-DiffBackup-Report.html
echo ^<TITLE^>CoreLogic Diff Backup Status Report^</TITLE^> >> %cpath%\RES-DiffBackup-Report.html
echo ^<body^> >> %cpath%\RES-DiffBackup-Report.html

echo ^<table border=1 cellspacing=0 cellpadding=1 bgcolor=#ccccc width=100%%^> >> %cpath%\RES-DiffBackup-Report.html
echo ^<tr rowspan=2 bgcolor=gray^>^<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Server Name^</b^>^</font^>^</td^>^
<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Env^</b^>^</font^>^</td^>^
<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Database Name^</b^>^</font^>^</td^>^
<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Size in MB^</b^>^</font^>^</td^>^
<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Durations^</b^>^</font^>^</td^>^
<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Type^</b^>^</font^>^</td^>^</font^>^<tr^> >> %cpath%\RES-DiffBackup-Report.html

echo ^<td align=center bgcolor=gray^>^<font face=verdana size=1 color=white^>^<b^>Status^</b^>^</font^>^</td^>^<td align=center bgcolor=gray^>^<font face=verdana size=1 color=white^>^<b^>Last Run Date^</b^>^</font^>^</td^>^</tr^>^</tr^>^</font^>^</td^> >> %cpath%\RES-DiffBackup-Report.html
type %cpath%\success.txt >> %cpath%\RES-DiffBackup-Report.html
echo ^</tr^> >> %cpath%\RES-DiffBackup-Report.html
echo ^</table^> >> %cpath%\RES-DiffBackup-Report.html 

echo ^<br^>^<br^>^<br^> >> %cpath%\RES-DiffBackup-Report.html     

GOTO eof

:eof

IF EXIST "%fn%" (del "%fn%"/q)
rename %cpath%\CoreLogic.html "%fn%"
IF EXIST %cpath%\output.txt (del %cpath%\output.txt)
IF EXIST %cpath%\pCoreLogic.txt (del %cpath%\pCoreLogic.txt)
IF EXIST %cpath%\cnt.txt (del %cpath%\cnt.txt)
IF EXIST %cpath%\success.txt (del %cpath%\success.txt)
IF EXIST %cpath%\error.txt (del %cpath%\error.txt)
IF EXIST %cpath%\hdr.txt (del %cpath%\hdr.txt)
IF EXIST %cpath%\op.txt (del %cpath%\op.txt)

echo ^<P^> ^<P^> ^<P^> >> %cpath%\RES-DiffBackup-Report.html


rename R:\DBA\RES\reports\Backupreport\RES-DiffBackup-Report.html RES-DiffBackup-Report_%date:~4,2%%date:~7,2%%date:~10,4%.html









for /f "tokens=1,2,3,4,5 delims=," %%i in (%spath%\servers_diff.txt)   do call "%cpath%\check_diffnotcomp.bat" %%i



echo. > %cpath%\RES-DiffBackup-Report_NotCompleted.html
echo Diff BACKUP REPORT GENERATED ON %date% AT %time% >> %cpath%\RES-DiffBackup-Report_NotCompleted.html
echo ^<br^>^<br^>^<br^> >> %cpath%\RES-DiffBackup-Report_NotCompleted.html     
FIND "</font>" %cpath%\success.txt>nul
if errorlevel 1 GOTO ErrorConsolidate
echo ^<html^> >> %cpath%\RES-DiffBackup-Report_NotCompleted.html
echo ^<TITLE^>CoreLogic Diff Backup Status Report^</TITLE^> >> %cpath%\RES-DiffBackup-Report_NotCompleted.html
echo ^<body^> >> %cpath%\RES-DiffBackup-Report_NotCompleted.html

echo ^<table border=1 cellspacing=0 cellpadding=1 bgcolor=#ccccc width=100%%^> >> %cpath%\RES-DiffBackup-Report_NotCompleted.html
echo ^<tr rowspan=2 bgcolor=gray^>^<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Server Name^</b^>^</font^>^</td^>^
<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Env^</b^>^</font^>^</td^>^
<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Database Name^</b^>^</font^>^</td^>^
<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Size in MB^</b^>^</font^>^</td^>^</font^>^<tr^> >> %cpath%\RES-DiffBackup-Report_NotCompleted.html

echo ^<td align=center bgcolor=gray^>^<font face=verdana size=1 color=white^>^<b^>Status^</b^>^</font^>^</td^>^<td align=center bgcolor=gray^>^<font face=verdana size=1 color=white^>^<b^>Last Run Date^</b^>^</font^>^</td^>^</tr^>^</tr^>^</font^>^</td^> >> %cpath%\RES-DiffBackup-Report_NotCompleted.html
type %cpath%\success.txt >> %cpath%\RES-DiffBackup-Report_NotCompleted.html
echo ^</tr^> >> %cpath%\RES-DiffBackup-Report_NotCompleted.html
echo ^</table^> >> %cpath%\RES-DiffBackup-Report_NotCompleted.html 

echo ^<br^>^<br^>^<br^> >> %cpath%\RES-DiffBackup-Report_NotCompleted.html     

GOTO eof1

:eof1

IF EXIST "%fn%" (del "%fn%"/q)
rename %cpath%\CoreLogic.html "%fn%"
IF EXIST %cpath%\output.txt (del %cpath%\output.txt)
IF EXIST %cpath%\pCoreLogic.txt (del %cpath%\pCoreLogic.txt)
IF EXIST %cpath%\cnt.txt (del %cpath%\cnt.txt)
IF EXIST %cpath%\success.txt (del %cpath%\success.txt)
IF EXIST %cpath%\error.txt (del %cpath%\error.txt)
IF EXIST %cpath%\hdr.txt (del %cpath%\hdr.txt)
IF EXIST %cpath%\op.txt (del %cpath%\op.txt)

echo ^<P^> ^<P^> ^<P^> >> %cpath%\RES-DiffBackup-Report_NotCompleted.html

rename R:\DBA\RES\reports\Backupreport\RES-DiffBackup-Report_NotCompleted.html RES-DiffBackup-Report_NotCompleted_%date:~4,2%%date:~7,2%%date:~10,4%.html


