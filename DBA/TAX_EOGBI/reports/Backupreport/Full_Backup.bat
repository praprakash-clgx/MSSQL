@echo off
set cpath=R:\DBA\TAX_EOGBI\reports\Backupreport
set spath=R:\DBA\TAX_EOGBI\reports\Backupreport

move R:\DBA\TAX_EOGBI\reports\Backupreport\TAX_EOGBI-FullBackup-Report* R:\DBA\TAX_EOGBI\reports\Backupreport\Archive_Reports

echo. > %cpath%\success.txt
echo. > %cpath%\error.txt
echo. > %cpath%\cnt.txt

for /f "tokens=1,2,3,4,5 delims=," %%i in (%spath%\servers.txt)   do call "%cpath%\check.bat" %%i


echo. > %cpath%\TAX_EOGBI-FullBackup-Report.html
echo FULL BACKUP REPORT GENERATED ON %date% AT %time% >> %cpath%\TAX_EOGBI-FullBackup-Report.html
echo ^<br^>^<br^>^<br^> >> %cpath%\TAX_EOGBI-FullBackup-Report.html     
FIND "</font>" %cpath%\success.txt>nul
if errorlevel 1 GOTO ErrorConsolidate
echo ^<html^> >> %cpath%\TAX_EOGBI-FullBackup-Report.html
echo ^<TITLE^>CL Prod Backup Status Report^</TITLE^> >> %cpath%\TAX_EOGBI-FullBackup-Report.html
echo ^<body^> >> %cpath%\TAX_EOGBI-FullBackup-Report.html

echo ^<table border=1 cellspacing=0 cellpadding=1 bgcolor=#ccccc width=100%%^> >> %cpath%\TAX_EOGBI-FullBackup-Report.html
echo ^<tr rowspan=2 bgcolor=gray^>^<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Server Name^</b^>^</font^>^</td^>^
<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Env^</b^>^</font^>^</td^>^
<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Database Name^</b^>^</font^>^</td^>^
<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Size in MB^</b^>^</font^>^</td^>^</font^>^<tr^> >> %cpath%\TAX_EOGBI-FullBackup-Report.html

echo ^<td align=center bgcolor=gray^>^<font face=verdana size=1 color=white^>^<b^>Status^</b^>^</font^>^</td^>^<td align=center bgcolor=gray^>^<font face=verdana size=1 color=white^>^<b^>Last Run Date^</b^>^</font^>^</td^>^</tr^>^</tr^>^</font^>^</td^> >> %cpath%\TAX_EOGBI-FullBackup-Report.html
type %cpath%\success.txt >> %cpath%\TAX_EOGBI-FullBackup-Report.html
echo ^</tr^> >> %cpath%\TAX_EOGBI-FullBackup-Report.html
echo ^</table^> >> %cpath%\TAX_EOGBI-FullBackup-Report.html 

echo ^<br^>^<br^>^<br^> >> %cpath%\TAX_EOGBI-FullBackup-Report.html     

GOTO eof

:eof

IF EXIST "%fn%" (del "%fn%"/q)
rename %cpath%\CL.html "%fn%"
IF EXIST %cpath%\output.txt (del %cpath%\output.txt)
IF EXIST %cpath%\pCL.txt (del %cpath%\pCL.txt)
IF EXIST %cpath%\cnt.txt (del %cpath%\cnt.txt)
IF EXIST %cpath%\success.txt (del %cpath%\success.txt)
IF EXIST %cpath%\error.txt (del %cpath%\error.txt)
IF EXIST %cpath%\hdr.txt (del %cpath%\hdr.txt)
IF EXIST %cpath%\op.txt (del %cpath%\op.txt)

echo ^<P^> ^<P^> ^<P^> >> %cpath%\TAX_EOGBI-FullBackup-Report.html


rename R:\DBA\TAX_EOGBI\reports\Backupreport\TAX_EOGBI-FullBackup-Report.html TAX_EOGBI-FullBackup-Report_%date:~4,2%%date:~7,2%%date:~10,4%.html









