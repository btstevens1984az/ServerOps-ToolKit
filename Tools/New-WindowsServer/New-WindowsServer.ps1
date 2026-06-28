#requires -Version 5.1
<#
.SYNOPSIS
    Interactive Windows Server build wizard for vCenter content library deployments.

.DESCRIPTION
    Collects OS version, role, domain join, hardening, and application choices then
    generates a build script, unattend.xml, and post-configuration checklist.
#>

param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'output')
)

$ErrorActionPreference = 'Stop'

function Read-Choice {
    param(
        [string]$Prompt,
        [string[]]$Options,
        [int]$Default = 0
    )

    Write-Host ""
    Write-Host $Prompt -ForegroundColor Cyan
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $marker = if ($i -eq $Default) { '*' } else { ' ' }
        Write-Host ("  [{0}] {1}" -f $marker, $Options[$i])
    }

    $input = Read-Host "Enter number (default $Default)"
    if ([string]::IsNullOrWhiteSpace($input)) { return $Options[$Default] }

    $index = 0
    if ([int]::TryParse($input, [ref]$index) -and $index -ge 0 -and $index -lt $Options.Count) {
        return $Options[$index]
    }

    Write-Warning "Invalid choice. Using default."
    return $Options[$Default]
}

function Read-YesNo {
    param(
        [string]$Prompt,
        [bool]$Default = $true
    )

    $defaultText = if ($Default) { 'Y/n' } else { 'y/N' }
    $answer = Read-Host "$Prompt ($defaultText)"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer -match '^[Yy]'
}

function Read-Text {
    param(
        [string]$Prompt,
        [string]$Default = ''
    )

    $answer = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $Default }
    return $answer.Trim()
}

Write-Host "=== Windows Server Build Wizard ===" -ForegroundColor Green

$serverName = Read-Text -Prompt "Server name (hostname)" -Default "srv-app-01"
$osVersion = Read-Choice -Prompt "Windows Server version" -Options @(
    '2016 Standard'
    '2019 Standard'
    '2022 Standard'
    '2025 Standard'
) -Default 2

$role = Read-Choice -Prompt "Primary server role" -Options @(
    'Vendor Application Server'
    'Domain Controller'
    'File Server'
    'Web Server (IIS)'
    'RDS Session Host'
    'SQL Server'
    'Generic Member Server'
) -Default 0

$joinDomain = Read-YesNo -Prompt "Join existing Active Directory domain?" -Default $true
$domainName = ''
$ouPath = ''
if ($joinDomain) {
    $defaultDomain = if ($env:USERDNSDOMAIN) { $env:USERDNSDOMAIN } else { 'contoso.local' }
    $domainName = Read-Text -Prompt "Domain FQDN" -Default $defaultDomain
    $ouPath = Read-Text -Prompt "Target OU (optional)" -Default ''
}

$hardening = Read-Choice -Prompt "Hardening level" -Options @(
    'None'
    'CIS Level 1'
    'CIS Level 2'
) -Default 1

$appsInput = Read-Host "Applications (comma-separated, e.g. .NET 4.8, IIS, CrowdStrike)"
$applications = @($appsInput.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })

$vCenter = Read-Text -Prompt "vCenter FQDN" -Default "vcenter.example.local"
$contentLibrary = Read-Text -Prompt "Content library name" -Default "Windows-Server-Templates"
$templateName = Read-Text -Prompt "Template / OVF name" -Default "Win2022-Std-Base"
$datastore = Read-Text -Prompt "Datastore" -Default "vsanDatastore"
$cluster = Read-Text -Prompt "Cluster" -Default "Prod-Cluster"
$network = Read-Text -Prompt "Port group" -Default "VLAN-100-App"

$cpu = Read-Text -Prompt "vCPU count" -Default "4"
$memoryGB = Read-Text -Prompt "Memory GB" -Default "16"
$diskGB = Read-Text -Prompt "OS disk GB" -Default "128"

if (-not (Test-Path $OutputDirectory)) {
    $null = New-Item -ItemType Directory -Path $OutputDirectory -Force
}

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$buildFolder = Join-Path $OutputDirectory ("{0}-{1}" -f $serverName, $stamp)
$null = New-Item -ItemType Directory -Path $buildFolder -Force

$features = switch -Regex ($role) {
    'Domain Controller' { @('AD-Domain-Services', 'DNS', 'RSAT-AD-PowerShell') }
    'File Server'       { @('FS-FileServer', 'FS-SMB1') }
    'Web Server'        { @('Web-Server', 'Web-Mgmt-Tools', 'NET-Framework-45-ASPNET') }
    'RDS Session Host'  { @('RDS-RD-Server', 'Desktop-Experience') }
    'SQL Server'        { @('NET-Framework-45-Core') }
    default             { @('NET-Framework-45-Core') }
}

$unattendPath = Join-Path $buildFolder 'unattend.xml'
$buildScriptPath = Join-Path $buildFolder 'Deploy-Server.ps1'
$postConfigPath = Join-Path $buildFolder 'Post-Config-Tasks.md'

