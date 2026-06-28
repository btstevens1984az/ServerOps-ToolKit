#requires -Version 5.1
<#
.SYNOPSIS
    Generate 30 SolarWinds Orion modern dashboard JSON exports for infra ops.
#>

$ErrorActionPreference = 'Stop'
$outDir = Join-Path $PSScriptRoot 'dashboards'
if (-not (Test-Path $outDir)) {
    $null = New-Item -ItemType Directory -Path $outDir -Force
}

$dashboards = @(
    @{ Id = '01'; Title = 'Windows Server Fleet Health Overview'; Category = 'Windows'; Focus = 'Win32_PerfRawData' }
    @{ Id = '02'; Title = 'Linux Server Fleet Health Overview'; Category = 'Linux'; Focus = 'Linux CPU Memory Disk' }
    @{ Id = '03'; Title = 'Virtual Windows Server Performance'; Category = 'VMware'; Focus = 'Windows VMs CPU RAM' }
    @{ Id = '04'; Title = 'Virtual Linux Server Performance'; Category = 'VMware'; Focus = 'Linux VMs CPU RAM' }
    @{ Id = '05'; Title = 'Physical Server Hardware Health'; Category = 'Hardware'; Focus = 'IPMI temperature power' }
    @{ Id = '06'; Title = 'Critical Windows Services Availability'; Category = 'Windows'; Focus = 'SAM Windows services' }
    @{ Id = '07'; Title = 'Critical Linux Daemon Availability'; Category = 'Linux'; Focus = 'SAM Linux processes' }
    @{ Id = '08'; Title = 'Cross-Platform CPU Hotspots'; Category = 'Mixed'; Focus = 'Top CPU all nodes' }
    @{ Id = '09'; Title = 'Memory Pressure Alert Board'; Category = 'Mixed'; Focus = 'High memory utilization' }
    @{ Id = '10'; Title = 'Windows Disk Capacity and Forecast'; Category = 'Windows'; Focus = 'Volume capacity trend' }
    @{ Id = '11'; Title = 'Linux Filesystem Capacity and Forecast'; Category = 'Linux'; Focus = 'Mount point capacity' }
    @{ Id = '12'; Title = 'WSUS Patch Compliance Summary'; Category = 'Patching'; Focus = 'Patch status Windows' }
    @{ Id = '13'; Title = 'SCCM Patch Compliance Dashboard'; Category = 'Patching'; Focus = 'SCCM compliance' }
    @{ Id = '14'; Title = 'Linux Package Patch Status'; Category = 'Patching'; Focus = 'YUM APT updates' }
    @{ Id = '15'; Title = 'Certificate Expiration Radar'; Category = 'Security'; Focus = 'Cert expiry SAM' }
    @{ Id = '16'; Title = 'Internal PKI Cert 30-60-90 Day View'; Category = 'Security'; Focus = 'PKI cert timeline' }
    @{ Id = '17'; Title = 'Web Server SSL TLS Certificate Monitor'; Category = 'Security'; Focus = 'HTTPS cert SAM' }
    @{ Id = '18'; Title = 'Windows Critical Event Log Errors'; Category = 'Windows'; Focus = 'Event log errors' }
    @{ Id = '19'; Title = 'Linux Syslog Severity Dashboard'; Category = 'Linux'; Focus = 'Syslog critical warn' }
    @{ Id = '20'; Title = 'Active Directory Domain Controller Health'; Category = 'Windows'; Focus = 'AD DC replication' }
    @{ Id = '21'; Title = 'DNS Resolution Performance'; Category = 'Network'; Focus = 'DNS response time' }
    @{ Id = '22'; Title = 'Server-to-Server Network Latency'; Category = 'Network'; Focus = 'Latency packet loss' }
    @{ Id = '23'; Title = 'VMware Cluster Capacity and Oversubscription'; Category = 'VMware'; Focus = 'Host CPU RAM ratios' }
    @{ Id = '24'; Title = 'Hyper-V Host Capacity Overview'; Category = 'Hyper-V'; Focus = 'Hyper-V host resources' }
    @{ Id = '25'; Title = 'SQL Server Instance Health'; Category = 'Application'; Focus = 'SQL performance SAM' }
    @{ Id = '26'; Title = 'IIS Web Server Availability and Response'; Category = 'Application'; Focus = 'IIS uptime response' }
    @{ Id = '27'; Title = 'RDS Session Host Load and Sessions'; Category = 'Windows'; Focus = 'RDS sessions CPU' }
    @{ Id = '28'; Title = 'Backup Job Success Rate'; Category = 'Operations'; Focus = 'Backup SAM jobs' }
    @{ Id = '29'; Title = 'EDR and Antivirus Agent Status'; Category = 'Security'; Focus = 'AV EDR heartbeat' }
    @{ Id = '30'; Title = 'Change Window Infrastructure Readiness'; Category = 'Operations'; Focus = 'Alerts down nodes patch' }
)

