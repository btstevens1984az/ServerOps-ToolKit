# PowerShell snippet and template library

function Get-SnippetRoot {
    return (Join-Path (Split-Path $PSScriptRoot -Parent) 'snippets')
}

function Get-SnippetCatalog {
    $root = Get-SnippetRoot
    $files = Get-ChildItem -Path $root -Filter '*.ps1' -File -ErrorAction SilentlyContinue
    return @($files | ForEach-Object {
        $name = $_.BaseName
        $category = ($name -split '-')[0]
        [pscustomobject]@{
            Name     = $name
            Category = $category
            Path     = $_.FullName
        }
    })
}

function Get-SnippetContent {
    param([Parameter(Mandatory)][string]$Name)

    $path = Join-Path (Get-SnippetRoot) ("{0}.ps1" -f $Name)
    if (-not (Test-Path $path)) {
        throw "Snippet not found: $Name"
    }
    return Get-Content -Path $path -Raw -Encoding UTF8
}

function Copy-SnippetToClipboard {
    param([Parameter(Mandatory)][string]$Name)

    $content = Get-SnippetContent -Name $Name
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Clipboard]::SetText($content)
}

function Get-SecretServerCredential {
    param(
        [Parameter(Mandatory)][int]$SecretId,
        [string]$SecretServerUrl = 'https://secretserver.example.local/SecretServer'
    )

    if (-not (Get-Module -ListAvailable -Name SecretManagement)) {
        Write-Warning 'SecretManagement module not installed. Returning prompt-based credential.'
        return Get-Credential -Message "Secret Server secret $SecretId (manual entry)"
    }

    # Placeholder for Thycotic Secret Server REST / PowerShell module integration
    Write-Verbose "Retrieve secret $SecretId from $SecretServerUrl via your org Secret Server module."
    return Get-Credential -Message "Secret Server secret $SecretId"
}

Export-ModuleMember -Function Get-SnippetCatalog, Get-SnippetContent, Copy-SnippetToClipboard, Get-SecretServerCredential
