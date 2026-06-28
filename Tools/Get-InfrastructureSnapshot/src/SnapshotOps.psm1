# Infrastructure snapshot collectors (no UI)

function Get-SnapshotConfigPath {
    return (Join-Path $env:APPDATA 'InfraSnapshot\settings.json')
}

function Get-SnapshotDefaultConfig {
    [pscustomobject]@{
        vCenters   = @('vcenter.example.local')
        infobloxHost = 'infoblox.example.local'
        orionHost  = 'orion.example.local'
    }
}

function Get-SnapshotConfig {
    $path = Get-SnapshotConfigPath
    $dir = Split-Path $path -Parent
    if (-not (Test-Path $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }

    if (-not (Test-Path $path)) {
        $defaults = Get-SnapshotDefaultConfig
        $defaults | ConvertTo-Json -Depth 4 | Set-Content -Path $path -Encoding UTF8
    }

    return (Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-VmSnapshotSection {
    param(
        [Parameter(Mandatory)][string]$ServerName,
        [string[]]$vCenters
    )

    $lines = @("## VMware (vCenter)", "")
    if (-not (Get-Module -ListAvailable VMware.PowerCLI)) {
        $lines += "_VMware.PowerCLI not installed._"
        return $lines
    }

    Import-Module VMware.PowerCLI -ErrorAction SilentlyContinue
    Set-PowerCLIConfiguration -ParticipateInCEIP $false -Confirm:$false -Scope User | Out-Null

    $found = $false
    foreach ($vc in $vCenters) {
        try {
            if (-not $global:DefaultVIServers -or $vc -notin @($global:DefaultVIServers.Name)) {
                Connect-VIServer -Server $vc -ErrorAction Stop | Out-Null
            }

            $vm = Get-VM -Name $ServerName -ErrorAction SilentlyContinue
            if ($vm) {
                $found = $true
                $lines += "| Field | Value |"
                $lines += "|-------|-------|"
                $lines += "| vCenter | $vc |"
                $lines += "| Power State | $($vm.PowerState) |"
                $lines += "| CPUs | $($vm.NumCpu) |"
                $lines += "| Memory GB | $($vm.MemoryGB) |"
                $lines += "| Guest OS | $($vm.Guest.OSFullName) |"
                $lines += "| IP Address | $($vm.Guest.IPAddress -join ', ') |"
                $lines += "| Cluster | $((Get-VM -Name $ServerName | Get-Cluster).Name) |"
                $lines += "| Host | $($vm.VMHost.Name) |"
                $lines += ""
                $snaps = Get-Snapshot -VM $vm -ErrorAction SilentlyContinue
                if ($snaps) {
                    $lines += "### Snapshots"
                    foreach ($s in $snaps) {
                        $lines += "- $($s.Name) ($($s.Created))"
                    }
                }
                break
            }
        }
        catch {
            $lines += "_vCenter $vc : $($_.Exception.Message)_"
        }
    }

    if (-not $found) {
        $lines += "_VM '$ServerName' not found on configured vCenters._"
    }

    return $lines
}

function Get-InfobloxSnapshotSection {
    param(
        [Parameter(Mandatory)][string]$ServerName,
        [string]$InfobloxHost,
        [pscredential]$Credential
    )

    $lines = @("", "## DNS (Infoblox)", "")
    if (-not $InfobloxHost) {
        $lines += "_Infoblox host not configured._"
        return $lines
    }

    try {
        $baseUri = "https://$InfobloxHost/wapi/v2.12/record:host"
        $params = @{
            Uri             = $baseUri
            Credential      = $Credential
            Method          = 'GET'
            Query           = @{ name = $ServerName }
            SkipCertificateCheck = $true
        }
        if ($Credential) {
            $resp = Invoke-RestMethod @params
            if ($resp) {
                foreach ($record in @($resp)) {
                    $lines += "- Host record: $($record.name) -> $($record.ipv4addr -join ', ')"
                }
            }
            else {
                $lines += "_No Infoblox host record found for $ServerName._"
            }
        }
        else {
            $lines += "_Provide -InfobloxCredential to query Infoblox WAPI._"
        }
    }
    catch {
        $lines += "_Infoblox query failed: $($_.Exception.Message)_"
    }

    return $lines
}

function Get-OrionSnapshotSection {
    param(
        [Parameter(Mandatory)][string]$ServerName,
        [string]$OrionHost,
        [pscredential]$Credential
    )

    $lines = @("", "## Monitoring (SolarWinds Orion)", "")
    if (-not $OrionHost) {
        $lines += "_Orion host not configured._"
        return $lines
    }

    try {
        if (-not (Get-Module -ListAvailable SwisPowerShell)) {
            $lines += "_SwisPowerShell module not installed._"
            return $lines
        }

        Import-Module SwisPowerShell -ErrorAction Stop
        if (-not $Credential) {
            $lines += "_Provide -OrionCredential to query Orion SWIS._"
            return $lines
        }

        Connect-Swis -Hostname $OrionHost -Credential $Credential | Out-Null
        $swql = "SELECT NodeID, Caption, IPAddress, Status, StatusDescription, MachineType FROM Orion.Nodes WHERE Caption LIKE '%$ServerName%'"
        $nodes = Get-SwisData -Query $swql
        if ($nodes) {
            foreach ($node in @($nodes)) {
                $lines += "- Node: $($node.Caption) | IP: $($node.IPAddress) | Status: $($node.StatusDescription)"
            }
        }
        else {
            $lines += "_No Orion node matched '$ServerName'._"
        }
    }
    catch {
        $lines += "_Orion query failed: $($_.Exception.Message)_"
    }

    return $lines
}

function Get-LocalServerSnapshotSection {
    param([Parameter(Mandatory)][string]$ServerName)

    $lines = @("", "## Windows Server (CIM)", "")
    try {
        $cimParam = @{ ClassName = 'Win32_OperatingSystem'; ErrorAction = 'Stop' }
        if ($ServerName -notin @('localhost', $env:COMPUTERNAME)) {
            $cimParam['ComputerName'] = $ServerName
        }

        $os = Get-CimInstance @cimParam
        $cs = Get-CimInstance -ClassName Win32_ComputerSystem @cimParam
        $lines += "| Field | Value |"
        $lines += "|-------|-------|"
        $lines += "| OS | $($os.Caption) |"
        $lines += "| Version | $($os.Version) |"
        $lines += "| Last Boot | $($os.LastBootUpTime) |"
        $lines += "| Domain | $($cs.Domain) |"
        $lines += "| Manufacturer | $($cs.Manufacturer) |"
        $lines += "| Model | $($cs.Model) |"
    }
    catch {
        $lines += "_CIM query failed: $($_.Exception.Message)_"
    }

    return $lines
}

function New-InfrastructureSnapshotMarkdown {
    param(
        [Parameter(Mandatory)][string]$ServerName,
        [string]$OutputPath,
        [pscredential]$InfobloxCredential,
        [pscredential]$OrionCredential
    )

    $config = Get-SnapshotConfig
    $header = @(
        "# Infrastructure Snapshot: $ServerName"
        ""
        "**Generated:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        ""
    )

    $body = @()
    $body += Get-LocalServerSnapshotSection -ServerName $ServerName
    $body += Get-VmSnapshotSection -ServerName $ServerName -vCenters @($config.vCenters)
    $body += Get-InfobloxSnapshotSection -ServerName $ServerName -InfobloxHost $config.infobloxHost -Credential $InfobloxCredential
    $body += Get-OrionSnapshotSection -ServerName $ServerName -OrionHost $config.orionHost -Credential $OrionCredential

    $markdown = ($header + $body) -join "`n"

    if (-not $OutputPath) {
        $OutputPath = Join-Path $env:TEMP ("infra-snapshot-{0}-{1}.md" -f $ServerName, (Get-Date -Format 'yyyyMMdd-HHmm'))
    }

    Set-Content -Path $OutputPath -Value $markdown -Encoding UTF8
    return $OutputPath
}

Export-ModuleMember -Function Get-SnapshotConfig, New-InfrastructureSnapshotMarkdown
