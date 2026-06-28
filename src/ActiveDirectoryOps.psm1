# Hybrid Infra Console - Active Directory / hybrid identity operations

function Test-ActiveDirectoryModule {
    return $null -ne (Get-Module -ListAvailable -Name ActiveDirectory)
}

function Import-ActiveDirectoryModule {
    if (-not (Test-ActiveDirectoryModule)) {
        throw 'ActiveDirectory module not found. Install RSAT: Active Directory tools on Windows 10/11 or Server.'
    }
    Import-Module ActiveDirectory -ErrorAction Stop
}

function Get-AdDomainSummary {
    Import-ActiveDirectoryModule

    $domain = Get-ADDomain -ErrorAction Stop
    $dcs = @(Get-ADDomainController -Filter * -ErrorAction Stop)
    $users = (Get-ADUser -Filter * -ErrorAction Stop | Measure-Object).Count
    $computers = (Get-ADComputer -Filter * -ErrorAction Stop | Measure-Object).Count
    $locked = @(Search-AdLockedOutUsers)

    $dcRows = foreach ($dc in $dcs) {
        $reachable = $false
        try {
            $reachable = Test-Connection -ComputerName $dc.HostName -Count 1 -Quiet -ErrorAction Stop
        }
        catch { $reachable = $false }

        [pscustomobject]@{
            Name       = $dc.Name
            HostName   = $dc.HostName
            Site       = $dc.Site
            IsGlobalCatalog = $dc.IsGlobalCatalog
            Reachable  = $reachable
        }
    }

    return [pscustomobject]@{
        DomainName   = $domain.DNSRoot
        Forest       = $domain.Forest
        DomainMode   = $domain.DomainMode
        UserCount    = $users
        ComputerCount = $computers
        LockedOut    = $locked.Count
        DomainControllers = @($dcRows)
    }
}

function Search-AdIdentityUser {
    param(
        [Parameter(Mandatory)][string]$Query,
        [string]$Domain = ''
    )

    Import-ActiveDirectoryModule

    if ([string]::IsNullOrWhiteSpace($Query)) {
        throw 'Enter a name, SAM account name, or email to search.'
    }

    $filter = "Name -like '*$Query*' -or SamAccountName -like '*$Query*' -or UserPrincipalName -like '*$Query*' -or mail -like '*$Query*'"
    $params = @{ Filter = $filter; Properties = @('DisplayName','SamAccountName','UserPrincipalName','mail','Enabled','LockedOut','LastLogonDate','PasswordExpired','PasswordLastSet','MemberOf','Description','whenCreated') }

    if ($Domain) {
        $params['Server'] = $Domain
    }

    $users = Get-ADUser @params -ErrorAction Stop

    return @($users | ForEach-Object {
        $hybridHint = 'On-prem'
        if ($_.UserPrincipalName -match '@.*\.onmicrosoft\.com$') {
            $hybridHint = 'Cloud UPN'
        }
        elseif ($_.UserPrincipalName -match '@') {
            $hybridHint = 'Hybrid (UPN set)'
        }

        [pscustomobject]@{
            DisplayName       = $_.DisplayName
            SamAccountName    = $_.SamAccountName
            UPN               = $_.UserPrincipalName
            Email             = $_.mail
            Enabled           = $_.Enabled
            LockedOut         = $_.LockedOut
            LastLogon         = $_.LastLogonDate
            PasswordExpired   = $_.PasswordExpired
            PasswordLastSet   = $_.PasswordLastSet
            GroupCount        = @($_.MemberOf).Count
            Description       = $_.Description
            Created           = $_.whenCreated
            HybridIdentity    = $hybridHint
            DistinguishedName = $_.DistinguishedName
        }
    } | Sort-Object DisplayName)
}

function Search-AdLockedOutUsers {
    Import-ActiveDirectoryModule

    $searcher = New-Object System.DirectoryServices.DirectorySearcher
    $searcher.Filter = '(&(objectClass=user)(objectCategory=person)(lockoutTime>=1))'
    $searcher.PropertiesToLoad.AddRange(@('displayName','sAMAccountName','mail','lockoutTime')) | Out-Null

    $results = $searcher.FindAll()
    $rows = @()

    foreach ($result in $results) {
        $props = $result.Properties
        $lockoutTime = if ($props['lockouttime'].Count -gt 0) { [DateTime]::FromFileTime([int64]$props['lockouttime'][0]) } else { $null }

        $rows += [pscustomobject]@{
            DisplayName    = [string]$props['displayname'][0]
            SamAccountName = [string]$props['samaccountname'][0]
            Email          = [string]$props['mail'][0]
            LockedSince    = $lockoutTime
        }
    }

    return @($rows | Sort-Object DisplayName)
}

function Unlock-AdIdentityUser {
    param([Parameter(Mandatory)][string]$SamAccountName)

    Import-ActiveDirectoryModule
    Unlock-ADAccount -Identity $SamAccountName -ErrorAction Stop
    return (Get-ADUser -Identity $SamAccountName -Properties LockedOut | Select-Object SamAccountName, LockedOut)
}

function Set-AdUserEnabledState {
    param(
        [Parameter(Mandatory)][string]$SamAccountName,
        [Parameter(Mandatory)][bool]$Enabled
    )

    Import-ActiveDirectoryModule
    Set-ADUser -Identity $SamAccountName -Enabled $Enabled -ErrorAction Stop
    return (Get-ADUser -Identity $SamAccountName -Properties Enabled | Select-Object SamAccountName, Enabled)
}

