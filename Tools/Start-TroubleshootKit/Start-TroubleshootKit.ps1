#requires -Version 5.1
<#
.SYNOPSIS
    One-click troubleshooting pack - collects diagnostics and zips for tickets.

.PARAMETER ComputerName
    Target server (local or remote).

.PARAMETER TicketNumber
    Optional ticket reference included in archive name.

.PARAMETER OutputDirectory
    Folder for the zip output.
#>

[CmdletBinding()]
param(
    [string]$ComputerName = $env:COMPUTERNAME,

    [string]$TicketNumber = '',

    [string]$OutputDirectory = (Join-Path $env:TEMP 'TroubleshootKit')
)

$ErrorActionPreference = 'Continue'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$workDir = Join-Path $OutputDirectory ("kit-{0}-{1}" -f $ComputerName, $stamp)

if (-not (Test-Path $workDir)) {
    $null = New-Item -ItemType Directory -Path $workDir -Force
}

$isLocal = ($ComputerName -in @('localhost', '127.0.0.1', $env:COMPUTERNAME))

function Save-TextReport {
    param([string]$Name, [string]$Content)
    Set-Content -Path (Join-Path $workDir $Name) -Value $Content -Encoding UTF8
}

function Invoke-LocalDiagnostics {
    Save-TextReport -Name '00-context.txt' -Content @"
Troubleshoot Kit
Computer: $ComputerName
User: $env:USERNAME
Generated: $(Get-Date -Format 'o')
Ticket: $TicketNumber
"@

    try {
        Get-CimInstance Win32_OperatingSystem |
            Select-Object CSName, Caption, Version, LastBootUpTime, TotalVisibleMemorySize, FreePhysicalMemory |
            Format-List | Out-String | ForEach-Object { Save-TextReport -Name '01-os.txt' -Content $_ }
    }
    catch { Save-TextReport -Name '01-os.txt' -Content $_.Exception.Message }

    try {
        Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' |
            Select-Object DeviceID, VolumeName, Size, FreeSpace |
            Format-Table -AutoSize | Out-String | ForEach-Object { Save-TextReport -Name '02-disks.txt' -Content $_ }
    }
    catch { Save-TextReport -Name '02-disks.txt' -Content $_.Exception.Message }

    try {
        Get-Service | Sort-Object Status, Name |
            Select-Object Name, DisplayName, Status, StartType |
            Format-Table -AutoSize | Out-String | ForEach-Object { Save-TextReport -Name '03-services.txt' -Content $_ }
    }
    catch { Save-TextReport -Name '03-services.txt' -Content $_.Exception.Message }

    try {
        Test-NetConnection -ComputerName '8.8.8.8' -Port 53 -WarningAction SilentlyContinue |
            Format-List | Out-String | ForEach-Object { Save-TextReport -Name '04-network-dns.txt' -Content $_ }
    }
    catch { Save-TextReport -Name '04-network-dns.txt' -Content $_.Exception.Message }

    try {
        Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Select-Object InterfaceAlias, IPAddress, PrefixLength |
            Format-Table -AutoSize | Out-String | ForEach-Object { Save-TextReport -Name '05-ipconfig.txt' -Content $_ }
    }
    catch { Save-TextReport -Name '05-ipconfig.txt' -Content $_.Exception.Message }

    foreach ($log in @('System', 'Application')) {
        try {
            Get-WinEvent -LogName $log -MaxEvents 200 -ErrorAction Stop |
                Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message |
                Format-Table -Wrap -AutoSize | Out-String -Width 300 |
                ForEach-Object { Save-TextReport -Name ("06-events-{0}.txt" -f $log) -Content $_ }
        }
        catch {
            Save-TextReport -Name ("06-events-{0}.txt" -f $log) -Content $_.Exception.Message
        }
    }

    try {
        Get-Process | Sort-Object CPU -Descending | Select-Object -First 25 Name, Id, CPU, WS |
            Format-Table -AutoSize | Out-String | ForEach-Object { Save-TextReport -Name '07-top-processes.txt' -Content $_ }
    }
    catch { Save-TextReport -Name '07-top-processes.txt' -Content $_.Exception.Message }

    try {
        wevtutil el | Out-String | ForEach-Object { Save-TextReport -Name '08-event-log-list.txt' -Content $_ }
    }
    catch { Save-TextReport -Name '08-event-log-list.txt' -Content $_.Exception.Message }
}

if ($isLocal) {
    Invoke-LocalDiagnostics
}
else {
    Write-Host "Collecting diagnostics on remote server: $ComputerName" -ForegroundColor Cyan
    $remoteOut = 'C:\Temp\TroubleshootKit'
    Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        param($ScriptPath, $Ticket, $OutDir)
        if (-not (Test-Path $ScriptPath)) {
            throw "Copy Start-TroubleshootKit.ps1 to the target or run from a shared script path. Missing: $ScriptPath"
        }
        & $ScriptPath -ComputerName localhost -TicketNumber $Ticket -OutputDirectory $OutDir
    } -ArgumentList $PSCommandPath, $TicketNumber, $remoteOut -ErrorAction Stop

    Write-Host "Remote pack created on \\$ComputerName\C$\Temp\TroubleshootKit (or target OutDir)." -ForegroundColor Green
    exit 0
}

$zipName = if ($TicketNumber) {
    "Troubleshoot-{0}-{1}.zip" -f $TicketNumber, $ComputerName
}
else {
    "Troubleshoot-{0}-{1}.zip" -f $ComputerName, $stamp
}

$zipPath = Join-Path $OutputDirectory $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($workDir, $zipPath)

Write-Host "Troubleshoot pack: $zipPath" -ForegroundColor Green
Write-Host "Working folder: $workDir"
