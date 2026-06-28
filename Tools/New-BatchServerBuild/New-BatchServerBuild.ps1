#requires -Version 5.1
<#
.SYNOPSIS
    Batch server builder - reads CSV and generates per-server build scripts or runs remoting.

.PARAMETER InputCsv
    CSV with server build parameters (see sample-servers.csv).

.PARAMETER OutputDirectory
    Folder for generated scripts.

.PARAMETER ExecuteRemotely
    Use Invoke-Command on build jump host instead of generating scripts only.

.PARAMETER JumpServer
    Remoting target when -ExecuteRemotely is set.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$InputCsv,

    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'output'),

    [switch]$ExecuteRemotely,

    [string]$JumpServer = ''
)

$ErrorActionPreference = 'Stop'
$wizardPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'New-WindowsServer\New-WindowsServer.ps1'

if (-not (Test-Path $InputCsv)) {
    throw "CSV not found: $InputCsv"
}

$rows = Import-Csv -Path $InputCsv
if (-not $rows.Count) {
    throw 'CSV contains no rows.'
}

if (-not (Test-Path $OutputDirectory)) {
    $null = New-Item -ItemType Directory -Path $OutputDirectory -Force
}

function New-SingleBuildScript {
    param($Row, [string]$Folder)

    $null = New-Item -ItemType Directory -Path $Folder -Force
    $features = switch -Regex ([string]$Row.Role) {
        'Domain Controller' { @('AD-Domain-Services', 'DNS') }
        'File Server'       { @('FS-FileServer') }
        'Web Server'        { @('Web-Server', 'Web-Mgmt-Tools') }
        'RDS'               { @('RDS-RD-Server') }
        'SQL Server'        { @('NET-Framework-45-Core') }
        default             { @('NET-Framework-45-Core') }
    }

    $featureList = ($features | ForEach-Object { "'$_'" }) -join ', '
    $apps = [string]$Row.Applications

    $script = @"
# Batch-generated build script for $($Row.ServerName)
`$ErrorActionPreference = 'Stop'
Import-Module VMware.PowerCLI -ErrorAction Stop
Connect-VIServer -Server '$($Row.vCenter)'

`$item = Get-ContentLibraryItem -ContentLibrary '$($Row.ContentLibrary)' -Name '$($Row.Template)'
`$cluster = Get-Cluster '$($Row.Cluster)'
`$vmHost = `$cluster | Get-VMHost | Select-Object -First 1
`$vm = Deploy-VApp -VApp `$item -Name '$($Row.ServerName)' -VMHost `$vmHost.Name -Datastore '$($Row.Datastore)'
Set-VM `$vm -NumCpu $($Row.vCPU) -MemoryGB $($Row.MemoryGB) -Confirm:`$false
Get-HardDisk -VM `$vm | Select-Object -First 1 | Set-HardDisk -CapacityGB $($Row.DiskGB) -Confirm:`$false
Get-NetworkAdapter -VM `$vm | Set-NetworkAdapter -NetworkName '$($Row.Network)' -Confirm:`$false

Install-WindowsFeature -Name @($featureList) -IncludeManagementTools
# Applications: $apps
# Hardening: $($Row.Hardening)
"@

    $scriptPath = Join-Path $Folder 'Deploy-Server.ps1'
    Set-Content -Path $scriptPath -Value $script -Encoding UTF8
    return $scriptPath
}

$generated = @()
foreach ($row in $rows) {
    $folder = Join-Path $OutputDirectory ([string]$row.ServerName)
    $path = New-SingleBuildScript -Row $row -Folder $folder
    $generated += $path
    Write-Host ("Generated: {0}" -f $path) -ForegroundColor Green
}

if ($ExecuteRemotely) {
    if (-not $JumpServer) {
        throw 'Specify -JumpServer when using -ExecuteRemotely.'
    }

    foreach ($path in $generated) {
        Write-Host ("Executing on {0}: {1}" -f $JumpServer, $path) -ForegroundColor Cyan
        Invoke-Command -ComputerName $JumpServer -FilePath $path -ErrorAction Stop
    }
}

Write-Host ("Batch complete. {0} script(s) in {1}" -f $generated.Count, $OutputDirectory) -ForegroundColor Cyan
