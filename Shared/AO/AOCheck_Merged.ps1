[CmdletBinding()]
param(
    [string[]]$BusinessUnit,
    [switch]$AllBusinessUnits,
    [string]$ServerCsvPath = (Join-Path $PSScriptRoot 'InputServer.csv'),
    [string]$ReportRoot
)

if (-not (Test-Path -LiteralPath $ServerCsvPath -PathType Leaf)) {
    throw "Server CSV not found: $ServerCsvPath"
}

$serverRows = @(Import-Csv -LiteralPath $ServerCsvPath -ErrorAction Stop)
if ($serverRows.Count -eq 0 -or
    'Server' -notin $serverRows[0].PSObject.Properties.Name -or
    'BU' -notin $serverRows[0].PSObject.Properties.Name) {
    throw "Server CSV must contain Server and BU columns and at least one data row: $ServerCsvPath"
}

$invalidRows = @(
    $serverRows | Where-Object {
        [string]::IsNullOrWhiteSpace($_.Server) -or
        [string]::IsNullOrWhiteSpace($_.BU)
    }
)
if ($invalidRows.Count -gt 0) {
    throw "Server CSV contains rows with an empty Server or BU value: $ServerCsvPath"
}

$availableBusinessUnits = @(
    $serverRows |
        ForEach-Object { $_.BU.Trim() } |
        Sort-Object -Unique
)
$requestedBusinessUnits = @(
    $BusinessUnit |
        ForEach-Object { if ($null -ne $_) { $_.Trim() } } |
        Where-Object { $_ } |
        Select-Object -Unique
)

if ($AllBusinessUnits -and $requestedBusinessUnits.Count -gt 0) {
    throw 'Specify either -AllBusinessUnits or -BusinessUnit, not both.'
}
if ($AllBusinessUnits) {
    $businessUnitsToRun = $availableBusinessUnits
}
elseif ($requestedBusinessUnits.Count -gt 0) {
    $unknownBusinessUnits = @(
        $requestedBusinessUnits | Where-Object { $_ -notin $availableBusinessUnits }
    )
    if ($unknownBusinessUnits.Count -gt 0) {
        throw "Unknown BU(s): $($unknownBusinessUnits -join ', '). Available BUs: $($availableBusinessUnits -join ', ')"
    }
    $businessUnitsToRun = $requestedBusinessUnits
}
else {
    throw 'Specify one or more BUs with -BusinessUnit, or explicitly use -AllBusinessUnits.'
}

if (-not $ReportRoot) {
    $workspaceRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $workspaceDbaRoot = Join-Path $workspaceRoot 'DBA'
    if (Test-Path -LiteralPath $workspaceDbaRoot -PathType Container) {
        $ReportRoot = $workspaceDbaRoot
    }
    else {
        $ReportRoot = $workspaceRoot
    }
}

$missingReportDirectories = @(
    foreach ($businessUnitToRun in $businessUnitsToRun) {
        $candidateReportDirectory = Join-Path (Join-Path $ReportRoot $businessUnitToRun) 'reports\AO'
        if (-not (Test-Path -LiteralPath $candidateReportDirectory -PathType Container)) {
            $candidateReportDirectory
        }
    }
)
if ($missingReportDirectories.Count -gt 0) {
    throw "AO report directory not found: $($missingReportDirectories -join ', ')"
}

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
<title>ALWAYS ON HEALTH CHECK REPORT</title>
"@

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

