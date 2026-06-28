#requires -Version 5.1
<#
.SYNOPSIS
    Infra Quick Launcher - console menu or system tray for favorite infra links.

.PARAMETER TrayMode
    Run as system tray icon with context menu (Windows only).
#>

param(
    [switch]$TrayMode
)

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
$configPath = Join-Path $scriptRoot 'config\links.json'

if (-not (Test-Path $configPath)) {
    throw "Config not found: $configPath"
}

$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
$flatLinks = @()
foreach ($group in $config.groups) {
    foreach ($link in $group.links) {
        $flatLinks += [pscustomobject]@{
            Group = $group.name
            Key   = [string]$link.key
            Title = [string]$link.title
            Url   = [string]$link.url
        }
    }
}

function Open-InfraLink {
    param([string]$Url)
    Start-Process $Url
}

function Show-InfraMenu {
    Clear-Host
    Write-Host "=== Infra Quick Launcher ===" -ForegroundColor Cyan
    Write-Host "Press a hotkey or number to open a link. Q to quit.`n"

    foreach ($group in $config.groups) {
        Write-Host $group.name -ForegroundColor Yellow
        foreach ($link in $group.links) {
            Write-Host ("  [{0}] {1}" -f $link.key, $link.title)
        }
        Write-Host ""
    }

    $choice = Read-Host "Selection"
    if ($choice -match '^[Qq]$') { return $false }

    $selected = $flatLinks | Where-Object { $_.Key -eq $choice } | Select-Object -First 1
    if ($selected) {
        Open-InfraLink -Url $selected.Url
        Write-Host ("Opened: {0}" -f $selected.Title) -ForegroundColor Green
    }
    else {
        Write-Warning "Unknown selection: $choice"
    }

    Read-Host "Press Enter to continue"
    return $true
}

if ($TrayMode) {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $icon = [System.Drawing.SystemIcons]::Application
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = $icon
    $notify.Text = 'Infra Launcher'
    $notify.Visible = $true

    $menu = New-Object System.Windows.Forms.ContextMenuStrip
    foreach ($group in $config.groups) {
        $groupItem = $menu.Items.Add($group.name)
        $groupItem.Enabled = $false
        foreach ($link in $group.links) {
            $item = $menu.Items.Add(("  {0}" -f $link.title))
            $localUrl = [string]$link.url
            $item.Add_Click({
                Start-Process $localUrl
            }.GetNewClosure())
        }
        $null = $menu.Items.Add('-')
    }

    $exitItem = $menu.Items.Add('Exit')
    $exitItem.Add_Click({ $notify.Visible = $false; [System.Windows.Forms.Application]::Exit() })

    $notify.ContextMenuStrip = $menu
    $notify.Add_DoubleClick({ Show-InfraMenu | Out-Null })

    [System.Windows.Forms.Application]::Run()
}
else {
    do {
        $continue = Show-InfraMenu
    } while ($continue)
}