function Get-AdStaleComputerAccounts {
    param([int]$StaleDays = 90)

    Import-ActiveDirectoryModule

    $cutoff = (Get-Date).AddDays(-1 * $StaleDays)
    $computers = Get-ADComputer -Filter * -Properties LastLogonDate, OperatingSystem, Enabled -ErrorAction Stop

    return @($computers | Where-Object {
        -not $_.LastLogonDate -or $_.LastLogonDate -lt $cutoff
    } | ForEach-Object {
        [pscustomobject]@{
            Name           = $_.Name
            SamAccountName = $_.SamAccountName
            OperatingSystem = $_.OperatingSystem
            Enabled        = $_.Enabled
            LastLogon      = $_.LastLogonDate
            DaysStale      = if ($_.LastLogonDate) { ((Get-Date) - $_.LastLogonDate).Days } else { 9999 }
        }
    } | Sort-Object DaysStale -Descending)
}

function Get-AdUserGroupMembership {
    param([Parameter(Mandatory)][string]$SamAccountName)

    Import-ActiveDirectoryModule
    $groups = Get-ADPrincipalGroupMembership -Identity $SamAccountName -ErrorAction Stop

    return @($groups | Select-Object Name, GroupCategory, GroupScope | Sort-Object Name)
}

function Get-AadConnectSyncStatus {
    param([string]$ConnectServer = '')

    if ([string]::IsNullOrWhiteSpace($ConnectServer)) {
        if (-not (Get-Command Get-InfraSettings -ErrorAction SilentlyContinue)) {
            Import-Module (Join-Path $PSScriptRoot 'ConfigStore.psm1') -Force | Out-Null
        }
        $settings = Get-InfraSettings
        $ConnectServer = [string]$settings.aadConnectServer
    }

    if ([string]::IsNullOrWhiteSpace($ConnectServer)) {
        throw 'Set aadConnectServer in Settings or config (Azure AD Connect server hostname).'
    }

    $remoteScript = {
        $summary = [ordered]@{
            Server             = $env:COMPUTERNAME
            SchedulerEnabled   = $null
            SyncCycleEnabled   = $null
            StagingMode        = $null
            LastSyncTime       = $null
            LastSyncMessage    = ''
            Services           = @()
            Connectors         = @()
        }

        foreach ($svcName in @('ADSync', 'ADSyncScheduler')) {
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
            if ($svc) {
                $summary.Services += [pscustomobject]@{
                    Name      = $svc.Name
                    Status    = $svc.Status.ToString()
                    StartType = $svc.StartType.ToString()
                }
            }
        }

        if (Get-Module -ListAvailable -Name ADSync) {
            Import-Module ADSync -ErrorAction Stop

            if (Get-Command Get-ADSyncScheduler -ErrorAction SilentlyContinue) {
                $sched = Get-ADSyncScheduler
                $summary.SchedulerEnabled = [bool]$sched.SchedulerEnabled
                $summary.SyncCycleEnabled = [bool]$sched.SyncCycleEnabled
                $summary.StagingMode = [bool]$sched.StagingModeEnabled
            }

            if (Get-Command Get-ADSyncConnectorRunStatus -ErrorAction SilentlyContinue) {
                $summary.Connectors = @(Get-ADSyncConnectorRunStatus | ForEach-Object {
                    [pscustomobject]@{
                        Connector  = [string]$_.ConnectorName
                        Profile    = [string]$_.RunProfileName
                        Status     = if ($_.RunState) { [string]$_.RunState } else { 'Completed' }
                        StartTime  = $_.StartDate
                        EndTime    = $_.EndDate
                    }
                })
            }
        }

        $events = Get-WinEvent -FilterHashtable @{
            LogName   = 'Application'
            ProviderName = @('ADSync', 'Directory Synchronization')
            StartTime = (Get-Date).AddDays(-14)
        } -MaxEvents 20 -ErrorAction SilentlyContinue |
            Where-Object { $_.Id -in @(106, 209, 210, 2500, 2501, 2502) -or $_.Message -match 'sync' } |
            Select-Object -First 1

        if ($events) {
            $summary.LastSyncTime = $events.TimeCreated
            $firstLine = ($events.Message -split "`n" | Select-Object -First 1).Trim()
            if ($firstLine.Length -gt 120) {
                $firstLine = $firstLine.Substring(0, 120) + '...'
            }
            $summary.LastSyncMessage = $firstLine
        }

        [pscustomobject]$summary
    }

    $localNames = @('localhost', '127.0.0.1', $env:COMPUTERNAME)
    if ($env:USERDNSDOMAIN) {
        $localNames += "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)"
    }

    if ($ConnectServer.Trim().TrimEnd('.') -in $localNames) {
        return & $remoteScript
    }

    return Invoke-Command -ComputerName $ConnectServer.Trim() -ScriptBlock $remoteScript -ErrorAction Stop
}

Export-ModuleMember -Function @(
    'Test-ActiveDirectoryModule'
    'Get-AdDomainSummary'
    'Search-AdIdentityUser'
    'Search-AdLockedOutUsers'
    'Unlock-AdIdentityUser'
    'Set-AdUserEnabledState'
    'Get-AdStaleComputerAccounts'
    'Get-AdUserGroupMembership'
    'Get-AadConnectSyncStatus'
)
