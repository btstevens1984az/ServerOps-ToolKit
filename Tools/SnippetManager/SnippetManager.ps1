#requires -Version 5.1
<#
.SYNOPSIS
    Snippet and template picker for common PowerShell patterns.
#>

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
Import-Module (Join-Path $scriptRoot 'src\SnippetStore.psm1') -Force

$catalog = Get-SnippetCatalog
if (-not $catalog.Count) {
    Write-Warning 'No snippets found in snippets folder.'
    exit 1
}

Write-Host "=== PowerShell Snippet Manager ===" -ForegroundColor Cyan
Write-Host ""

$index = 1
$map = @{}
foreach ($item in ($catalog | Sort-Object Category, Name)) {
    Write-Host ("[{0}] {1} ({2})" -f $index, $item.Name, $item.Category)
    $map[[string]$index] = $item.Name
    $index++
}

Write-Host ""
$choice = Read-Host 'Select snippet number (or name prefix)'
$selectedName = $null

if ($map.ContainsKey($choice)) {
    $selectedName = $map[$choice]
}
else {
    $selectedName = ($catalog | Where-Object { $_.Name -like "$choice*" } | Select-Object -First 1).Name
}

if (-not $selectedName) {
    Write-Error 'Invalid selection.'
    exit 1
}

$content = Get-SnippetContent -Name $selectedName
Write-Host ""
Write-Host "--- $selectedName ---" -ForegroundColor Yellow
Write-Host $content
Write-Host ""

$action = Read-Host 'Copy to clipboard? (Y/n)'
if ($action -notmatch '^[Nn]') {
    Copy-SnippetToClipboard -Name $selectedName
    Write-Host 'Copied to clipboard.' -ForegroundColor Green
}

$savePath = Read-Host 'Save to file path (optional)'
if ($savePath) {
    Set-Content -Path $savePath -Value $content -Encoding UTF8
    Write-Host "Saved: $savePath" -ForegroundColor Green
}
