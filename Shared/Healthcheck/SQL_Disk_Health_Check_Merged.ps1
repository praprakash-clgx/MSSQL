[CmdletBinding()]
param(
    [string[]]$BusinessUnit,
    [switch]$AllBusinessUnits,
    [string]$ReportRoot
)

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

$serverCsvPath = Join-Path $PSScriptRoot 'InputServer.csv'
if (-not (Test-Path -LiteralPath $serverCsvPath -PathType Leaf)) {
    throw "Server CSV not found: $serverCsvPath"
}
$serverRows = @(Import-Csv -LiteralPath $serverCsvPath -ErrorAction Stop)
if ($serverRows.Count -eq 0 -or
    'Server' -notin $serverRows[0].PSObject.Properties.Name -or
    'BU' -notin $serverRows[0].PSObject.Properties.Name) {
    throw "Server CSV must contain Server and BU columns and at least one data row: $serverCsvPath"
}
$invalidRows = @(
    $serverRows | Where-Object {
        [string]::IsNullOrWhiteSpace($_.Server) -or
        [string]::IsNullOrWhiteSpace($_.BU)
    }
)
if ($invalidRows.Count -gt 0) {
    throw "Server CSV contains rows with an empty Server or BU value: $serverCsvPath"
}

$availableBusinessUnits = @(
    $serverRows |
        ForEach-Object { $_.BU.Trim() } |
        Sort-Object -Unique
)
if ($availableBusinessUnits.Count -eq 0) {
    throw "No BU values found in server CSV: $serverCsvPath"
}

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

foreach ($businessUnitToRun in $businessUnitsToRun) {
    $reportDirectory = Join-Path (Join-Path $ReportRoot $businessUnitToRun) 'reports\Healthcheck'
    if (-not (Test-Path -LiteralPath $reportDirectory -PathType Container)) {
        throw "Healthcheck report directory not found for BU '$businessUnitToRun': $reportDirectory"
    }
    $serverLines = @(
        $serverRows |
            Where-Object { $_.BU.Trim() -eq $businessUnitToRun } |
            ForEach-Object { $_.Server.Trim() } |
            Where-Object { $_ }
    )
    if ($serverLines.Count -eq 0) {
        throw "No servers found for BU '$businessUnitToRun' in $serverCsvPath"
    }
    foreach ($serverLine in $serverLines) {
        $serverInfo = $serverLine.Trim() -split ',', 2
        if ($serverInfo.Count -eq 2) {
            $portNumber = 0
            if (-not [int]::TryParse($serverInfo[1].Trim(), [ref]$portNumber) -or $portNumber -lt 1 -or $portNumber -gt 65535) {
                throw "Invalid SQL port in server entry '$serverLine' for BU '$businessUnitToRun'"
            }
        }
    }
}

