#requires -Version 5.1
<#
.SYNOPSIS
    Build living infrastructure documentation for a server or cluster.

.PARAMETER ServerName
    Hostname to document.

.PARAMETER OutputPath
    Markdown output file path.

.PARAMETER InfobloxCredential
    Optional credential for Infoblox WAPI.

.PARAMETER OrionCredential
    Optional credential for SolarWinds SWIS.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ServerName,

    [string]$OutputPath = '',

    [pscredential]$InfobloxCredential,

    [pscredential]$OrionCredential
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'src\SnapshotOps.psm1') -Force

$path = New-InfrastructureSnapshotMarkdown `
    -ServerName $ServerName `
    -OutputPath $OutputPath `
    -InfobloxCredential $InfobloxCredential `
    -OrionCredential $OrionCredential

Write-Host "Snapshot written: $path" -ForegroundColor Green