for /f "tokens=1,2,3,4,5 delims=," %%i in (%spath%\servers.txt)   do call "%cpath%\check_notcomp.bat" %%i
: for /f "tokens=1,2,3,4,5 delims=," %%i in (%spath%\Servers_Hqintl1.txt)   do call "%cpath%\check_hqintl1_notcomp.bat" %%i


echo. > %cpath%\TAX_EOGBI-FullBackup-Report_NotCompleted.html
echo FULL BACKUP REPORT GENERATED ON %date% AT %time% >> %cpath%\TAX_EOGBI-FullBackup-Report_NotCompleted.html
echo ^<br^>^<br^>^<br^> >> %cpath%\TAX_EOGBI-FullBackup-Report_NotCompleted.html     
FIND "</font>" %cpath%\success.txt>nul
if errorlevel 1 GOTO ErrorConsolidate
echo ^<html^> >> %cpath%\TAX_EOGBI-FullBackup-Report_NotCompleted.html
echo ^<TITLE^>CL Prod Backup Status Report^</TITLE^> >> %cpath%\TAX_EOGBI-FullBackup-Report_NotCompleted.html
echo ^<body^> >> %cpath%\TAX_EOGBI-FullBackup-Report_NotCompleted.html

echo ^<table border=1 cellspacing=0 cellpadding=1 bgcolor=#ccccc width=100%%^> >> %cpath%\TAX_EOGBI-FullBackup-Report_NotCompleted.html
echo ^<tr rowspan=2 bgcolor=gray^>^<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Server Name^</b^>^</font^>^</td^>^
<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Env^</b^>^</font^>^</td^>^
<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Database Name^</b^>^</font^>^</td^>^
<td rowspan=2 align=center^>^<font face=verdana size=1 color=white^>^<b^>Size in MB^</b^>^</font^>^</td^>^</font^>^<tr^> >> %cpath%\TAX_EOGBI-FullBackup-Report_NotCompleted.html

echo ^<td align=center bgcolor=gray^>^<font face=verdana size=1 color=white^>^<b^>Status^</b^>^</font^>^</td^>^<td align=center bgcolor=gray^>^<font face=verdana size=1 color=white^>^<b^>Last Run Date^</b^>^</font^>^</td^>^</tr^>^</tr^>^</font^>^</td^> >> %cpath%\TAX_EOGBI-FullBackup-Report_NotCompleted.html
type %cpath%\success.txt >> %cpath%\TAX_EOGBI-FullBackup-Report_NotCompleted.html
echo ^</tr^> >> %cpath%\TAX_EOGBI-FullBackup-Report_NotCompleted.html
echo ^</table^> >> %cpath%\TAX_EOGBI-FullBackup-Report_NotCompleted.html 

echo ^<br^>^<br^>^<br^> >> %cpath%\TAX_EOGBI-FullBackup-Report_NotCompleted.html     

GOTO eof1

:eof1

IF EXIST "%fn%" (del "%fn%"/q)
rename %cpath%\CL.html "%fn%"
IF EXIST %cpath%\output.txt (del %cpath%\output.txt)
IF EXIST %cpath%\pCL.txt (del %cpath%\pCL.txt)
IF EXIST %cpath%\cnt.txt (del %cpath%\cnt.txt)
IF EXIST %cpath%\success.txt (del %cpath%\success.txt)
IF EXIST %cpath%\error.txt (del %cpath%\error.txt)
IF EXIST %cpath%\hdr.txt (del %cpath%\hdr.txt)
IF EXIST %cpath%\op.txt (del %cpath%\op.txt)

echo ^<P^> ^<P^> ^<P^> >> %cpath%\TAX_EOGBI-FullBackup-Report_NotCompleted.html

rename R:\DBA\TAX_EOGBI\reports\Backupreport\TAX_EOGBI-FullBackup-Report_NotCompleted.html TAX_EOGBI-FullBackup-Report_NotCompleted_%date:~4,2%%date:~7,2%%date:~10,4%.html


