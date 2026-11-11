#$date = ( get-date ).ToString('yyyy/MM/dd hh:mm:ss')
$date = Get-Date -Format("yyyy/MM/dd HH:mm:ss")

<#
# Email params
#$recipients = "bveeraraghavareddy@corelogic.com,kusudhir@corelogic.com"
$recipients = "sgnanthikam@corelogic.com"
[string[]]$To = $recipients.Split(',')
#>

<#
#Rename existing file 
$stamp = $(Get-Date -Format "yyyy-MM-dd-HHmmss")
Get-ChildItem *.html | ForEach-Object { Rename-Item -Path $_.FullName -NewName "$($_.DirectoryName)\$($_.BaseName)_$stamp$($_.Extension)" }
#>

#Move older file to Archive folder
Move-Item -Path "R:\DBA\NTT\reports\Backup\*.html" -Destination "R:\DBA\NTT\reports\Backup\Archive"

#Setup HTML
$header = @"
<style>
body {
    background-color: #FFFFFF; font-family: Tahoma; font-size: 12pt;
}
td,
th {
    border: 0px solid black;border-collapse: collapse;
}
th {
    color: black;background-color: lightblue;
}
table,
tr,
td,
th {
    padding: 2px;margin: 0px;
}
tr:nth-child(even) {
    background-color: lightgray
}
table {
    width: 95%;    margin-left: 10px;    margin-bottom: 20px;    table-layout: auto;
}
.meta {
    width: 25%;    font-size: 8pt;    margin-left: 0px;    table-layout: auto;
}
.top {
    width: 50%;    margin-left: 0px;    table-layout: auto;
}
tr.meta {
    background-color: #FFFFFF;
}
.right {
    text-align: right;    width: 20%;
}
caption {
    background-color: #FFFF66;    text-align: left;    font-weight: bold;    font-size: 14pt;
}
td[tip]:hover {
    color: #ff2283;    position: relative;
}
td[tip]:hover:after {
    content: attr(tip);    left: 0;    top: 100%;    margin-left: 80px;    margin-top: 10px;    width: 400px;
    padding: 3px 8px;    position: absolute;    color: #85003a;    font-family: 'Courier New', Courier, monospace;
    font-size: 10pt;    background-color: gainsboro;    white-space: pre-wrap;
}
</style>
<title>BACKUP HEALTH CHECK REPORT</title>
"@

$Pre = "<font face='tahoma' color='blue' size='5'>BACKUP HEALTH CHECK REPORT executed at - $date</font><br></br>"


#Alternate Row Color
Function Set-AlternatingRows {
	
    [CmdletBinding()]
   	Param(
       	[Parameter(Mandatory,ValueFromPipeline)]
        [string]$Line,
       
   	    [Parameter(Mandatory)]
       	[string]$CSSEvenClass,
       
        [Parameter(Mandatory)]
   	    [string]$CSSOddClass
   	)
	Begin {
		$ClassName = $CSSEvenClass
	}
	Process {
		If ($Line.Contains("<tr><td>"))
		{	$Line = $Line.Replace("<tr>","<tr class=""$ClassName"">")
			If ($ClassName -eq $CSSEvenClass)
			{	$ClassName = $CSSOddClass
			}
			Else
			{	$ClassName = $CSSEvenClass
			}
		}
		Return $Line
	}
}