foreach ($businessUnitToRun in $businessUnitsToRun) {
    $reportDirectory = Join-Path (Join-Path $ReportRoot $businessUnitToRun) 'reports\Healthcheck'
    $serverLines = @(
        $serverRows |
            Where-Object { $_.BU.Trim() -eq $businessUnitToRun } |
            ForEach-Object { $_.Server.Trim() } |
            Where-Object { $_ }
    )
    $archiveDirectory = Join-Path $reportDirectory 'Archive'
    New-Item -Path $archiveDirectory -ItemType Directory -Force | Out-Null
    Get-ChildItem -LiteralPath $reportDirectory -Filter '*.html' -File |
        Move-Item -Destination $archiveDirectory

    $currentDateTime = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $reportFilePath = Join-Path $reportDirectory "${businessUnitToRun}_SQL_Server_Health_Report_$currentDateTime.html"

# Initialize HTML report header
$htmlReport = @"
<html>
<head>
<style>
    body { background-color: #FFFFFF; font-family: Tahoma; font-size: 12pt; }
    h2 { color: #333399; }
    p { font-size: 12px; color: #333; }
    table { width: 95%; margin-left: 10px; margin-bottom: 20px; table-layout: auto; }
    th { background-color: lightblue ; color: black; font-weight: bold; padding: 8px; text-align: center; border: 1px solid #ddd; }
    td { border: 1px solid #ddd; padding: 8px; text-align: center; font-weight: normal; }
    .hostname { background-color: #f2f2f2; font-weight: bold; } /* Hostname column with grey background */
    .highlight { color: red; font-weight: bold; } /* Free % values less than 20% will be in red */
    .star { color: red; font-weight: bold; } /* Red for star symbol */
    .server-info { background-color: #f9f9f9; font-weight: bold; } /* Server-level info styling */
    .running-status { color: green; font-weight: bold; } /* Green for running status */
    .negative { color: red; font-weight: bold; } /* Red for negative results */
</style>
</head>
<body>
<h2>SQL Server Health Report</h2>
<p>Report Generated On: $currentDateTime</p>
<table>
<tr>
    <th>Hostname</th>
    <th>SQL Instance Status</th>
    <th>SQL Agent Status</th>
    <th>Last Reboot Date</th>
    <th>Database Status</th>
    <th>TempDB Size (MB)</th>
    <th>Disk</th>
    <th>Free Space (GB)</th>
    <th>Used Space (GB)</th>
    <th>Total Size (GB)</th>
    <th>Free %</th>
</tr>
"@

# Loop through each server in the list
foreach ($serverLine in $serverLines) {
    $serverInfo = $serverLine.Split(",")
    $serverName = $serverInfo[0]
    $portNumber = if ($serverInfo.Count -eq 2) { $serverInfo[1] } else { "1433" }

    # Construct server connection string
    $serverConnectionString = if ($portNumber -eq "1433") { $serverName } else { "$serverName,$portNumber" }

    # Retrieve SQL instance and SQL agent status
    $sqlInstanceStatus = invoke-command -ComputerName $serverName -ScriptBlock {
        (Get-Service -Name "MSSQLSERVER" -ErrorAction SilentlyContinue).Status
    }
    $sqlInstanceStatus = $sqlInstanceStatus.tostring()

    $sqlAgentStatus = invoke-command -ComputerName $serverName -ScriptBlock {
        (Get-Service -Name "SQLSERVERAGENT" -ErrorAction SilentlyContinue).status
    }
    $sqlAgentStatus = $sqlAgentStatus.tostring()

    # Get running status color
    $sqlInstanceStatusClass = if ($sqlInstanceStatus -eq "Running") { "running-status" } else { "negative" }
    $sqlAgentStatusClass = if ($sqlAgentStatus -eq "Running") { "running-status" } else { "negative" }

    # Retrieve last reboot time
    $lastRebootTime = invoke-command -ComputerName $serverName -ScriptBlock {
        (Get-WmiObject -Class Win32_OperatingSystem).LastBootUpTime
    }
    $lastRebootDate = [Management.ManagementDateTimeConverter]::ToDateTime($lastRebootTime).ToString("yyyy-MM-dd HH:mm:ss")

    # Connect to SQL Server to check database statuses and tempdb size
    $databaseStatus = Invoke-Sqlcmd -ServerInstance $serverConnectionString -Database master -Query "SELECT CASE WHEN EXISTS (SELECT state_desc FROM sys.databases WHERE state_desc <> 'ONLINE') THEN 'Some databases are offline' ELSE 'All databases are online' END ;" -TrustServerCertificate | Format-Table -HideTableHeaders | out-string
    $databaseStatus = $databaseStatus.tostring()

    if ($databaseStatus -match "All databases are online") {
        $databaseStatusClass = "running-status"
    } else {
        $databaseStatusClass = "negative"
    }

    $tempDBSizeMB = Invoke-Sqlcmd -ServerInstance $serverConnectionString -Database master -Query "SELECT SUM(convert(decimal(10,2),size * 8.0 / 1024)) FROM sys.master_files WHERE database_id = 2;" -TrustServerCertificate | Format-Table -HideTableHeaders | out-string

    # Retrieve disk information
    $drives = invoke-command -ComputerName $serverName -ScriptBlock {
        Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue
    }

    # Create a flag for merged columns on the first drive row
    $isFirstDrive = $true

    # Loop through each drive
    foreach ($drive in $drives) {
        $totalSizeGB = [math]::round($drive.Size / 1GB, 2)
        $freeSpaceGB = [math]::round($drive.FreeSpace / 1GB, 2)
        $usedSpaceGB = [math]::round(($drive.Size - $drive.FreeSpace) / 1GB, 2)
        $freePercentage = [math]::round(($drive.FreeSpace / $drive.Size) * 100, 2)

        # Threshold limits
        if ($totalSizeGB -lt 500) { $AlertPercent = 10 }
        elseif ($totalSizeGB -lt 1000) { $AlertPercent = 8 }
        elseif ($totalSizeGB -lt 2000) { $AlertPercent = 7 }
        elseif ($totalSizeGB -lt 4000) { $AlertPercent = 6 }
        elseif ($totalSizeGB -lt 6000) { $AlertPercent = 5 }
        elseif ($totalSizeGB -lt 8000) { $AlertPercent = 4 }
        elseif ($totalSizeGB -lt 10000) { $AlertPercent = 3 }
        else { $AlertPercent = 1 }

        # Apply red color and star if free space is below the threshold
        $highlightFreeSpace = if ($freePercentage -lt $AlertPercent) { "$freeSpaceGB <span class='star'></span>" } else { "$freeSpaceGB" }
        $highlightFreePercentage = if ($freePercentage -lt $AlertPercent) { "<span class='highlight'>$freePercentage % *</span>" } else { "$freePercentage %" }

        # Append data to HTML report with merged columns for the first drive row
        $htmlReport += @"
        <tr>
"@
        if ($isFirstDrive) {
            $htmlReport += @"
            <td rowspan='$($drives.Count)' class='hostname'>$serverName</td>
            <td rowspan='$($drives.Count)' class='server-info $sqlInstanceStatusClass'>$sqlInstanceStatus</td>
            <td rowspan='$($drives.Count)' class='server-info $sqlAgentStatusClass'>$sqlAgentStatus</td>
            <td rowspan='$($drives.Count)' class='server-info'>$lastRebootDate</td>
            <td rowspan='$($drives.Count)' class='server-info $databaseStatusClass'>$databaseStatus</td>
            <td rowspan='$($drives.Count)' class='server-info'>$tempDBSizeMB</td>
"@
            $isFirstDrive = $false
        }

        $htmlReport += @"
            <td>$($drive.DeviceID)</td>
            <td>$highlightFreeSpace</td>
            <td>$usedSpaceGB</td>
            <td>$totalSizeGB</td>
            <td>$highlightFreePercentage</td>
        </tr>
"@
    }
}

# Close HTML tags

$htmlReport += @"
</table>
</body>
</html>
"@

# Save the HTML report to a file with the current date and time in the filename
$htmlReport | Out-File -FilePath $reportFilePath -Encoding UTF8
    Write-Host "Report written to $reportFilePath"
}