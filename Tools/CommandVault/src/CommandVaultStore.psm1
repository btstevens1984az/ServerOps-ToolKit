# Command Vault - data persistence and search (no UI)

function Get-CommandVaultCategories {
    return @(
        'Server Build'
        'F5'
        'Storage'
        'Networking'
        'Hardening'
        'Active Directory'
        'Backup/Restore'
    )
}

$Script:CommandVaultCategories = Get-CommandVaultCategories

function Get-CommandVaultDataPath {
    $dir = Join-Path $env:APPDATA 'CommandVault'
    if (-not (Test-Path $dir)) {
        $null = New-Item -ItemType Directory -Path $dir -Force
    }
    return (Join-Path $dir 'commands.json')
}

function Get-CommandVaultDefaultPath {
    return (Join-Path (Split-Path $PSScriptRoot -Parent) 'data\default-commands.json')
}

function Initialize-CommandVaultData {
    $path = Get-CommandVaultDataPath
    if (-not (Test-Path $path)) {
        $default = Get-CommandVaultDefaultPath
        if (Test-Path $default) {
            Copy-Item -Path $default -Destination $path -Force
        }
        else {
            @{
                version  = 1
                commands = @()
            } | ConvertTo-Json -Depth 6 | Set-Content -Path $path -Encoding UTF8
        }
    }
    return $path
}

function Get-CommandVaultEntries {
    $path = Initialize-CommandVaultData
    $raw = Get-Content -Path $path -Raw -Encoding UTF8 | ConvertFrom-Json
    return @($raw.commands)
}

function Save-CommandVaultEntries {
    param([Parameter(Mandatory)][array]$Commands)

    $path = Get-CommandVaultDataPath
    @{
        version  = 1
        commands = $Commands
    } | ConvertTo-Json -Depth 6 | Set-Content -Path $path -Encoding UTF8
}

function Search-CommandVaultEntries {
    param(
        [string]$Query = '',
        [string]$Category = 'All',
        [switch]$FavoritesOnly
    )

    $entries = Get-CommandVaultEntries
    $q = $Query.Trim().ToLower()

    $filtered = foreach ($entry in $entries) {
        if ($Category -ne 'All' -and $entry.category -ne $Category) { continue }
        if ($FavoritesOnly -and -not $entry.favorite) { continue }

        if ($q) {
            $haystack = @(
                $entry.title
                $entry.category
                $entry.command
                ($entry.tags -join ' ')
            ) -join ' '
            if ($haystack.ToLower() -notlike "*$q*") { continue }
        }

        $entry
    }

    return @($filtered | Sort-Object { -not $_.favorite }, title)
}

function Export-CommandVaultJson {
    param([Parameter(Mandatory)][string]$Path)

    $entries = Get-CommandVaultEntries
    @{
        version  = 1
        exported = (Get-Date).ToString('o')
        commands = $entries
    } | ConvertTo-Json -Depth 6 | Set-Content -Path $Path -Encoding UTF8
}

function Import-CommandVaultJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('Merge', 'Replace')]
        [string]$Mode = 'Merge'
    )

    if (-not (Test-Path $Path)) {
        throw "Import file not found: $Path"
    }

    $imported = Get-Content -Path $Path -Raw -Encoding UTF8 | ConvertFrom-Json
    $incoming = @($imported.commands)

    if ($Mode -eq 'Replace') {
        Save-CommandVaultEntries -Commands $incoming
        return $incoming.Count
    }

    $existing = @(Get-CommandVaultEntries)
    $byId = @{}
    foreach ($item in $existing) { $byId[$item.id] = $item }
    foreach ($item in $incoming) { $byId[$item.id] = $item }

    $merged = @($byId.Values)
    Save-CommandVaultEntries -Commands $merged
    return $merged.Count
}

function Set-CommandVaultFavorite {
    param(
        [Parameter(Mandatory)][string]$Id,
        [bool]$Favorite
    )

    $entries = @(Get-CommandVaultEntries)
    foreach ($entry in $entries) {
        if ($entry.id -eq $Id) {
            $entry.favorite = $Favorite
            break
        }
    }
    Save-CommandVaultEntries -Commands $entries
}

function Copy-CommandVaultText {
    param([Parameter(Mandatory)][string]$Text)

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Clipboard]::SetText($Text)
}

Export-ModuleMember -Function @(
    'Get-CommandVaultCategories'
    'Get-CommandVaultEntries'
    'Save-CommandVaultEntries'
    'Search-CommandVaultEntries'
    'Export-CommandVaultJson'
    'Import-CommandVaultJson'
    'Set-CommandVaultFavorite'
    'Copy-CommandVaultText'
)
