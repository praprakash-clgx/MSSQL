@echo on
SET wpath=R:\DBA\RES\reports\Backupreport

echo %1 %2 %3 %4 %5
sqlcmd -S%4,%5 -t0 -E -i%wpath%\status_notcompdiff.txt -o%wpath%\output.txt
echo T >> cnt.txt
type %wpath%\output.txt >> %wpath%\success.txt
if errorlevel 1 goto end
For /F "tokens=1,2 delims=" %%A in (%wpath%\output.txt) Do (
Echo %%A%%B>> %wpath%\op.txt
If "%%A"=="size=2>" (
Echo %2>> %wpath%\op.txt))
Goto Final


:end



:Final