$adminPasswordPlaceholder = '***SET-LOCAL-ADMIN-PASSWORD***'
$domainJoinXml = ''
if ($joinDomain) {
    $domainJoinXml = @"
            <Identification>
                <JoinDomain>$domainName</JoinDomain>
                <MachineObjectOU>$ouPath</MachineObjectOU>
                <Credentials>
                    <Domain>$(($domainName -split '\.')[0])</Domain>
                    <Username>DOMAIN\svc-domainjoin</Username>
                    <Password>
                        <PlainText>true</PlainText>
                        <Value>***DOMAIN-JOIN-PASSWORD***</Value>
                    </Password>
                </Credentials>
            </Identification>
"@
}

$unattend = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <ComputerName>$serverName</ComputerName>
            <TimeZone>Eastern Standard Time</TimeZone>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <UserAccounts>
                <AdministratorPassword>
                    <Value>$adminPasswordPlaceholder</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
            <AutoLogon>
                <Enabled>false</Enabled>
            </AutoLogon>
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>1</ProtectYourPC>
            </OOBE>
        </component>
    </settings>
    <settings pass="offlineServicing">
        <component name="Microsoft-Windows-LUA-Settings" processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <EnableLUA>true</EnableLUA>
        </component>
    </settings>
</unattend>
"@

Set-Content -Path $unattendPath -Value $unattend -Encoding UTF8

$featureList = ($features | ForEach-Object { "'$_'" }) -join ', '
$appComments = ($applications | ForEach-Object { "#   - $_" }) -join "`n"

$buildScript = @"
# Generated by New-WindowsServer.ps1 on $(Get-Date -Format 'yyyy-MM-dd HH:mm')
# Server: $serverName | Role: $role | OS: $osVersion

`$ErrorActionPreference = 'Stop'

# --- vCenter deploy from content library ---
if (-not (Get-Module -ListAvailable VMware.PowerCLI)) {
    throw 'Install-Module VMware.PowerCLI -Scope CurrentUser'
}
Import-Module VMware.PowerCLI -ErrorAction Stop

Connect-VIServer -Server '$vCenter' -ErrorAction Stop

`$libraryItem = Get-ContentLibraryItem -ContentLibrary '$contentLibrary' -Name '$templateName'
if (-not `$libraryItem) { throw "Template '$templateName' not found in library '$contentLibrary'" }

`$vm = Deploy-VApp -VApp `$libraryItem -Name '$serverName' -VMHost (Get-Cluster '$cluster' | Get-VMHost | Select-Object -First 1).Name -Datastore '$datastore'
Set-VM -VM `$vm -NumCpu $cpu -MemoryGB $memoryGB -Confirm:`$false
Get-HardDisk -VM `$vm | Select-Object -First 1 | Set-HardDisk -CapacityGB $diskGB -Confirm:`$false
Get-NetworkAdapter -VM `$vm | Set-NetworkAdapter -NetworkName '$network' -Confirm:`$false

# Attach unattend (customize spec or guest customization as per your standard)
Write-Host 'Deploy complete. Apply guest customization with unattend.xml from this folder.'

# --- Post-deploy configuration (run after first boot) ---
`$features = @($featureList)
Install-WindowsFeature -Name `$features -IncludeManagementTools

$(if ($hardening -ne 'None') { "& '$PSScriptRoot\..\..\Invoke-ServerHardening\Invoke-ServerHardening.ps1' -Level '$($hardening -replace 'CIS ','')' -ComputerName '$serverName'" } else { '# Hardening skipped' })

# Applications
$appComments

Write-Host 'Build script finished.'
"@

Set-Content -Path $buildScriptPath -Value $buildScript -Encoding UTF8

$postConfig = @"
# Post-Configuration Tasks: $serverName

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm')

## Build Summary

| Item | Value |
|------|-------|
| Server | $serverName |
| OS | $osVersion |
| Role | $role |
| Domain Join | $(if ($joinDomain) { $domainName } else { 'Workgroup' }) |
| Hardening | $hardening |
| vCenter | $vCenter |
| Content Library | $contentLibrary |
| Template | $templateName |

## Checklist

- [ ] Verify VM deployed to cluster **$cluster** on datastore **$datastore**
- [ ] Confirm network **$network** and IP/DNS records
- [ ] Apply unattend.xml / customization spec
- [ ] Install Windows features: $($features -join ', ')
- [ ] Install applications: $($applications -join ', ')
- [ ] Run hardening: $hardening
- [ ] Join monitoring (SolarWinds / CrowdStrike)
- [ ] Create handover doc with New-ServerReleaseDoc.ps1
- [ ] Submit change record for production release

## Files in this folder

- Deploy-Server.ps1
- unattend.xml
- Post-Config-Tasks.md
"@

Set-Content -Path $postConfigPath -Value $postConfig -Encoding UTF8

Write-Host ""
Write-Host "Build package created:" -ForegroundColor Green
Write-Host "  $buildFolder"
Write-Host "  - Deploy-Server.ps1"
Write-Host "  - unattend.xml"
Write-Host "  - Post-Config-Tasks.md"