function New-SwqlQuery {
    param([string]$Focus, [string]$Category)

    switch -Regex ($Focus) {
        'Win32' { return "SELECT N.Caption, N.IPAddress, CPULoad, PercentMemoryUsed FROM Orion.Nodes N INNER JOIN Orion.CPULoad CL ON N.NodeID = CL.NodeID WHERE N.OSVersion LIKE '%Windows%' AND N.Status <> 9 ORDER BY CPULoad DESC" }
        'Linux' { return "SELECT N.Caption, N.IPAddress, AvgResponseTime, PercentLoss FROM Orion.Nodes N INNER JOIN Orion.ResponseTime RT ON N.NodeID = RT.NodeID WHERE N.OSVersion LIKE '%Linux%' ORDER BY PercentLoss DESC" }
        'VMware' { return "SELECT VM.Name, VM.VMwareMemoryUsage, VM.VMwareCpuUsage FROM Orion.VIM.VirtualMachines VM WHERE VM.PowerState = 'PoweredOn' ORDER BY VM.VMwareCpuUsage DESC" }
        'IPMI' { return "SELECT H.Caption, H.PercentMemory, H.PercentCPU, H.Status FROM Orion.HardwareHealth.HardwareInfo H ORDER BY H.Status DESC" }
        'Cert' { return "SELECT CertificateName, ExpirationDate, DaysUntilExpiration FROM Orion.CertificateManager.Certificates WHERE DaysUntilExpiration < 90 ORDER BY DaysUntilExpiration ASC" }
        'Event' { return "SELECT TOP 50 EventTime, EventType, Message FROM Orion.Events WHERE EventType > 2 ORDER BY EventTime DESC" }
        'DNS' { return "SELECT Node.Caption, A.AvgResponseTime FROM Orion.Nodes Node INNER JOIN Orion.ResponseTime A ON Node.NodeID = A.NodeID WHERE Node.Caption LIKE '%DNS%' ORDER BY A.AvgResponseTime DESC" }
        'SQL' { return "SELECT Application.Name, Application.Status FROM Orion.APM.Application Application WHERE Application.Name LIKE '%SQL%' ORDER BY Application.Status" }
        'Backup' { return "SELECT JobName, LastRun, LastRunResult FROM Orion.BackupJobs ORDER BY LastRun DESC" }
        default { return "SELECT Caption, IPAddress, Status, StatusDescription FROM Orion.Nodes WHERE Status <> 1 ORDER BY Caption" }
    }
}

$catalog = @()

foreach ($dash in $dashboards) {
    $fileName = ("dashboard-{0}-{1}.json" -f $dash.Id, ($dash.Title -replace '[^a-zA-Z0-9]+', '-').Trim('-').ToLower())
    $filePath = Join-Path $outDir $fileName
    $swql = New-SwqlQuery -Focus $dash.Focus -Category $dash.Category

    $widgetTemplates = @(
        @{ Title = 'Status Summary'; Type = 'Status'; Query = "SELECT Status, COUNT(*) AS Count FROM Orion.Nodes GROUP BY Status" }
        @{ Title = 'Top Offenders'; Type = 'Table'; Query = $swql }
        @{ Title = '24 Hour Trend'; Type = 'Timeseries'; Query = "SELECT DateTime, AVG(StatValue) AS Value FROM Orion.ResponseTime WHERE DateTime > GETDATE()-1 GROUP BY DateTime" }
        @{ Title = 'Alert Count'; Type = 'Counter'; Query = "SELECT COUNT(*) AS ActiveAlerts FROM Orion.AlertActive" }
    )

    $widgets = @()
    $x = 0
    $y = 0
    $wi = 0
    foreach ($wt in $widgetTemplates) {
        $widgets += [ordered]@{
            id           = ("w-{0}-{1}" -f $dash.Id, $wi)
            title        = $wt.Title
            type         = $wt.Type
            layout       = [ordered]@{ x = $x; y = $y; width = 6; height = 4 }
            dataSettings = [ordered]@{
                swql         = $wt.Query
                refreshRate  = 300
                chartType    = if ($wt.Type -eq 'Timeseries') { 'line' } else { 'table' }
            }
        }
        $x += 6
        if ($x -ge 12) { $x = 0; $y += 4 }
        $wi++
    }

    $export = [ordered]@{
        schemaVersion = '2024.1'
        source        = 'ServerOpsToolkit - Thwack-inspired community patterns'
        dashboard     = [ordered]@{
            name         = $dash.Title
            description  = ("Modern Orion dashboard for {0} infrastructure monitoring. Category: {1}." -f $dash.Category, $dash.Focus)
            category     = $dash.Category
            tags         = @($dash.Category, 'Infrastructure', 'ServerOpsToolkit')
            autoRefresh  = 300
            widgets      = $widgets
        }
    }

    $export | ConvertTo-Json -Depth 8 | Set-Content -Path $filePath -Encoding UTF8

    $catalog += [ordered]@{
        id       = $dash.Id
        title    = $dash.Title
        category = $dash.Category
        file     = $fileName
    }
}

$catalogPath = Join-Path $outDir 'catalog.json'
[ordered]@{
    generated = (Get-Date).ToString('o')
    count     = $catalog.Count
    dashboards = $catalog
} | ConvertTo-Json -Depth 5 | Set-Content -Path $catalogPath -Encoding UTF8

Write-Host ("Generated {0} dashboards in {1}" -f $catalog.Count, $outDir)
