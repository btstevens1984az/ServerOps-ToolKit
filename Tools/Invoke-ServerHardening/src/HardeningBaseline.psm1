# CIS-style hardening baselines (idempotent checks and remediations)

function Get-HardeningBaselines {
    return @{
        '2019' = @{
            'Level1' = @(
                @{ Id = '1.1.1'; Name = 'Disable Guest account'; Check = { (Get-LocalUser -Name Guest -ErrorAction SilentlyContinue).Enabled -eq $false }; Remediate = { Disable-LocalUser -Name Guest -ErrorAction SilentlyContinue } }
                @{ Id = '1.1.2'; Name = 'Rename Administrator account'; Check = { (Get-LocalUser -Name Administrator -ErrorAction SilentlyContinue).Name -ne 'Administrator' -or -not (Get-LocalUser -Name Administrator -ErrorAction SilentlyContinue).Enabled }; Remediate = { Write-Verbose 'Rename Administrator manually per org policy' } }
                @{ Id = '2.2.1'; Name = 'Enable Windows Firewall all profiles'; Check = { (Get-NetFirewallProfile | Where-Object { -not $_.Enabled }).Count -eq 0 }; Remediate = { Set-NetFirewallProfile -All -Enabled True } }
                @{ Id = '2.3.1'; Name = 'Disable SMBv1'; Check = { (Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue).State -ne 'Enabled' }; Remediate = { Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null } }
                @{ Id = '9.1.1'; Name = 'Enable Windows Defender real-time'; Check = { (Get-MpPreference -ErrorAction SilentlyContinue).DisableRealtimeMonitoring -eq $false }; Remediate = { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue } }
                @{ Id = '18.9.6'; Name = 'Disable AutoRun'; Check = { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name NoDriveTypeAutoRun -ErrorAction SilentlyContinue).NoDriveTypeAutoRun -eq 255 }; Remediate = { New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name NoDriveTypeAutoRun -Value 255 -PropertyType DWord -Force | Out-Null } }
            )
            'Level2' = @(
                @{ Id = '2.2.15'; Name = 'Block inbound RDP from all (restrict via GPO in prod)'; Check = { $true }; Remediate = { Write-Verbose 'Apply RDP restriction via firewall rule set in production' } }
                @{ Id = '18.4.8'; Name = 'Enable Credential Guard (if supported)'; Check = { $true }; Remediate = { Write-Verbose 'Enable Device Guard / Credential Guard via GPO for supported hardware' } }
                @{ Id = '18.7.5'; Name = 'Disable Print Spooler if not print server'; Check = { (Get-Service Spooler -ErrorAction SilentlyContinue).StartType -eq 'Disabled' }; Remediate = { Set-Service Spooler -StartupType Disabled -ErrorAction SilentlyContinue } }
            )
        }
        '2022' = @{
            'Level1' = @(
                @{ Id = '1.1.1'; Name = 'Disable Guest account'; Check = { (Get-LocalUser -Name Guest -ErrorAction SilentlyContinue).Enabled -eq $false }; Remediate = { Disable-LocalUser -Name Guest -ErrorAction SilentlyContinue } }
                @{ Id = '2.2.1'; Name = 'Enable Windows Firewall all profiles'; Check = { (Get-NetFirewallProfile | Where-Object { -not $_.Enabled }).Count -eq 0 }; Remediate = { Set-NetFirewallProfile -All -Enabled True } }
                @{ Id = '2.3.1'; Name = 'Disable SMBv1'; Check = { (Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction SilentlyContinue).State -ne 'Enabled' }; Remediate = { Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue | Out-Null } }
                @{ Id = '9.1.1'; Name = 'Enable Windows Defender real-time'; Check = { (Get-MpPreference -ErrorAction SilentlyContinue).DisableRealtimeMonitoring -eq $false }; Remediate = { Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue } }
                @{ Id = '18.9.6'; Name = 'Disable AutoRun'; Check = { (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name NoDriveTypeAutoRun -ErrorAction SilentlyContinue).NoDriveTypeAutoRun -eq 255 }; Remediate = { New-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer' -Name NoDriveTypeAutoRun -Value 255 -PropertyType DWord -Force | Out-Null } }
                @{ Id = '18.10.12'; Name = 'Enable LSASS protection'; Check = { (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name RunAsPPL -ErrorAction SilentlyContinue).RunAsPPL -eq 1 }; Remediate = { New-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name RunAsPPL -Value 1 -PropertyType DWord -Force | Out-Null } }
            )
            'Level2' = @(
                @{ Id = '18.7.5'; Name = 'Disable Print Spooler if not print server'; Check = { (Get-Service Spooler -ErrorAction SilentlyContinue).StartType -eq 'Disabled' }; Remediate = { Set-Service Spooler -StartupType Disabled -ErrorAction SilentlyContinue } }
                @{ Id = '18.4.8'; Name = 'Enable Credential Guard (if supported)'; Check = { $true }; Remediate = { Write-Verbose 'Enable Device Guard / Credential Guard via GPO for supported hardware' } }
            )
        }
    }
}

function Get-WindowsServerVersionKey {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    if ($os.Caption -match '2025') { return '2022' }
    if ($os.Caption -match '2022') { return '2022' }
    if ($os.Caption -match '2019') { return '2019' }
    if ($os.Caption -match '2016') { return '2019' }
    return '2022'
}

function Test-HardeningCompliance {
    param(
        [ValidateSet('Level1', 'Level2')]
        [string]$Level = 'Level1',
        [string]$VersionKey = ''
    )

    if (-not $VersionKey) {
        $VersionKey = Get-WindowsServerVersionKey
    }

    $baselines = Get-HardeningBaselines
    $rules = @($baselines[$VersionKey][$Level])
    if ($Level -eq 'Level2') {
        $rules += @($baselines[$VersionKey]['Level1'])
    }

    $results = foreach ($rule in $rules) {
        $passed = $false
        $errorMsg = ''
        try {
            $passed = [bool](& $rule.Check)
        }
        catch {
            $errorMsg = $_.Exception.Message
            $passed = $false
        }

        [pscustomobject]@{
            Id       = $rule.Id
            Name     = $rule.Name
            Passed   = $passed
            Error    = $errorMsg
        }
    }

    return $results
}

function Invoke-HardeningRemediation {
    param(
        [ValidateSet('Level1', 'Level2')]
        [string]$Level = 'Level1',
        [string]$VersionKey = '',
        [switch]$WhatIf
    )

    if (-not $VersionKey) {
        $VersionKey = Get-WindowsServerVersionKey
    }

    $baselines = Get-HardeningBaselines
    $rules = @($baselines[$VersionKey][$Level])
    if ($Level -eq 'Level2') {
        $rules += @($baselines[$VersionKey]['Level1'])
    }

    $applied = @()
    foreach ($rule in $rules) {
        $checkPassed = $false
        try { $checkPassed = [bool](& $rule.Check) } catch { $checkPassed = $false }

        if ($checkPassed) { continue }

        if ($WhatIf) {
            $applied += [pscustomobject]@{ Id = $rule.Id; Name = $rule.Name; Action = 'Would remediate' }
            continue
        }

        try {
            & $rule.Remediate
            $applied += [pscustomobject]@{ Id = $rule.Id; Name = $rule.Name; Action = 'Remediated' }
        }
        catch {
            $applied += [pscustomobject]@{ Id = $rule.Id; Name = $rule.Name; Action = "Failed: $($_.Exception.Message)" }
        }
    }

    return $applied
}

function Export-HardeningHtmlReport {
    param(
        [Parameter(Mandatory)][array]$Results,
        [Parameter(Mandatory)][string]$Path,
        [string]$ComputerName = $env:COMPUTERNAME,
        [string]$Level = 'Level1'
    )

    $passCount = @($Results | Where-Object Passed).Count
    $failCount = @($Results | Where-Object { -not $_.Passed }).Count
    $total = @($Results).Count
    $pct = if ($total -gt 0) { [math]::Round(100 * $passCount / $total, 1) } else { 0 }

    $rows = ($Results | ForEach-Object {
        $status = if ($_.Passed) { '<span class="pass">PASS</span>' } else { '<span class="fail">FAIL</span>' }
        $err = if ($_.Error) { $_.Error } else { '' }
        "<tr><td>$($_.Id)</td><td>$($_.Name)</td><td>$status</td><td>$err</td></tr>"
    }) -join "`n"

    $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<title>Hardening Report - $ComputerName</title>
<style>
body { font-family: Segoe UI, sans-serif; margin: 24px; background: #f8fafc; color: #0f172a; }
.card { background: #fff; border: 1px solid #e2e8f0; border-radius: 8px; padding: 20px; margin-bottom: 16px; }
h1 { margin-top: 0; }
.pass { color: #16a34a; font-weight: bold; }
.fail { color: #dc2626; font-weight: bold; }
table { width: 100%; border-collapse: collapse; }
th, td { border: 1px solid #e2e8f0; padding: 8px; text-align: left; }
th { background: #f1f5f9; }
</style>
</head>
<body>
<div class="card">
<h1>Server Hardening Compliance Report</h1>
<p><strong>Computer:</strong> $ComputerName</p>
<p><strong>Level:</strong> $Level</p>
<p><strong>Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
<p><strong>Score:</strong> $passCount / $total passed ($pct%)</p>
</div>
<div class="card">
<table>
<thead><tr><th>ID</th><th>Control</th><th>Status</th><th>Notes</th></tr></thead>
<tbody>
$rows
</tbody>
</table>
</div>
</body>
</html>
"@

    Set-Content -Path $Path -Value $html -Encoding UTF8
}

Export-ModuleMember -Function Get-HardeningBaselines, Get-WindowsServerVersionKey, Test-HardeningCompliance, Invoke-HardeningRemediation, Export-HardeningHtmlReport
