# ServerOps Toolkit - remote server operations

. "$PSScriptRoot\Theme.ps1"

function Test-IsLocalServerName {
    param([string]$Target)

    $normalized = $Target.Trim().TrimEnd('.')
    if ([string]::IsNullOrWhiteSpace($normalized)) {
        return $false
    }

    $localNames = @(
        'localhost'
        '127.0.0.1'
        '::1'
        $env:COMPUTERNAME
    )

    if ($env:USERDNSDOMAIN) {
        $localNames += "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"
    }

    foreach ($name in $localNames) {
        if ($normalized -ieq $name) {
            return $true
        }
    }

    try {
        $localEntry = [System.Net.Dns]::GetHostEntry($env:COMPUTERNAME)
        $localHosts = @($localEntry.HostName)
        $localHosts += $localEntry.AddressList | ForEach-Object { $_.ToString() }

        foreach ($alias in $localHosts) {
            if ($normalized -ieq $alias) {
                return $true
            }
        }

        $targetEntry = [System.Net.Dns]::GetHostEntry($normalized)
        if ($targetEntry.HostName -ieq $localEntry.HostName) {
            return $true
        }
    }
    catch {
        # DNS lookup failed; fall through to remote handling
    }

    return $false
}

function Get-CimTarget {
    param([string]$ComputerName)

    if ([string]::IsNullOrWhiteSpace($ComputerName)) {
        throw 'No server specified. Enter a server name and click Connect.'
    }

    if (Test-IsLocalServerName -Target $ComputerName) {
        return @{}
    }

    return @{ ComputerName = $ComputerName.Trim() }
}

function Connect-ServerOpsTarget {
    param([string]$ComputerName)

    try {
        $cim = Get-CimTarget -ComputerName $ComputerName
        $os = Get-CimInstance -ClassName Win32_OperatingSystem @cim -ErrorAction Stop

        [pscustomobject]@{
            Connected    = $true
            ComputerName = if ($cim.ComputerName) { $cim.ComputerName } else { $env:COMPUTERNAME }
            Caption      = $os.Caption
            Version      = $os.Version
            LastBoot     = $os.LastBootUpTime
            Uptime       = (Get-Date) - $os.LastBootUpTime
        }
    }
    catch {
        throw "Cannot connect to '$ComputerName'. Ensure the server is online, DNS resolves, and WinRM/CIM is enabled. Details: $($_.Exception.Message)"
    }
}

function Get-ServerHealthSnapshot {
    param([string]$ComputerName)

    $cim = Get-CimTarget -ComputerName $ComputerName
    $os = Get-CimInstance -ClassName Win32_OperatingSystem @cim -ErrorAction Stop
    $cpu = Get-CimInstance -ClassName Win32_Processor @cim -ErrorAction Stop | Select-Object -First 1
    $disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" @cim -ErrorAction Stop

    $diskRows = foreach ($disk in $disks) {
        $freePct = if ($disk.Size -gt 0) { [math]::Round(($disk.FreeSpace / $disk.Size) * 100, 1) } else { 0 }
        [pscustomobject]@{
            Drive       = $disk.DeviceID
            Label       = $disk.VolumeName
            SizeGB      = [math]::Round($disk.Size / 1GB, 1)
            FreeGB      = [math]::Round($disk.FreeSpace / 1GB, 1)
            FreePercent = $freePct
            Status      = Get-DiskStatusBrush -FreePercent $freePct
        }
    }

    [pscustomobject]@{
        ComputerName   = if ($cim.ComputerName) { $cim.ComputerName } else { $env:COMPUTERNAME }
        OS             = $os.Caption
        Uptime         = Format-Uptime -Span ((Get-Date) - $os.LastBootUpTime)
        TotalMemoryGB  = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        FreeMemoryGB   = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        CPU            = $cpu.Name
        LogicalCores   = $cpu.NumberOfLogicalProcessors
        Disks          = [object[]]$diskRows
    }
}

function Get-ServerServiceList {
    param(
        [string]$ComputerName,
        [string]$Filter = ''
    )

    $cim = Get-CimTarget -ComputerName $ComputerName
    $services = Get-Service @cim -ErrorAction Stop | Sort-Object DisplayName

    if (-not [string]::IsNullOrWhiteSpace($Filter)) {
        $services = $services | Where-Object {
            $_.DisplayName -like "*$Filter*" -or $_.Name -like "*$Filter*"
        }
    }

    return @($services | Select-Object Name, DisplayName, Status, StartType)
}

function Set-ServerServiceState {
    param(
        [string]$ComputerName,
        [string]$ServiceName,
        [ValidateSet('Start', 'Stop', 'Restart')]
        [string]$Action
    )

    $cim = Get-CimTarget -ComputerName $ComputerName
    $service = Get-Service -Name $ServiceName @cim -ErrorAction Stop

    switch ($Action) {
        'Start'   { Start-Service -InputObject $service -ErrorAction Stop }
        'Stop'    { Stop-Service -InputObject $service -ErrorAction Stop }
        'Restart' { Restart-Service -InputObject $service -ErrorAction Stop }
    }

    return (Get-Service -Name $ServiceName @cim)
}

function Get-ServerEventLogEntries {
    param(
        [string]$ComputerName,
        [ValidateSet('System', 'Application', 'Security')]
        [string]$LogName = 'System',
        [int]$MaxEvents = 50,
        [ValidateSet('Error', 'Warning', 'Information', 'All')]
        [string]$Level = 'Error'
    )

    $cim = Get-CimTarget -ComputerName $ComputerName
    $events = Get-WinEvent -LogName $LogName -MaxEvents $MaxEvents @cim -ErrorAction Stop

    if ($Level -ne 'All') {
        $levelId = switch ($Level) {
            'Error'         { 2 }
            'Warning'       { 3 }
            'Information'   { 4 }
        }
        $events = $events | Where-Object { $_.Level -eq $levelId }
    }

    return @($events | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message)
}

function Invoke-ServerOpsCommand {
    param(
        [string]$ComputerName,
        [string]$Command
    )

    if ([string]::IsNullOrWhiteSpace($Command)) {
        throw 'Enter a PowerShell command to run.'
    }

    $cim = Get-CimTarget -ComputerName $ComputerName
    $scriptBlock = [scriptblock]::Create($Command)

    if ($cim.Count -eq 0) {
        return (& $scriptBlock | Out-String).Trim()
    }

    return (Invoke-Command -ComputerName $cim.ComputerName -ScriptBlock $scriptBlock -ErrorAction Stop | Out-String).Trim()
}

Export-ModuleMember -Function @(
    'Connect-ServerOpsTarget'
    'Get-ServerHealthSnapshot'
    'Get-ServerServiceList'
    'Set-ServerServiceState'
    'Get-ServerEventLogEntries'
    'Invoke-ServerOpsCommand'
    'Get-DiskStatusBrush'
    'Format-Uptime'
    'Set-InfraTheme'
    'Export-InfraGridToCsv'
) -Variable Theme