#Set Cell color
Function Set-CellColor
{   
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory,Position=0)]
        [string]$Property,
        [Parameter(Mandatory,Position=1)]
        [string]$Color,
        [Parameter(Mandatory,ValueFromPipeline)]
        [Object[]]$InputObject,
        [Parameter(Mandatory)]
        [string]$Filter,
        [switch]$Row
    )
    
    Begin {
        Write-Verbose "$(Get-Date): Function Set-CellColor begins"
        If ($Filter)
        {   If ($Filter.ToUpper().IndexOf($Property.ToUpper()) -ge 0)
            {   $Filter = $Filter.ToUpper().Replace($Property.ToUpper(),"`$Value")
                Try {
                    [scriptblock]$Filter = [scriptblock]::Create($Filter)
                }
                Catch {
                    Write-Warning "$(Get-Date): ""$Filter"" caused an error, stopping script!"
                    Write-Warning $Error[0]
                    Exit
                }
            }
            Else
            {   Write-Warning "Could not locate $Property in the Filter, which is required.  Filter: $Filter"
                Exit
            }
        }
    }
    
    Process {
        ForEach ($Line in $InputObject)
        {   If ($Line.IndexOf("<tr><th") -ge 0)
            {   Write-Verbose "$(Get-Date): Processing headers..."
                $Search = $Line | Select-String -Pattern '<th ?[a-z\-:;"=]*>(.*?)<\/th>' -AllMatches
                $Index = 0
                ForEach ($Match in $Search.Matches)
                {   If ($Match.Groups[1].Value -eq $Property)
                    {   Break
                    }
                    $Index ++
                }
                If ($Index -eq $Search.Matches.Count)
                {   Write-Warning "$(Get-Date): Unable to locate property: $Property in table header"
                    Exit
                }
                Write-Verbose "$(Get-Date): $Property column found at index: $Index"
            }
            If ($Line -match "<tr( style=""background-color:.+?"")?><td")
            {   $Search = $Line | Select-String -Pattern '<td ?[a-z\-:;"=]*>(.*?)<\/td>' -AllMatches
                $Value = $Search.Matches[$Index].Groups[1].Value -as [double]
                If (-not $Value)
                {   $Value = $Search.Matches[$Index].Groups[1].Value
                }
                If (Invoke-Command $Filter)
                {   If ($Row)
                    {   Write-Verbose "$(Get-Date): Criteria met!  Changing row to $Color..."
                        If ($Line -match "<tr style=""background-color:(.+?)"">")
                        {   $Line = $Line -replace "<tr style=""background-color:$($Matches[1])","<tr style=""background-color:$Color"
                        }
                        Else
                        {   $Line = $Line.Replace("<tr>","<tr style=""background-color:$Color"">")
                        }
                    }
                    Else
                    {   Write-Verbose "$(Get-Date): Criteria met!  Changing cell to $Color..."
                        $Line = $Line.Replace($Search.Matches[$Index].Value,"<td style=""background-color:$Color"">$Value</td>")
                    }
                }
            }
            Write-Output $Line
        }
    }
    
    End {
        Write-Verbose "$(Get-Date): Function Set-CellColor completed"
    }
}

#import SQL Server module
Import-Module SQLServer -DisableNameChecking -Global

