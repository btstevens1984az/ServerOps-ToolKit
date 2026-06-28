# Hybrid Infra Console - settings persistence

function Get-InfraConfigPath {
    $configDir = Join-Path $env:APPDATA 'HybridInfraConsole'
    if (-not (Test-Path $configDir)) {
        $null = New-Item -ItemType Directory -Path $configDir -Force
    }
    return (Join-Path $configDir 'settings.json')
}

function Get-InfraDefaultSettings {
    [pscustomobject]@{
        defaultDomain        = if ($env:USERDNSDOMAIN) { $env:USERDNSDOMAIN.ToLower() } else { 'contoso.local' }
        vCenters             = @()
        snapshotWarningDays  = 7
        staleComputerDays    = 90
        aadConnectServer     = ''
        darkTheme            = $false
    }
}

function Get-InfraSettings {
    $path = Get-InfraConfigPath

    if (-not (Test-Path $path)) {
        $example = Join-Path (Split-Path $PSScriptRoot -Parent) 'config\settings.json.example'
        if (Test-Path $example) {
            Copy-Item -Path $example -Destination $path -Force
        }
        else {
            $defaults = Get-InfraDefaultSettings
            $defaults | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding UTF8
        }
    }

    $raw = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
    return $raw
}

function Save-InfraSettings {
    param([Parameter(Mandatory)][psobject]$Settings)

    $path = Get-InfraConfigPath
    $Settings | ConvertTo-Json -Depth 5 | Set-Content -Path $path -Encoding UTF8
}

function Get-VcenterCredential {
    param([string]$CredentialTarget)

    if ([string]::IsNullOrWhiteSpace($CredentialTarget)) {
        return $null
    }

    # Optional: Install-Module CredentialManager for stored creds
    if (Get-Command Get-StoredCredential -ErrorAction SilentlyContinue) {
        return Get-StoredCredential -Target $CredentialTarget -ErrorAction SilentlyContinue
    }

    return $null
}

Export-ModuleMember -Function Get-InfraSettings, Save-InfraSettings, Get-InfraConfigPath, Get-VcenterCredential
