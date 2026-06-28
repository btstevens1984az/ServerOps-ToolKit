#requires -Version 5.1
<#
.SYNOPSIS
    Certificate expiration and patching status dashboard (HTML report).

.PARAMETER SharePointSiteUrl
    SharePoint site hosting cert inventory list.

.PARAMETER CertListName
    SharePoint list name for internal certificates.

.PARAMETER WsusServer
    WSUS server for patch summary.

.PARAMETER SccmSiteCode
    SCCM site code (optional).

.PARAMETER DaysUntilCertAlert
    Alert threshold for cert expiry.
#>

[CmdletBinding()]
param(
    [string]$SharePointSiteUrl = 'https://sharepoint.example.com/sites/Infra',

    [string]$CertListName = 'Internal Certificates',

    [string]$WsusServer = 'wsus.example.local',

    [string]$SccmSiteCode = '',

    [int]$DaysUntilCertAlert = 60,

    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'

if (-not $OutputPath) {
    $OutputPath = Join-Path $PSScriptRoot ("cert-patch-dashboard-{0}.html" -f (Get-Date -Format 'yyyyMMdd-HHmm'))
}

function Get-SharePointCertRecords {
    param([string]$SiteUrl, [string]$ListName)

    $results = @()
    try {
        if (Get-Command Get-PnPListItem -ErrorAction SilentlyContinue) {
            Connect-PnPOnline -Url $SiteUrl -Interactive -ErrorAction Stop
            $items = Get-PnPListItem -List $ListName -PageSize 500
            foreach ($item in $items) {
                $expiry = [datetime]$item.FieldValues.ExpirationDate
                $daysLeft = ($expiry - (Get-Date)).Days
                $results += [pscustomobject]@{
                    Subject    = [string]$item.FieldValues.Title
                    Expires    = $expiry
                    DaysLeft   = $daysLeft
                    Owner      = [string]$item.FieldValues.Owner
                    Alert      = ($daysLeft -le $DaysUntilCertAlert)
                }
            }
        }
        else {
            Write-Warning 'PnP.PowerShell not available. Using sample cert data.'
            $results = @(
                [pscustomobject]@{ Subject = 'wildcard.example.com'; Expires = (Get-Date).AddDays(45); DaysLeft = 45; Owner = 'NetOps'; Alert = $true }
                [pscustomobject]@{ Subject = 'api.internal.local'; Expires = (Get-Date).AddDays(120); DaysLeft = 120; Owner = 'AppTeam'; Alert = $false }
            )
        }
    }
    catch {
        Write-Warning "SharePoint cert query failed: $($_.Exception.Message)"
    }

    return $results
}

function Get-WsusPatchSummary {
    param([string]$Server)

    $summary = [pscustomobject]@{
        Server          = $Server
        ComputersTotal  = 0
        NeedsPatching   = 0
        LastSync        = ''
        Status          = 'Unknown'
    }

    try {
        if (-not $Server) { return $summary }

        $scriptBlock = {
            if (Get-Command Get-WsusServer -ErrorAction SilentlyContinue) {
                $wsus = Get-WsusServer -Name localhost -PortNumber 8530
                $computers = $wsus.GetComputerTargets() | Where-Object { $_.LastSyncTime -gt (Get-Date).AddDays(-30) }
                $needs = @($computers | Where-Object { $_.LastSyncResult -ne 'Succeeded' })
                [pscustomobject]@{
                    ComputersTotal = @($computers).Count
                    NeedsPatching  = @($needs).Count
                    LastSync       = (Get-Date).ToString('yyyy-MM-dd')
                    Status         = 'OK'
                }
            }
        }

        $remote = Invoke-Command -ComputerName $Server -ScriptBlock $scriptBlock -ErrorAction SilentlyContinue
        if ($remote) {
            $summary = [pscustomobject]@{
                Server         = $Server
                ComputersTotal = $remote.ComputersTotal
                NeedsPatching  = $remote.NeedsPatching
                LastSync       = $remote.LastSync
                Status         = $remote.Status
            }
        }
    }
    catch {
        $summary.Status = "Error: $($_.Exception.Message)"
    }

    return $summary
}

function Get-SccmPatchSummary {
    param([string]$SiteCode)

    if (-not $SiteCode) {
        return [pscustomobject]@{ SiteCode = ''; Compliant = 0; NonCompliant = 0; Status = 'Not configured' }
    }

    try {
        if (Get-Module -ListAvailable ConfigurationManager) {
            Import-Module ConfigurationManager -ErrorAction Stop
            $site = Get-PSDrive -PSProvider CMSite -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($site) {
                Set-Location "$($site.Name):"
                $stats = Get-CMComplianceStatus -ErrorAction SilentlyContinue
                return [pscustomobject]@{
                    SiteCode     = $SiteCode
                    Compliant    = @($stats | Where-Object { $_.Status -eq 'Compliant' }).Count
                    NonCompliant = @($stats | Where-Object { $_.Status -ne 'Compliant' }).Count
                    Status       = 'OK'
                }
            }
        }
    }
    catch {
        return [pscustomobject]@{ SiteCode = $SiteCode; Compliant = 0; NonCompliant = 0; Status = $_.Exception.Message }
    }

    return [pscustomobject]@{ SiteCode = $SiteCode; Compliant = 0; NonCompliant = 0; Status = 'Module not loaded' }
}

$certs = Get-SharePointCertRecords -SiteUrl $SharePointSiteUrl -ListName $CertListName
$wsus = Get-WsusPatchSummary -Server $WsusServer
$sccm = Get-SccmPatchSummary -SiteCode $SccmSiteCode

$certRows = ($certs | Sort-Object DaysLeft | ForEach-Object {
    $cls = if ($_.Alert) { 'fail' } else { 'pass' }
    "<tr class='$cls'><td>$($_.Subject)</td><td>$($_.Expires.ToString('yyyy-MM-dd'))</td><td>$($_.DaysLeft)</td><td>$($_.Owner)</td></tr>"
}) -join "`n"

$alertCount = @($certs | Where-Object Alert).Count

$html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8"/>
<title>Certificate and Patching Dashboard</title>
<style>
body { font-family: Segoe UI, sans-serif; margin: 24px; background: #f8fafc; }
.card { background: #fff; border: 1px solid #e2e8f0; border-radius: 8px; padding: 16px; margin-bottom: 16px; }
.pass { background: #f0fdf4; }
.fail { background: #fef2f2; }
table { width: 100%; border-collapse: collapse; }
th, td { border: 1px solid #e2e8f0; padding: 8px; text-align: left; }
th { background: #f1f5f9; }
.metric { font-size: 28px; font-weight: bold; color: #2563eb; }
</style>
</head>
<body>
<h1>Certificate and Patching Dashboard</h1>
<p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>

<div class="card">
<h2>Certificate Alerts (&lt;= $DaysUntilCertAlert days)</h2>
<p class="metric">$alertCount</p>
<table>
<thead><tr><th>Subject</th><th>Expires</th><th>Days Left</th><th>Owner</th></tr></thead>
<tbody>$certRows</tbody>
</table>
</div>

<div class="card">
<h2>WSUS Patch Summary ($($wsus.Server))</h2>
<p>Total synced: $($wsus.ComputersTotal) | Needs attention: $($wsus.NeedsPatching) | Status: $($wsus.Status)</p>
</div>

<div class="card">
<h2>SCCM Compliance ($($sccm.SiteCode))</h2>
<p>Compliant: $($sccm.Compliant) | Non-compliant: $($sccm.NonCompliant) | Status: $($sccm.Status)</p>
</div>
</body>
</html>
"@

Set-Content -Path $OutputPath -Value $html -Encoding UTF8
Write-Host "Dashboard: $OutputPath" -ForegroundColor Green

if ($alertCount -gt 0) {
    Write-Warning "$alertCount certificate(s) expiring within $DaysUntilCertAlert days."
}
