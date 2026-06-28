# Hybrid Infra Console - VMware / multi-vSphere operations

. "$PSScriptRoot\ConfigStore.psm1"

function Test-PowerCliAvailable {
    return $null -ne (Get-Module -ListAvailable -Name VMware.PowerCLI)
}

function Import-PowerCli {
    if (-not (Test-PowerCliAvailable)) {
        throw 'VMware PowerCLI is not installed. Run: Install-Module VMware.PowerCLI -Scope CurrentUser'
    }

    Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Import-Module VMware.PowerCLI -ErrorAction Stop
}

function Connect-VsphereEndpoints {
    param(
        [Parameter(Mandatory)]
        [array]$VCenters,
        [System.Management.Automation.PSCredential]$Credential
    )

    Import-PowerCli
    Disconnect-VsphereSessions

    $results = @()
    foreach ($vc in @($VCenters)) {
        $server = [string]$vc.Server
        $name   = if ($vc.Name) { [string]$vc.Name } else { $server }

        try {
            $cred = $Credential
            if (-not $cred -and $vc.UseCredentialManager -and $vc.CredentialTarget) {
                $cred = Get-VcenterCredential -Server $server -CredentialTarget $vc.CredentialTarget
            }

            if ($cred) {
                $null = Connect-VIServer -Server $server -Credential $cred -ErrorAction Stop
            }
            else {
                $null = Connect-VIServer -Server $server -ErrorAction Stop
            }

            $results += [pscustomobject]@{
                Name      = $name
                Server    = $server
                Connected = $true
                Message   = 'Connected'
            }
        }
        catch {
            $results += [pscustomobject]@{
                Name      = $name
                Server    = $server
                Connected = $false
                Message   = $_.Exception.Message
            }
        }
    }

    return @($results)
}

function Disconnect-VsphereSessions {
    if (Get-Module -Name VMware.PowerCLI -ErrorAction SilentlyContinue) {
        Disconnect-VIServer -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    }
}

function Get-VsphereFleetInventory {
    param([string]$Filter = '')

    Import-PowerCli

    $servers = @(Get-VIServer -ErrorAction SilentlyContinue)
    if ($servers.Count -eq 0) {
        throw 'Not connected to any vCenter. Use Settings to connect first.'
    }

    $rows = @()
    foreach ($vis in $servers) {
        $vms = Get-VM -Server $vis -ErrorAction Stop

        if (-not [string]::IsNullOrWhiteSpace($Filter)) {
            $vms = $vms | Where-Object { $_.Name -like "*$Filter*" }
        }

        foreach ($vm in $vms) {
            $guest = $vm.ExtensionData.Guest
            $ip = if ($guest.IpAddress) { ($guest.IpAddress | Where-Object { $_ -match '^\d' } | Select-Object -First 1) } else { '' }
            $snapCount = (Get-Snapshot -VM $vm -Server $vis -ErrorAction SilentlyContinue | Measure-Object).Count

            $rows += [pscustomobject]@{
                VMName     = $vm.Name
                vCenter    = $vis.Name
                PowerState = $vm.PowerState.ToString()
                CPUs       = $vm.NumCpu
                MemoryGB   = [math]::Round($vm.MemoryGB, 1)
                IPAddress  = [string]$ip
                GuestOS    = $vm.Guest.OSFullName
                Cluster    = if ($vm.VMHost.Parent.Name) { $vm.VMHost.Parent.Name } else { $vm.VMHost.Name }
                Snapshots  = $snapCount
                ToolsStatus = $guest.ToolsStatus
            }
        }
    }

    return @($rows | Sort-Object vCenter, VMName)
}

function Get-VsphereSnapshotReport {
    param([int]$WarningDays = 7)

    Import-PowerCli

    $servers = @(Get-VIServer -ErrorAction SilentlyContinue)
    if ($servers.Count -eq 0) {
        throw 'Not connected to any vCenter.'
    }

    $cutoff = (Get-Date).AddDays(-1 * $WarningDays)
    $rows = @()

    foreach ($vis in $servers) {
        $vms = Get-VM -Server $vis -ErrorAction Stop
        foreach ($vm in $vms) {
            $snaps = @(Get-Snapshot -VM $vm -Server $vis -ErrorAction SilentlyContinue)
            foreach ($snap in $snaps) {
                $age = ((Get-Date) - $snap.Created).Days
                $rows += [pscustomobject]@{
                    VMName     = $vm.Name
                    vCenter    = $vis.Name
                    Snapshot   = $snap.Name
                    Created    = $snap.Created
                    AgeDays    = $age
                    SizeGB     = [math]::Round($snap.SizeGB, 2)
                    Status     = if ($age -ge $WarningDays) { 'Stale' } else { 'OK' }
                }
            }
        }
    }

    return @($rows | Sort-Object AgeDays -Descending)
}

function Set-VsphereVmPowerState {
    param(
        [Parameter(Mandatory)][string]$VMName,
        [Parameter(Mandatory)][string]$VCenter,
        [ValidateSet('Start', 'Stop', 'Restart')]
        [string]$Action
    )

    Import-PowerCli

    $vis = Get-VIServer | Where-Object { $_.Name -eq $VCenter -or $_.Name -like "*$VCenter*" } | Select-Object -First 1
    if (-not $vis) {
        throw "vCenter '$VCenter' is not connected."
    }

    $vm = Get-VM -Name $VMName -Server $vis -ErrorAction Stop

    switch ($Action) {
        'Start'   { Start-VM -VM $vm -Confirm:$false -ErrorAction Stop | Out-Null }
        'Stop'    { Stop-VM -VM $vm -Confirm:$false -ErrorAction Stop | Out-Null }
        'Restart' { Restart-VM -VM $vm -Confirm:$false -ErrorAction Stop | Out-Null }
    }

    return [pscustomobject]@{
        VMName     = $vm.Name
        vCenter    = $vis.Name
        PowerState = (Get-VM -VM $vm).PowerState.ToString()
        Action     = $Action
    }
}

function Get-VsphereFleetSummary {
    Import-PowerCli

    $servers = @(Get-VIServer -ErrorAction SilentlyContinue)
    if ($servers.Count -eq 0) {
        return [pscustomobject]@{
            vCenters    = 0
            TotalVMs    = 0
            PoweredOn   = 0
            PoweredOff  = 0
            WithSnaps   = 0
        }
    }

    $all = Get-VsphereFleetInventory
    $withSnaps = ($all | Where-Object { $_.Snapshots -gt 0 }).Count

    return [pscustomobject]@{
        vCenters   = $servers.Count
        TotalVMs   = $all.Count
        PoweredOn  = ($all | Where-Object { $_.PowerState -eq 'PoweredOn' }).Count
        PoweredOff = ($all | Where-Object { $_.PowerState -eq 'PoweredOff' }).Count
        WithSnaps  = $withSnaps
    }
}

Export-ModuleMember -Function @(
    'Test-PowerCliAvailable'
    'Connect-VsphereEndpoints'
    'Disconnect-VsphereSessions'
    'Get-VsphereFleetInventory'
    'Get-VsphereSnapshotReport'
    'Set-VsphereVmPowerState'
    'Get-VsphereFleetSummary'
)
