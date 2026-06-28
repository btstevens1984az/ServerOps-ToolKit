#requires -Version 5.1
<#
.SYNOPSIS
    Personal PowerShell Command Vault - lightweight WPF GUI.
#>

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
Import-Module (Join-Path $scriptRoot 'src\CommandVaultStore.psm1') -Force

$xamlPath = Join-Path $scriptRoot 'ui\CommandVaultWindow.xaml'
[xml]$xaml = Get-Content -Path $xamlPath -Raw -Encoding UTF8
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

function Get-Ctrl { param([string]$Name) $window.FindName($Name) }

$txtSearch      = Get-Ctrl 'txtSearch'
$cboCategory    = Get-Ctrl 'cboCategory'
$chkFavorites   = Get-Ctrl 'chkFavorites'
$btnRefresh     = Get-Ctrl 'btnRefresh'
$lstCommands    = Get-Ctrl 'lstCommands'
$txtSelectedTitle = Get-Ctrl 'txtSelectedTitle'
$txtSelectedTags  = Get-Ctrl 'txtSelectedTags'
$txtCommandBody = Get-Ctrl 'txtCommandBody'
$btnFavorite    = Get-Ctrl 'btnFavorite'
$btnCopy        = Get-Ctrl 'btnCopy'
$btnExecute     = Get-Ctrl 'btnExecute'
$txtStatus      = Get-Ctrl 'txtStatus'
$btnImport      = Get-Ctrl 'btnImport'
$btnExport      = Get-Ctrl 'btnExport'

$script:SelectedEntry = $null

function Set-Status {
    param([string]$Message)
    $txtStatus.Text = $Message
}

function Update-CommandList {
    $category = if ($cboCategory.SelectedItem) { [string]$cboCategory.SelectedItem } else { 'All' }
    $results = Search-CommandVaultEntries `
        -Query $txtSearch.Text `
        -Category $category `
        -FavoritesOnly:($chkFavorites.IsChecked -eq $true)

    $lstCommands.ItemsSource = $null
    $lstCommands.ItemsSource = $results
    Set-Status ("Showing {0} command(s)" -f @($results).Count)
}

function Show-SelectedCommand {
    param($Entry)

    $script:SelectedEntry = $Entry
    if (-not $Entry) {
        $txtSelectedTitle.Text = 'Select a command'
        $txtSelectedTags.Text = ''
        $txtCommandBody.Text = ''
        $btnFavorite.Content = 'Favorite'
        return
    }

    $txtSelectedTitle.Text = $Entry.title
    $tagText = if ($Entry.tags) { 'Tags: ' + ($Entry.tags -join ', ') } else { '' }
    $txtSelectedTags.Text = $tagText
    $txtCommandBody.Text = $Entry.command
    $btnFavorite.Content = if ($Entry.favorite) { 'Unfavorite' } else { 'Favorite' }
}

$cboCategory.ItemsSource = @('All') + (Get-CommandVaultCategories)
$cboCategory.SelectedIndex = 0
$txtSearch.Text = ''

$txtSearch.Add_TextChanged({ Update-CommandList })
$cboCategory.Add_SelectionChanged({ Update-CommandList })
$chkFavorites.Add_Checked({ Update-CommandList })
$chkFavorites.Add_Unchecked({ Update-CommandList })

$btnRefresh.Add_Click({ Update-CommandList })

$lstCommands.Add_SelectionChanged({
    $selected = $lstCommands.SelectedItem
    Show-SelectedCommand -Entry $selected
})

$btnFavorite.Add_Click({
    if (-not $script:SelectedEntry) { return }
    $newFav = -not [bool]$script:SelectedEntry.favorite
    Set-CommandVaultFavorite -Id $script:SelectedEntry.id -Favorite $newFav
    Update-CommandList
    $refreshed = Search-CommandVaultEntries -Query $txtSearch.Text |
        Where-Object { $_.id -eq $script:SelectedEntry.id } |
        Select-Object -First 1
    Show-SelectedCommand -Entry $refreshed
})

$btnCopy.Add_Click({
    if (-not $script:SelectedEntry) { return }
    try {
        Copy-CommandVaultText -Text $script:SelectedEntry.command
        Set-Status 'Command copied to clipboard.'
    }
    catch {
        Set-Status ("Copy failed: {0}" -f $_.Exception.Message)
    }
})

$btnExecute.Add_Click({
    if (-not $script:SelectedEntry) { return }

    $preview = $script:SelectedEntry.command
    if ($preview.Length -gt 120) {
        $preview = $preview.Substring(0, 117) + '...'
    }

    $answer = [System.Windows.MessageBox]::Show(
        "Execute this command in a new PowerShell window?`n`n$preview",
        'Confirm Execute',
        'YesNo',
        'Warning')

    if ($answer -ne 'Yes') { return }

    $encoded = [Convert]::ToBase64String(
        [Text.Encoding]::Unicode.GetBytes($script:SelectedEntry.command))

    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList @('-NoExit', '-EncodedCommand', $encoded) `
        -WorkingDirectory $env:USERPROFILE

    Set-Status 'Launched command in new PowerShell window.'
})

$btnExport.Add_Click({
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = 'JSON files (*.json)|*.json'
    $dialog.FileName = 'command-vault-export.json'
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    try {
        Export-CommandVaultJson -Path $dialog.FileName
        Set-Status ("Exported to {0}" -f $dialog.FileName)
    }
    catch {
        Set-Status ("Export failed: {0}" -f $_.Exception.Message)
    }
})

$btnImport.Add_Click({
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = 'JSON files (*.json)|*.json'
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

    $modeAnswer = [System.Windows.MessageBox]::Show(
        'Merge with existing commands? (No = replace all)',
        'Import Mode',
        'YesNoCancel',
        'Question')

    if ($modeAnswer -eq 'Cancel') { return }
    $mode = if ($modeAnswer -eq 'Yes') { 'Merge' } else { 'Replace' }

    try {
        $count = Import-CommandVaultJson -Path $dialog.FileName -Mode $mode
        Update-CommandList
        Set-Status ("Import complete. {0} command(s) in vault." -f $count)
    }
    catch {
        Set-Status ("Import failed: {0}" -f $_.Exception.Message)
    }
})

Update-CommandList
[void]$window.ShowDialog()