function Get-SQLData {
    param(
        [Parameter(Mandatory)]
        [string[]]$ServerList
    )

    foreach ($serverName in $ServerList) {
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
IF OBJECT_ID  ('tempdb..#temp') IS NOT NULL DROP TABLE #temp
;WITH AG_Stats AS 
			(
			SELECT AR.replica_server_name,
				   HARS.role_desc, 
				   Db_name(DRS.database_id) [DBName]
			FROM   sys.dm_hadr_database_replica_states DRS 
			INNER JOIN sys.availability_replicas AR ON DRS.replica_id = AR.replica_id 
			INNER JOIN sys.dm_hadr_availability_replica_states HARS ON AR.group_id = HARS.group_id 
				AND AR.replica_id = HARS.replica_id 
			),
	Waits AS
			(
			select wait_type
				, waiting_tasks_count
				, wait_time_ms
				, wait_time_ms/waiting_tasks_count sync_lag_MS
			from sys.dm_os_wait_stats where waiting_tasks_count >0
			and wait_type = 'HADR_SYNC_COMMIT'
			),
	Pri_CommitTime AS 
			(
			SELECT	replica_server_name
					, DBName
			FROM	AG_Stats
			WHERE	role_desc = 'PRIMARY'
			),
	Sec_CommitTime AS 
			(
			SELECT	replica_server_name
					, DBName
			FROM	AG_Stats
			WHERE	role_desc = 'SECONDARY'
			)
SELECT --p.replica_server_name [primary_replica],
w.sync_lag_MS as 'Time Lag' into #temp
FROM Pri_CommitTime p
CROSS APPLY Waits w 

IF OBJECT_ID('tempdb..#temp2') IS NOT NULL DROP TABLE #temp2
select * into #temp2 from sys.dm_hadr_database_replica_states

SELECT ag.name AS AGName, listener_name=(select dns_name from sys.availability_group_listeners where dns_name<>'PRODDB21L'),
Primary_Replica=(SELECT distinct r.replica_server_name FROM sys.availability_replicas r
     INNER JOIN sys.dm_hadr_database_replica_states rs ON r.replica_id = rs.replica_id
	 where rs.is_primary_replica=1),
Secondary_Replica=(SELECT distinct r.replica_server_name FROM sys.availability_replicas r
     INNER JOIN sys.dm_hadr_database_replica_states rs ON r.replica_id = rs.replica_id
	 where rs.is_primary_replica=0 and (r.replica_server_name like '%GA%' or r.replica_server_name like '%GE%'
	 or r.replica_server_name like '%GP%') and r.failover_mode=0),
DR_server=(SELECT distinct r.replica_server_name FROM sys.availability_replicas r
     INNER JOIN sys.dm_hadr_database_replica_states rs ON r.replica_id = rs.replica_id
	 where rs.is_primary_replica=0 and r.replica_server_name like '%GR%' and r.failover_mode=1
	 ),
ar.availability_mode_desc, adc.[database_name],
drs.is_local, drs.is_primary_replica, drs.synchronization_state_desc,
drs.synchronization_health_desc, 
TimeLagMilliSeconds=(select max([Time Lag])  from #temp),
[log_send_rate KB/Sec]=(select isnull(min(log_send_rate), 0)  from #temp2 where synchronization_state_desc='SYNCHRONIZING' and log_send_rate<>0),
[redo_rate KB/Sec]=(select min(redo_rate) from #temp2 where synchronization_state_desc='SYNCHRONIZING' and redo_rate<>0),
drs.last_hardened_lsn, 
drs.end_of_log_lsn, drs.last_commit_lsn
--log_send_rate=(select min(log_send_rate) from #temp2 where synchronization_state_desc='SYNCHRONIZING' and log_send_rate<>0)
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
"

#Use SQLCmd to execute the query on the server
Invoke-Sqlcmd -ServerInstance $($serverName.Toupper()).Trim() -Query $Query -TrustServerCertificate

    }
}


foreach ($businessUnitToRun in $businessUnitsToRun) {
    $serverList = @(
        $serverRows |
            Where-Object { $_.BU.Trim() -eq $businessUnitToRun } |
            ForEach-Object { $_.Server.Trim() } |
            Where-Object { $_ }
    )
    if ($serverList.Count -eq 0) {
        throw "No servers found for BU '$businessUnitToRun' in $ServerCsvPath"
    }

    $reportDirectory = Join-Path (Join-Path $ReportRoot $businessUnitToRun) 'reports\AO'
    $archiveDirectory = Join-Path $reportDirectory 'Archive'
    New-Item -Path $archiveDirectory -ItemType Directory -Force | Out-Null
    Get-ChildItem -LiteralPath $reportDirectory -Filter '*.html' -File |
        Move-Item -Destination $archiveDirectory

    $date = Get-Date -Format 'yyyy/MM/dd HH:mm:ss'
    $Pre = "<font face='tahoma' color='blue' size='5'>AO HEALTH CHECK REPORT executed at - $date</font><br></br>"

    Get-SQLData -ServerList $serverList | Select-Object AGName,listener_name,Primary_Replica,Secondary_Replica,DR_server,availability_mode_desc,database_name,synchronization_state_desc,synchronization_health_desc,TimeLagMilliSeconds,
"log_send_rate KB/Sec","redo_rate KB/Sec",last_hardened_lsn,end_of_log_lsn,last_commit_lsn | ConvertTo-Html -Head $Header -PreContent $pre | Set-CellColor -Property synchronization_health_desc -Color red -Filter "synchronization_health_desc -ge 'NOT HEALTHY'"  |
Set-CellColor -Property "log_send_rate KB/Sec" -Color red -Filter "log_send_rate KB/Sec -ge '30000000'" |
Set-CellColor -Property "redo_rate KB/Sec" -Color red -Filter "redo_rate KB/Sec -ge '1115000'" |
    Out-File -FilePath (Join-Path $reportDirectory "$($businessUnitToRun)_AO_HealthCheck$(Get-Date -Format 'yyyy-MM-dd-HHmmss').html")
}