function Get-SQLData{

    #List of servers from text file
    $serverlist = Get-Content -Path R:\DBA\NTT\reports\Backup\ServerList.txt


 #Loop through each server and create SMO object)
foreach ($serverName in $serverlist){

        #create smo object
        $SQLServer = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $ServerName
<#
$Query = "            
SELECT ag.name AS AGName, listener_name=(select dns_name from sys.availability_group_listeners),
Primary_Replica=(SELECT distinct r.replica_server_name FROM sys.availability_replicas r
     INNER JOIN sys.dm_hadr_database_replica_states rs ON r.replica_id = rs.replica_id
	 where rs.is_primary_replica=1),
Secondary_Replica=(SELECT distinct r.replica_server_name FROM sys.availability_replicas r
     INNER JOIN sys.dm_hadr_database_replica_states rs ON r.replica_id = rs.replica_id
	 where rs.is_primary_replica=0 and r.replica_server_name like '%NX%'),
DR_server=(SELECT distinct r.replica_server_name FROM sys.availability_replicas r
     INNER JOIN sys.dm_hadr_database_replica_states rs ON r.replica_id = rs.replica_id
	 where rs.is_primary_replica=0 and r.replica_server_name like '%CV%'),
ar.availability_mode_desc, adc.[database_name],
drs.is_local, drs.is_primary_replica, drs.synchronization_state_desc, drs.is_commit_participant,
drs.synchronization_health_desc, drs.recovery_lsn, drs.truncation_lsn, drs.last_received_lsn,  
drs.last_hardened_lsn, drs.last_redone_lsn, drs.log_send_queue_size, drs.redo_queue_size, 
drs.end_of_log_lsn, drs.last_commit_lsn, drs.last_commit_time
FROM sys.dm_hadr_database_replica_states AS drs WITH (NOLOCK)
INNER JOIN sys.availability_databases_cluster AS adc WITH (NOLOCK)
ON drs.group_id = adc.group_id
AND drs.group_database_id = adc.group_database_id
INNER JOIN sys.availability_groups AS ag WITH (NOLOCK)
ON ag.group_id = drs.group_id
INNER JOIN sys.availability_replicas AS ar WITH (NOLOCK)
ON drs.group_id = ar.group_id
AND drs.replica_id = ar.replica_id
where drs.is_primary_replica=1
ORDER BY ag.name, ar.replica_server_name, adc.[database_name] 
"#>

$Query = "            
;WITH    backupsetSummary
          AS ( SELECT   bs.database_name ,
                        bs.type bstype ,
                        MAX(backup_finish_date) MAXbackup_finish_date
               FROM     msdb.dbo.backupset bs
               GROUP BY bs.database_name ,
                        bs.type
             ),
        MainBigSet
          AS ( SELECT   
						@@SERVERNAME servername,
						db.name ,
                        db.state_desc ,
                        db.recovery_model_desc ,
                        bs.type ,
                        convert(decimal(10,2),bs.backup_size/1024.00/1024) backup_sizeinMB,
						bs.backup_start_date,
                        bs.backup_finish_date,
						physical_device_name,
						DATEDIFF(MINUTE, bs.backup_start_date, bs.backup_finish_date) AS DurationMins
			            FROM     master.sys.databases db
                        LEFT OUTER JOIN backupsetSummary bss ON bss.database_name = db.name
                        LEFT OUTER JOIN msdb.dbo.backupset bs ON bs.database_name = db.name
                                                              AND bss.bstype = bs.type
                                                              AND bss.MAXbackup_finish_date = bs.backup_finish_date
						JOIN msdb.dbo.backupmediafamily m ON bs.media_set_id = m.media_set_id
						where  db.name <> 'tempdb' and is_copy_only <> 1
             )
 
			-- select * from MainBigSet
 
SELECT
	servername,
	name,
	state_desc,
	recovery_model_desc,getdate() CurrentDateTime,
	Last_Backup      = MAX(a.backup_finish_date), 
	[Days_Since_Last_FUll_Backup] = DATEDIFF(d,(MAX(CASE WHEN a.type='D' THEN a.backup_finish_date ELSE NULL END)),GETDATE()),
	[Days_Since_Last_Diff_Backup] = DATEDIFF(d,(MAX(CASE WHEN a.type='I' THEN a.backup_finish_date ELSE NULL END)),GETDATE()),
	[Days_Since_Last_Log_Backup] = DATEDIFF(d,(MAX(CASE WHEN a.type='L' THEN a.backup_finish_date ELSE NULL END)),GETDATE()), 
	Last_Full_Backup_start_Date = MAX(CASE WHEN a.type='D' 
										THEN a.backup_start_date ELSE NULL END),
	Last_Full_Backup_end_date = MAX(CASE WHEN a.type='D' 
										THEN a.backup_finish_date ELSE NULL END),
	Last_Full_BackupSize_MB=  MAX(CASE WHEN a.type='D' THEN backup_sizeinMB  ELSE NULL END),
	FullDurationSeocnds = MAX(CASE WHEN a.type='D' 
										THEN DATEDIFF(SECOND, a.backup_start_date, a.backup_finish_date) ELSE NULL END),
	Last_Full_Backup_path = MAX(CASE WHEN a.type='D' 
										THEN a.physical_device_name ELSE NULL END),
	Last_Diff_Backup_start_Date = MAX(CASE WHEN a.type='I' 
										THEN a.backup_start_date ELSE NULL END),
	Last_Diff_Backup_end_date = MAX(CASE WHEN a.type='I' 
										 THEN a.backup_finish_date ELSE NULL END),
	Last_Diff_BackupSize_MB=  MAX(CASE WHEN a.type='I' THEN backup_sizeinMB  ELSE NULL END),
	DiffDurationSeocnds = MAX(CASE WHEN a.type='I' 
										THEN DATEDIFF(SECOND, a.backup_start_date, a.backup_finish_date) ELSE NULL END),
											Last_Diff_Backup_path = MAX(CASE WHEN a.type='I' 
										THEN a.physical_device_name ELSE NULL END),
	Last_Log_Backup_start_Date = MAX(CASE WHEN a.type='L' 
										THEN a.backup_start_date ELSE NULL END),
	Last_Log_Backup_end_date = MAX(CASE WHEN a.type='L' 
										 THEN a.backup_finish_date ELSE NULL END),
	Last_Log_BackupSize_MB=  MAX(CASE WHEN a.type='L' THEN backup_sizeinMB  ELSE NULL END),
	LogDurationSeocnds = MAX(CASE WHEN a.type='L' 
										THEN DATEDIFF(SECOND, a.backup_start_date, a.backup_finish_date) ELSE NULL END),
	Last_Log_Backup_path = MAX(CASE WHEN a.type='L' 
										THEN a.physical_device_name ELSE NULL END)

FROM
	MainBigSet a
group by 
	 servername,
	 name,
	 state_desc,
	 recovery_model_desc
--	order by name,backup_start_date desc
"

#Use SQLCmd to execute the query on the server
Invoke-Sqlcmd -ServerInstance $($serverName.Toupper()).Trim() -Query $Query -TrustServerCertificate

    }
}


