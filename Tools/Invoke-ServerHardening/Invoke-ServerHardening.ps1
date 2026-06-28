#requires -Version 5.1
<#
.SYNOPSIS
    Apply CIS-style hardening and generate HTML compliance report (idempotent).

.PARAMETER Level
    Level1 or Level2 baseline.

.PARAMETER ComputerName
    Local or remote server (uses Invoke-Command when remote).

.PARAMETER ReportPath
    Output HTML report path.

.PARAMETER WhatIf
    Show remediations without applying.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('Level1', 'Level2')]
    [string]$Level = 'Level1',

    [string]$ComputerName = $env:COMPUTERNAME,

    [string]$ReportPath = '',

    [switch]$CheckOnly,

    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$moduleRoot = $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'src\HardeningBaseline.psm1') -Force

if (-not $ReportPath) {
    $ReportPath = Join-Path $moduleRoot ("hardening-report-{0}-{1}.html" -f $ComputerName, (Get-Date -Format 'yyyyMMdd-HHmm'))
}

$isLocal = ($ComputerName -in @('localhost', '127.0.0.1', $env:COMPUTERNAME))

if ($isLocal) {
    if (-not $CheckOnly) {
        $applied = Invoke-HardeningRemediation -Level $Level -WhatIf:$WhatIf
        if ($applied) {
            Write-Host ("Remediations: {0}" -f @($applied).Count)
            $applied | Format-Table -AutoSize
        }
    }

    $results = Test-HardeningCompliance -Level $Level
    Export-HardeningHtmlReport -Results $results -Path $ReportPath -ComputerName $ComputerName -Level $Level
}
else {
    $scriptBlock = {
        param($Level, $CheckOnly, $WhatIf, $ModulePath)
        Import-Module $ModulePath -Force
        if (-not $CheckOnly) {
            Invoke-HardeningRemediation -Level $Level -WhatIf:$WhatIf | Out-Null
        }
        Test-HardeningCompliance -Level $Level
    }

    $results = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList @(
        $Level, [bool]$CheckOnly, [bool]$WhatIf, (Join-Path $moduleRoot 'src\HardeningBaseline.psm1')
    )

    Export-HardeningHtmlReport -Results $results -Path $ReportPath -ComputerName $ComputerName -Level $Level
}

$pass = @($results | Where-Object Passed).Count
$total = @($results).Count
Write-Host ("Compliance: {0}/{1} passed. Report: {2}" -f $pass, $total, $ReportPath) -ForegroundColor Green

if ($pass -lt $total) { exit 1 }
exit 0