Get-SQLData | Select servername,name,state_desc,recovery_model_desc,CurrentDateTime,Days_Since_Last_FUll_Backup,Days_Since_Last_Diff_Backup,Days_Since_Last_Log_Backup,Last_Full_Backup_end_date,FullDurationSeocnds,Last_Diff_Backup_end_date,DiffDurationSeocnds,Last_Log_Backup_end_date,LogDurationSeocnds | ConvertTo-Html -Head $Header -PreContent $pre | Set-CellColor -Property Days_Since_Last_FUll_Backup -Color red -Filter "Days_Since_Last_FUll_Backup -ge 8 "  |
Set-CellColor -Property "Days_Since_Last_Diff_Backup" -Color red -Filter "Days_Since_Last_Diff_Backup -ge 2"| Set-CellColor -Property "Days_Since_Last_Log_Backup" -Color red -Filter "Days_Since_Last_Log_Backup -ge 1"|  Out-File "R:\DBA\NTT\reports\Backup\NTT_Backup_HealthCheck$(Get-Date -Format "yyyy-MM-dd-HHmmss").html"

<#Get-SQLData | Select AGNAME,listener_name,availability_mode_desc,database_name,synchronization_state_desc,
synchronization_health_desc | ConvertTo-Html -Head $Header -PreContent $pre | Set-CellColor -Property synchronization_health_desc -Color red -Filter "synchronization_health_desc -ge 'NOT HEALTHY'"|  Out-File R:\DBA\NTT\reports\Backup\NTT_Backup_HealthCheck.html #>
#end_of_log_lsn,last_commit_lsn,last_commit_time | ConvertTo-Html -Head $Header -PreContent $Pre | Set-CellColor -Property synchronization_health_desc -Color red -Filter "synchronization_health_desc -ge 'NOT HEALTHY'"| Set-AlternatingRows -CSSEvenClass even -CssOddClass Odd | Out-File R:\DBA\NTT\reports\Backup\NTT_Backup_HealthCheck.html 

<#
#Send the file as e-mail
Send-MailMessage -from 'Grp-ACI-Speedpay-DBA@aciondemand.com' -to $To  -Subject "ALWAYS ON HEALTH CHECK REPORT" -SmtpServer 172.28.242.13 -Attachments R:\DBA\NTT\reports\Backup\NTT_Backup_HealthCheck.html -Body “Hi Team,
Please review attached file for BACKUP HEALTH CHECK Report.


Thanks,
DBA Team” #-BodyAsHtml (Get-Content R:\DBA\NTT\reports\Backup\NTT_Backup_HealthCheck.Html | Out-String)
#>


