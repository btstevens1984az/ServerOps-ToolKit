#requires -Version 5.1
<#
.SYNOPSIS
    Hybrid Infra Console - PowerShell WPF launcher.

.DESCRIPTION
    Loads MainWindow.xaml, imports ServerOpsToolkit.psm1, and wires UI events.
    Remote work runs on a background runspace so the UI stays responsive.
#>

$ErrorActionPreference = 'Stop'
$scriptRoot = $PSScriptRoot
$script:StartupWarnings = @()

function Add-StartupWarning {
    param([string]$Message)
    $script:StartupWarnings += $Message
    Write-Warning $Message
}

# --- Load dependencies ---
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

foreach ($moduleName in @('ServerOpsToolkit', 'ConfigStore', 'VsphereOps', 'ActiveDirectoryOps')) {
    $modulePath = Join-Path $scriptRoot "src\$moduleName.psm1"
    try {
        Import-Module $modulePath -Force -ErrorAction Stop
    }
    catch {
        Add-StartupWarning "Module '$moduleName' did not load: $($_.Exception.Message)"
    }
}

$xamlPath = Join-Path $scriptRoot 'ui\MainWindow.xaml'
if (-not (Test-Path $xamlPath)) {
    throw "UI file not found: $xamlPath"
}

[xml]$xaml = Get-Content -Path $xamlPath -Raw -Encoding UTF8
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# --- Resolve named controls ---
function Get-Ctrl {
    param([string]$Name)
    return $window.FindName($Name)
}

$txtServer          = Get-Ctrl 'txtServer'
$btnConnect         = Get-Ctrl 'btnConnect'
$btnDisconnect      = Get-Ctrl 'btnDisconnect'
$txtStatus          = Get-Ctrl 'txtStatus'
$txtDashboardServer = Get-Ctrl 'txtDashboardServer'
$txtDashboardOs     = Get-Ctrl 'txtDashboardOs'
$txtDashboardUptime = Get-Ctrl 'txtDashboardUptime'
$btnDashHealth      = Get-Ctrl 'btnDashHealth'
$btnDashServices    = Get-Ctrl 'btnDashServices'
$btnDashEvents      = Get-Ctrl 'btnDashEvents'
$btnRefreshHealth   = Get-Ctrl 'btnRefreshHealth'
$txtHealthOs        = Get-Ctrl 'txtHealthOs'
$txtHealthCpu       = Get-Ctrl 'txtHealthCpu'
$txtHealthMemory    = Get-Ctrl 'txtHealthMemory'
$txtHealthUptime    = Get-Ctrl 'txtHealthUptime'
$gridDisks          = Get-Ctrl 'gridDisks'
$txtServiceFilter   = Get-Ctrl 'txtServiceFilter'
$btnLoadServices    = Get-Ctrl 'btnLoadServices'
$btnStartService    = Get-Ctrl 'btnStartService'
$btnStopService     = Get-Ctrl 'btnStopService'
$btnRestartService  = Get-Ctrl 'btnRestartService'
$gridServices       = Get-Ctrl 'gridServices'
$cboLogName         = Get-Ctrl 'cboLogName'
$cboLogLevel        = Get-Ctrl 'cboLogLevel'
$btnLoadEvents      = Get-Ctrl 'btnLoadEvents'
$gridEvents         = Get-Ctrl 'gridEvents'
$txtCommand         = Get-Ctrl 'txtCommand'
$txtCommandOutput   = Get-Ctrl 'txtCommandOutput'
$btnRunCommand      = Get-Ctrl 'btnRunCommand'
$mainTabs           = Get-Ctrl 'mainTabs'
$busyOverlay        = Get-Ctrl 'busyOverlay'
$txtBusyMessage     = Get-Ctrl 'txtBusyMessage'

# VMware Fleet
$txtVmwareVCenters  = Get-Ctrl 'txtVmwareVCenters'
$txtVmwareTotal     = Get-Ctrl 'txtVmwareTotal'
$txtVmwareOn        = Get-Ctrl 'txtVmwareOn'
$txtVmwareOff       = Get-Ctrl 'txtVmwareOff'
$txtVmwareSnaps     = Get-Ctrl 'txtVmwareSnaps'
$txtVmFilter        = Get-Ctrl 'txtVmFilter'
$btnLoadFleet       = Get-Ctrl 'btnLoadFleet'
$btnLoadSnapshots   = Get-Ctrl 'btnLoadSnapshots'
$btnVmPowerOn       = Get-Ctrl 'btnVmPowerOn'
$btnVmPowerOff      = Get-Ctrl 'btnVmPowerOff'
$gridVmware         = Get-Ctrl 'gridVmware'
$txtVmwareHint      = Get-Ctrl 'txtVmwareHint'
$btnExportVmware    = Get-Ctrl 'btnExportVmware'
$txtHeaderTitle     = Get-Ctrl 'txtHeaderTitle'
$txtHeaderSubtitle  = Get-Ctrl 'txtHeaderSubtitle'
$btnThemeToggle     = Get-Ctrl 'btnThemeToggle'
$borderConnBar      = Get-Ctrl 'borderConnBar'
$borderStatusBar    = Get-Ctrl 'borderStatusBar'

# Active Directory
$txtAdDomain        = Get-Ctrl 'txtAdDomain'
$txtAdUserCount     = Get-Ctrl 'txtAdUserCount'
$txtAdLockedCount   = Get-Ctrl 'txtAdLockedCount'
$btnAdRefreshDomain = Get-Ctrl 'btnAdRefreshDomain'
$txtAdSearch        = Get-Ctrl 'txtAdSearch'
$btnAdSearch        = Get-Ctrl 'btnAdSearch'
$btnAdLocked        = Get-Ctrl 'btnAdLocked'
$btnAdUnlock        = Get-Ctrl 'btnAdUnlock'
$btnAdEnable        = Get-Ctrl 'btnAdEnable'
$btnAdDisable       = Get-Ctrl 'btnAdDisable'
$gridAdUsers        = Get-Ctrl 'gridAdUsers'
$gridAdStale        = Get-Ctrl 'gridAdStale'
$gridAdConnectors   = Get-Ctrl 'gridAdConnectors'
$gridAdDCs          = Get-Ctrl 'gridAdDCs'
$txtAdSyncServer    = Get-Ctrl 'txtAdSyncServer'
$txtAdSyncStatus    = Get-Ctrl 'txtAdSyncStatus'
$txtAdSyncLast      = Get-Ctrl 'txtAdSyncLast'
$txtAdSyncDetail    = Get-Ctrl 'txtAdSyncDetail'
$btnAdSyncRefresh   = Get-Ctrl 'btnAdSyncRefresh'
$btnAdStale         = Get-Ctrl 'btnAdStale'
$btnExportAd        = Get-Ctrl 'btnExportAd'

# Settings
$txtNewVCenter      = Get-Ctrl 'txtNewVCenter'
$txtNewVCenterName   = Get-Ctrl 'txtNewVCenterName'
$btnAddVCenter      = Get-Ctrl 'btnAddVCenter'
$btnConnectVCenters = Get-Ctrl 'btnConnectVCenters'
$lstVCenters        = Get-Ctrl 'lstVCenters'
$txtVcenterStatus   = Get-Ctrl 'txtVcenterStatus'
$txtConfigPath      = Get-Ctrl 'txtConfigPath'
$txtAadConnectServer = Get-Ctrl 'txtAadConnectServer'
$btnSaveSettings    = Get-Ctrl 'btnSaveSettings'
$chkDarkTheme       = Get-Ctrl 'chkDarkTheme'

# --- App state ---
$script:ConnectedServer = $null
$script:ModuleRoot = Join-Path $scriptRoot 'src'
$script:InfraSettings = $null
$script:VCenterCredential = $null
$script:OperationInFlight = $false
$script:AdGridView = 'Users'
$script:IsDarkTheme = $false

if (Get-Command Get-InfraSettings -ErrorAction SilentlyContinue) {
    try {
        $script:InfraSettings = Get-InfraSettings
        if ($script:InfraSettings.PSObject.Properties.Name -contains 'darkTheme') {
            $script:IsDarkTheme = [bool]$script:InfraSettings.darkTheme
        }
    }
    catch {
        Add-StartupWarning "Could not read settings: $($_.Exception.Message)"
    }
}

if (-not $script:InfraSettings) {
    $script:InfraSettings = [pscustomobject]@{
        defaultDomain       = 'contoso.local'
        vCenters            = @()
        snapshotWarningDays = 7
        staleComputerDays   = 90
        aadConnectServer    = ''
        darkTheme           = $false
    }
}

$script:RunspacePool = [runspacefactory]::CreateRunspacePool(1, 3)
$script:RunspacePool.Open()

$script:ActionButtons = @(
    $btnConnect, $btnDisconnect, $btnDashHealth, $btnDashServices, $btnDashEvents,
    $btnRefreshHealth, $btnLoadServices, $btnStartService, $btnStopService,
    $btnRestartService, $btnLoadEvents, $btnRunCommand,
    $btnLoadFleet, $btnLoadSnapshots, $btnVmPowerOn, $btnVmPowerOff, $btnExportVmware,
    $btnAdRefreshDomain, $btnAdSearch, $btnAdLocked, $btnAdUnlock, $btnAdEnable, $btnAdDisable,
    $btnAdStale, $btnExportAd, $btnAdSyncRefresh,
    $btnAddVCenter, $btnConnectVCenters, $btnSaveSettings, $btnThemeToggle
)

$script:SecondaryButtons = @(
    $btnDisconnect, $btnDashHealth, $btnDashServices, $btnDashEvents,
    $btnLoadSnapshots, $btnVmPowerOn, $btnLoadServices, $btnStartService,
    $btnRestartService, $btnAdRefreshDomain, $btnAdLocked, $btnAdUnlock, $btnAdEnable,
    $btnAdStale, $btnExportAd, $btnExportVmware, $btnAdSyncRefresh, $btnAddVCenter, $btnThemeToggle
)

$script:DangerButtons = @($btnStopService, $btnVmPowerOff, $btnAdDisable)

$script:PrimaryButtons = @(
    $btnConnect, $btnLoadFleet, $btnRefreshHealth, $btnLoadServices, $btnLoadEvents,
    $btnRunCommand, $btnAdSearch, $btnConnectVCenters, $btnSaveSettings
)

$script:ThemeTextBoxes = @(
    $txtServer, $txtVmFilter, $txtAdSearch, $txtServiceFilter, $txtCommand,
    $txtNewVCenter, $txtNewVCenterName, $txtAadConnectServer
)

$script:ThemeDataGrids = @(
    $gridVmware, $gridAdUsers, $gridAdStale, $gridAdConnectors, $gridAdDCs,
    $gridDisks, $gridServices, $gridEvents
)

function Set-Status {
    param([string]$Message)
    $txtStatus.Text = $Message
}

function Set-UiBusy {
    param(
        [bool]$IsBusy,
        [string]$Message = ''
    )

    foreach ($btn in $script:ActionButtons) {
        $btn.IsEnabled = -not $IsBusy
    }

    $txtServer.IsEnabled = -not $IsBusy

    if (-not $IsBusy -and $null -ne $script:ConnectedServer) {
        $btnDisconnect.IsEnabled = $true
    }

    if ($IsBusy) {
        $busyOverlay.Visibility = 'Visible'
        if ($Message) {
            $txtBusyMessage.Text = $Message
            Set-Status $Message
        }
        [System.Windows.Input.Mouse]::OverrideCursor = [System.Windows.Input.Cursors]::Wait
    }
    else {
        $busyOverlay.Visibility = 'Collapsed'
        [System.Windows.Input.Mouse]::OverrideCursor = $null
    }
}

function Invoke-ServerOpsAsync {
    param(
        [string]$StatusMessage,
        [ValidateSet('Connect', 'Health', 'Services', 'ServiceAction', 'Events', 'Command',
            'VsphereConnect', 'VsphereFleet', 'VsphereSnapshots', 'VspherePower',
            'AdDomainSummary', 'AdSearch', 'AdLocked', 'AdUnlock', 'AdEnable', 'AdDisable',
            'AdStaleComputers', 'AdAadConnectStatus')]
        [string]$Operation,
        [hashtable]$WorkArgs = @{},
        [System.Management.Automation.PSCredential]$Credential = $null,
        [scriptblock]$OnSuccess,
        [scriptblock]$OnError
    )

    if ($script:OperationInFlight) {
        Set-Status 'Please wait for the current operation to finish.'
        return
    }

    $job = @{ Operation = $Operation }
    foreach ($key in $WorkArgs.Keys) {
        $job[$key] = $WorkArgs[$key]
    }
    $jobJson = $job | ConvertTo-Json -Compress

    $script:OperationInFlight = $true
    Set-UiBusy -IsBusy $true -Message $StatusMessage

    $powershell = [powershell]::Create()
    $null = $powershell.AddScript({
        param($ModuleRoot, $JobJson, $Credential)
        $ErrorActionPreference = 'Stop'
        Import-Module (Join-Path $ModuleRoot 'ConfigStore.psm1') -Force | Out-Null
        Import-Module (Join-Path $ModuleRoot 'VsphereOps.psm1') -Force | Out-Null
        Import-Module (Join-Path $ModuleRoot 'ActiveDirectoryOps.psm1') -Force | Out-Null
        Import-Module (Join-Path $ModuleRoot 'ServerOpsToolkit.psm1') -Force | Out-Null

        $job = $JobJson | ConvertFrom-Json

        switch ($job.Operation) {
            'Connect' {
                Connect-ServerOpsTarget -ComputerName $job.Target
            }
            'Health' {
                $health = Get-ServerHealthSnapshot -ComputerName $job.Server
                [pscustomobject]@{
                    ComputerName  = [string]$health.ComputerName
                    OS            = [string]$health.OS
                    Uptime        = [string]$health.Uptime
                    TotalMemoryGB = [double]$health.TotalMemoryGB
                    FreeMemoryGB  = [double]$health.FreeMemoryGB
                    CPU           = [string]$health.CPU
                    LogicalCores  = [int]$health.LogicalCores
                    Disks         = @(
                        foreach ($disk in @($health.Disks)) {
                            [pscustomobject]@{
                                Drive       = [string]$disk.Drive
                                Label       = [string]$disk.Label
                                SizeGB      = [double]$disk.SizeGB
                                FreeGB      = [double]$disk.FreeGB
                                FreePercent = [double]$disk.FreePercent
                                Status      = [string]$disk.Status
                            }
                        }
                    )
                }
            }
            'Services' {
                $filter = if ($job.PSObject.Properties.Name -contains 'Filter') { [string]$job.Filter } else { '' }
                Get-ServerServiceList -ComputerName $job.Server -Filter $filter
            }
            'ServiceAction' {
                $filter = if ($job.PSObject.Properties.Name -contains 'Filter') { [string]$job.Filter } else { '' }
                Set-ServerServiceState -ComputerName $job.Server -ServiceName $job.ServiceName -Action $job.Action
                Get-ServerServiceList -ComputerName $job.Server -Filter $filter
            }
            'Events' {
                Get-ServerEventLogEntries -ComputerName $job.Server -LogName $job.LogName -Level $job.Level -MaxEvents 75
            }
            'Command' {
                Invoke-ServerOpsCommand -ComputerName $job.Server -Command $job.Command
            }
            'VsphereConnect' {
                $settings = Get-InfraSettings
                Connect-VsphereEndpoints -VCenters @($settings.vCenters) -Credential $Credential
            }
            'VsphereFleet' {
                Get-VsphereFleetInventory -Filter $job.Filter
            }
            'VsphereSnapshots' {
                $settings = Get-InfraSettings
                $days = if ($settings.snapshotWarningDays) { [int]$settings.snapshotWarningDays } else { 7 }
                Get-VsphereSnapshotReport -WarningDays $days
            }
            'VspherePower' {
                Set-VsphereVmPowerState -VMName $job.VMName -VCenter $job.VCenter -Action $job.Action
            }
            'AdDomainSummary' {
                Get-AdDomainSummary
            }
            'AdSearch' {
                Search-AdIdentityUser -Query $job.Query
            }
            'AdLocked' {
                Search-AdLockedOutUsers
            }
            'AdUnlock' {
                Unlock-AdIdentityUser -SamAccountName $job.SamAccountName
            }
            'AdEnable' {
                Set-AdUserEnabledState -SamAccountName $job.SamAccountName -Enabled $true
            }
            'AdDisable' {
                Set-AdUserEnabledState -SamAccountName $job.SamAccountName -Enabled $false
            }
            'AdStaleComputers' {
                $settings = Get-InfraSettings
                $days = if ($settings.staleComputerDays) { [int]$settings.staleComputerDays } else { 90 }
                Get-AdStaleComputerAccounts -StaleDays $days
            }
            'AdAadConnectStatus' {
                $server = if ($job.PSObject.Properties.Name -contains 'ConnectServer') { [string]$job.ConnectServer } else { '' }
                Get-AadConnectSyncStatus -ConnectServer $server
            }
            default {
                throw "Unknown operation: $($job.Operation)"
            }
        }
    }).AddArgument($script:ModuleRoot).AddArgument($jobJson).AddArgument($Credential)

    $powershell.RunspacePool = $script:RunspacePool
    $asyncResult = $powershell.BeginInvoke()

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(50)

    $script:AsyncState = @{
        PowerShell = $powershell
        Async      = $asyncResult
        Timer      = $timer
        OnSuccess  = $OnSuccess
        OnError    = $OnError
    }

    $timer.Add_Tick({
        if (-not $script:AsyncState.Async.IsCompleted) {
            return
        }

        $script:AsyncState.Timer.Stop()

        try {
            $result = $script:AsyncState.PowerShell.EndInvoke($script:AsyncState.Async)
            if ($script:AsyncState.PowerShell.HadErrors -and $script:AsyncState.PowerShell.Streams.Error.Count -gt 0) {
                throw $script:AsyncState.PowerShell.Streams.Error[0].Exception
            }

            if ($script:AsyncState.OnSuccess) {
                & $script:AsyncState.OnSuccess $result
            }
        }
        catch {
            $err = $_.Exception
            if ($script:AsyncState.OnError) {
                & $script:AsyncState.OnError $err
            }
            else {
                Set-Status $err.Message
                [System.Windows.MessageBox]::Show(
                    $err.Message,
                    'Error',
                    'OK',
                    'Warning'
                ) | Out-Null
            }
        }
        finally {
            $script:AsyncState.PowerShell.Dispose()
            $script:AsyncState = $null
            $script:OperationInFlight = $false
            Set-UiBusy -IsBusy $false
        }
    })

    $timer.Start()
}

function Assert-Connected {
    if (-not $script:ConnectedServer) {
        throw 'Not connected. Enter a server name and click Connect first.'
    }
    return $script:ConnectedServer
}

function Get-ComboValue {
    param($ComboBox)

    $item = $ComboBox.SelectedItem
    if ($item -is [System.Windows.Controls.ComboBoxItem]) {
        return $item.Content.ToString()
    }
    return $item.ToString()
}

function Get-HealthDiskRows {
    param($Health)

    $disks = $Health.Disks
    if ($null -eq $disks) {
        return @()
    }

    # Runspace serialization unwraps single-element arrays into one object
    if ($disks.PSObject.Properties.Name -contains 'Drive') {
        return @($disks)
    }

    return @($disks)
}

function Set-DataGridItems {
    param(
        $DataGrid,
        $Items
    )

    $rows = New-Object System.Collections.ObjectModel.ObservableCollection[object]

    if ($null -ne $Items) {
        if ($Items -is [System.Array] -or ($Items -is [System.Collections.IList] -and $Items -isnot [string])) {
            foreach ($item in $Items) {
                if ($null -ne $item) {
                    [void]$rows.Add($item)
                }
            }
        }
        else {
            [void]$rows.Add($Items)
        }
    }

    $DataGrid.ItemsSource = $rows
    return $rows
}

function Update-Dashboard {
    param($Info)

    $txtDashboardServer.Text = "Connected to: $($Info.ComputerName)"
    $txtDashboardOs.Text     = $Info.Caption
    $txtDashboardUptime.Text = "Uptime: $(Format-Uptime -Span $Info.Uptime)  |  Version: $($Info.Version)"
}

function Show-HealthData {
    param(
        $Health,
        [string]$Server
    )

    $txtHealthOs.Text      = $Health.OS
    $txtHealthCpu.Text     = "CPU: $($Health.CPU) ($($Health.LogicalCores) logical processors)"
    $txtHealthMemory.Text  = "Memory: $($Health.FreeMemoryGB) GB free of $($Health.TotalMemoryGB) GB"
    $txtHealthUptime.Text  = "Uptime: $($Health.Uptime)"
    Set-DataGridItems -DataGrid $gridDisks -Items (Get-HealthDiskRows $Health) | Out-Null
    Set-Status "Health refreshed for $Server."
}

function Start-HealthRefresh {
    try {
        $server = Assert-Connected
    }
    catch {
        Set-Status $_.Exception.Message
        return
    }

    Invoke-ServerOpsAsync `
        -StatusMessage "Loading health for $server..." `
        -Operation 'Health' `
        -WorkArgs @{ Server = $server } `
        -OnSuccess {
            param($health)
            Show-HealthData -Health $health -Server $health.ComputerName
        }
}

function Start-ServicesLoad {
    try {
        $server = Assert-Connected
    }
    catch {
        Set-Status $_.Exception.Message
        return
    }

    $filter = $txtServiceFilter.Text

    Invoke-ServerOpsAsync `
        -StatusMessage "Loading services on $server..." `
        -Operation 'Services' `
        -WorkArgs @{ Server = $server; Filter = $filter } `
        -OnSuccess {
            param($services)
            $items = Set-DataGridItems -DataGrid $gridServices -Items $services
            Set-Status "Loaded $($items.Count) service(s) on $server."
        }
}

function Start-ServiceAction {
    param([string]$Action)

    try {
        $server = Assert-Connected
    }
    catch {
        Set-Status $_.Exception.Message
        return
    }

    $selected = $gridServices.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show(
            'Select a service in the grid first.',
            'No selection',
            'OK',
            'Information'
        ) | Out-Null
        return
    }

    $serviceName = $selected.Name
    $filter = $txtServiceFilter.Text

    Invoke-ServerOpsAsync `
        -StatusMessage "$Action service $serviceName on $server..." `
        -Operation 'ServiceAction' `
        -WorkArgs @{
            Server      = $server
            ServiceName = $serviceName
            Action      = $Action
            Filter      = $filter
        } `
        -OnSuccess {
            param($services)
            Set-DataGridItems -DataGrid $gridServices -Items $services | Out-Null
            Set-Status "Service $serviceName - $Action completed."
        }
}

function Start-EventsLoad {
    try {
        $server = Assert-Connected
    }
    catch {
        Set-Status $_.Exception.Message
        return
    }

    $logName = Get-ComboValue $cboLogName
    $level   = Get-ComboValue $cboLogLevel

    Invoke-ServerOpsAsync `
        -StatusMessage "Loading event log from $server..." `
        -Operation 'Events' `
        -WorkArgs @{
            Server  = $server
            LogName = $logName
            Level   = $level
        } `
        -OnSuccess {
            param($events)
            $items = Set-DataGridItems -DataGrid $gridEvents -Items $events
            Set-Status "Loaded $($items.Count) event(s) from $logName on $server."
        }
}

function Get-ThemeCardBorders {
    param($Root)

    $script:ThemeCardResults = @()

    function Walk-ThemeNode {
        param($Node)

        if ($null -eq $Node) { return }

        if ($Node -is [System.Windows.Controls.Border]) {
            try {
                if ($Node.Padding.Left -ge 16 -and $Node.CornerRadius.TopLeft -ge 4) {
                    $script:ThemeCardResults += $Node
                }
            }
            catch {
                # Skip borders with unexpected property types
            }
        }

        if ($Node -is [System.Windows.Controls.Panel]) {
            foreach ($child in $Node.Children) {
                Walk-ThemeNode $child
            }
        }
        elseif ($Node -is [System.Windows.Controls.ContentControl] -and $null -ne $Node.Content) {
            if ($Node.Content -is [System.Windows.Controls.Panel]) {
                Walk-ThemeNode $Node.Content
            }
            elseif ($Node.Content -is [System.Windows.Controls.Border]) {
                Walk-ThemeNode $Node.Content
            }
            elseif ($Node.Content -is [System.Windows.UIElement]) {
                Walk-ThemeNode $Node.Content
            }
        }
        elseif ($Node -is [System.Windows.Controls.ScrollViewer]) {
            Walk-ThemeNode $Node.Content
        }
        elseif ($Node -is [System.Windows.Controls.TabControl]) {
            foreach ($item in $Node.Items) {
                if ($item.Content) { Walk-ThemeNode $item.Content }
            }
        }
        elseif ($Node -is [System.Windows.Controls.TabItem]) {
            if ($Node.Content) { Walk-ThemeNode $Node.Content }
        }
    }

    Walk-ThemeNode $Root
    return $script:ThemeCardResults
}

function Update-InfraTheme {
    try {
        $cards = @($borderConnBar)
        try {
            $cards += Get-ThemeCardBorders $window.Content
        }
        catch {
            # Card discovery is optional; named borders still theme correctly
        }

        $themeControls = @{
            HeaderTitle      = $txtHeaderTitle
            HeaderSubtitle   = $txtHeaderSubtitle
            BusyMessage      = $txtBusyMessage
            StatusText       = $txtStatus
            StatusBar        = $borderStatusBar
            BusyOverlay      = $busyOverlay
            CommandOutput    = $txtCommandOutput
            VmwareOn         = $txtVmwareOn
            VmwareOff        = $txtVmwareOff
            VmwareSnaps      = $txtVmwareSnaps
            AdLockedCount    = $txtAdLockedCount
            AdSyncStatus     = $txtAdSyncStatus
            ThemeToggle      = $btnThemeToggle
            PrimaryButtons   = $script:PrimaryButtons
            SecondaryButtons = $script:SecondaryButtons
            DangerButtons    = $script:DangerButtons
            TextBoxes        = $script:ThemeTextBoxes
            DataGrids        = $script:ThemeDataGrids
            Cards            = $cards
        }

        Set-InfraTheme -Window $window -Controls $themeControls -IsDark $script:IsDarkTheme
    }
    catch {
        if ($txtStatus) {
            $txtStatus.Text = "Theme skipped: $($_.Exception.Message)"
        }
    }
}

function Select-MainTab {
    param([string]$Header)

    foreach ($tab in $mainTabs.Items) {
        if ([string]$tab.Header -eq $Header) {
            $mainTabs.SelectedItem = $tab
            return
        }
    }
}

function Set-AdGridView {
    param([ValidateSet('Users', 'Stale', 'Connectors')][string]$View)

    $script:AdGridView = $View
    $gridAdUsers.Visibility = 'Collapsed'
    $gridAdStale.Visibility = 'Collapsed'
    $gridAdConnectors.Visibility = 'Collapsed'

    switch ($View) {
        'Users'      { $gridAdUsers.Visibility = 'Visible' }
        'Stale'      { $gridAdStale.Visibility = 'Visible' }
        'Connectors' { $gridAdConnectors.Visibility = 'Visible' }
    }
}

function Get-ActiveAdExportGrid {
    switch ($script:AdGridView) {
        'Stale'      { return $gridAdStale.ItemsSource }
        'Connectors' { return $gridAdConnectors.ItemsSource }
        default      { return $gridAdUsers.ItemsSource }
    }
}

function Show-AadConnectStatus {
    param($Status)

    $txtAdSyncServer.Text = "Server: $($Status.Server)"
    $sched = if ($Status.SchedulerEnabled) { 'Scheduler ON' } else { 'Scheduler OFF' }
    $cycle = if ($Status.SyncCycleEnabled) { 'Sync cycle ON' } else { 'Sync cycle OFF' }
    $staging = if ($Status.StagingMode) { ' | Staging mode' } else { '' }
    $txtAdSyncStatus.Text = "$sched | $cycle$staging"

    if ($Status.LastSyncTime) {
        $txtAdSyncLast.Text = $Status.LastSyncTime.ToString('g')
        $txtAdSyncDetail.Text = $Status.LastSyncMessage
    }
    else {
        $txtAdSyncLast.Text = 'No recent sync events found'
        $txtAdSyncDetail.Text = 'Check ADSync services on the connect server.'
    }

    if (@($Status.Connectors).Count -gt 0) {
        Set-AdGridView 'Connectors'
        Set-DataGridItems -DataGrid $gridAdConnectors -Items $Status.Connectors | Out-Null
    }

    Set-Status "Azure AD Connect status loaded from $($Status.Server)."
}

function Save-InfraSettingsFromUi {
    $script:InfraSettings.aadConnectServer = $txtAadConnectServer.Text.Trim()
    $script:InfraSettings.darkTheme = [bool]$chkDarkTheme.IsChecked
    Save-InfraSettings -Settings $script:InfraSettings
    Set-Status 'Settings saved.'
}

function Update-VmwareSummary {
    try {
        $summary = Get-VsphereFleetSummary
        $txtVmwareVCenters.Text = [string]$summary.vCenters
        $txtVmwareTotal.Text     = [string]$summary.TotalVMs
        $txtVmwareOn.Text        = [string]$summary.PoweredOn
        $txtVmwareOff.Text       = [string]$summary.PoweredOff
        $txtVmwareSnaps.Text     = [string]$summary.WithSnaps
    }
    catch {
        # PowerCLI may not be connected yet
    }
}

function Show-AdDomainData {
    param($Summary)

    $txtAdDomain.Text      = $Summary.DomainName
    $txtAdUserCount.Text   = [string]$Summary.UserCount
    $txtAdLockedCount.Text = [string]$Summary.LockedOut
    Set-DataGridItems -DataGrid $gridAdDCs -Items $Summary.DomainControllers | Out-Null
    Set-Status "Domain summary loaded for $($Summary.DomainName)."
}

function Get-SelectedAdUser {
    $selected = $gridAdUsers.SelectedItem
    if (-not $selected) {
        throw 'Select a user in the grid first.'
    }
    if ($selected.SamAccountName) {
        return [string]$selected.SamAccountName
    }
    return [string]$selected
}

function Get-SelectedVm {
    $selected = $gridVmware.SelectedItem
    if (-not $selected) {
        throw 'Select a VM in the grid first.'
    }
    return $selected
}

function Refresh-VcenterList {
    $script:InfraSettings = Get-InfraSettings
    $lstVCenters.Items.Clear()
    foreach ($vc in @($script:InfraSettings.vCenters)) {
        $label = if ($vc.Name) { "$($vc.Name) ($($vc.Server))" } else { $vc.Server }
        [void]$lstVCenters.Items.Add($label)
    }
}

function Start-AdDomainRefresh {
    Invoke-ServerOpsAsync `
        -StatusMessage 'Loading Active Directory summary...' `
        -Operation 'AdDomainSummary' `
        -OnSuccess {
            param($summary)
            Show-AdDomainData -Summary $summary
        }
}

function Start-VsphereFleetLoad {
    $filter = $txtVmFilter.Text

    Invoke-ServerOpsAsync `
        -StatusMessage 'Loading VM fleet across vCenters...' `
        -Operation 'VsphereFleet' `
        -WorkArgs @{ Filter = $filter } `
        -OnSuccess {
            param($vms)
            $items = Set-DataGridItems -DataGrid $gridVmware -Items $vms
            Update-VmwareSummary
            Set-Status "Loaded $($items.Count) VM(s) across connected vCenters."
        }
}

function Start-VsphereConnect {
    if (-not $script:VCenterCredential) {
        $script:VCenterCredential = Get-Credential -Message 'Enter vCenter credentials (shared across all vCenters)' -ErrorAction SilentlyContinue
        if (-not $script:VCenterCredential) {
            Set-Status 'vCenter connection cancelled.'
            return
        }
    }

    Invoke-ServerOpsAsync `
        -StatusMessage 'Connecting to vCenters...' `
        -Operation 'VsphereConnect' `
        -Credential $script:VCenterCredential `
        -OnSuccess {
            param($results)
            $connected = @($results | Where-Object { $_.Connected }).Count
            $failed = @($results | Where-Object { -not $_.Connected })
            $msg = "Connected to $connected vCenter(s)."
            if ($failed.Count -gt 0) {
                $msg += ' Failed: ' + (($failed | ForEach-Object { "$($_.Name): $($_.Message)" }) -join '; ')
            }
            $txtVcenterStatus.Text = $msg
            Set-Status $msg
            Update-VmwareSummary
        }
}

# --- Event handlers ---
$btnConnect.Add_Click({
    $target = $txtServer.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($target)) {
        Set-Status 'Enter a server name before connecting.'
        return
    }

    Invoke-ServerOpsAsync `
        -StatusMessage 'Connecting...' `
        -Operation 'Connect' `
        -WorkArgs @{ Target = $target } `
        -OnSuccess {
            param($info)
            $script:ConnectedServer = $info.ComputerName
            Update-Dashboard $info
            $btnDisconnect.IsEnabled = $true
            Set-Status "Connected to $($info.ComputerName)."
            $window.Dispatcher.BeginInvoke(
                [System.Windows.Threading.DispatcherPriority]::ApplicationIdle,
                [action]{ Start-HealthRefresh }
            ) | Out-Null
        } `
        -OnError {
            param($err)
            $script:ConnectedServer = $null
            $btnDisconnect.IsEnabled = $false
            Set-Status $err.Message
            [System.Windows.MessageBox]::Show(
                $err.Message,
                'Connection failed',
                'OK',
                'Warning'
            ) | Out-Null
        }
})

$btnDisconnect.Add_Click({
    if ($script:OperationInFlight) {
        Set-Status 'Please wait for the current operation to finish.'
        return
    }

    $script:ConnectedServer = $null
    $btnDisconnect.IsEnabled = $false
    $txtDashboardServer.Text = 'Not connected'
    $txtDashboardOs.Text = ''
    $txtDashboardUptime.Text = ''
    $gridDisks.ItemsSource = $null
    $gridServices.ItemsSource = $null
    $gridEvents.ItemsSource = $null
    Set-Status 'Disconnected.'
})

$btnDashHealth.Add_Click({ Select-MainTab 'Health'; Start-HealthRefresh })
$btnDashServices.Add_Click({ Select-MainTab 'Services'; Start-ServicesLoad })
$btnDashEvents.Add_Click({ Select-MainTab 'Event Log'; Start-EventsLoad })
$btnRefreshHealth.Add_Click({ Start-HealthRefresh })
$btnLoadServices.Add_Click({ Start-ServicesLoad })
$btnStartService.Add_Click({ Start-ServiceAction 'Start' })
$btnStopService.Add_Click({ Start-ServiceAction 'Stop' })
$btnRestartService.Add_Click({ Start-ServiceAction 'Restart' })
$btnLoadEvents.Add_Click({ Start-EventsLoad })

$btnRunCommand.Add_Click({
    try {
        $server = Assert-Connected
    }
    catch {
        Set-Status $_.Exception.Message
        return
    }

    $command = $txtCommand.Text

    Invoke-ServerOpsAsync `
        -StatusMessage "Running command on $server..." `
        -Operation 'Command' `
        -WorkArgs @{ Server = $server; Command = $command } `
        -OnSuccess {
            param($output)
            $txtCommandOutput.Text = $output
            Set-Status "Command completed on $server."
        } `
        -OnError {
            param($err)
            $txtCommandOutput.Text = $err.Message
            Set-Status $err.Message
        }
})

# VMware Fleet
$btnConnectVCenters.Add_Click({ Start-VsphereConnect })
$btnLoadFleet.Add_Click({ Start-VsphereFleetLoad })

$btnLoadSnapshots.Add_Click({
    Invoke-ServerOpsAsync `
        -StatusMessage 'Auditing snapshots across vCenters...' `
        -Operation 'VsphereSnapshots' `
        -OnSuccess {
            param($snaps)
            $items = Set-DataGridItems -DataGrid $gridVmware -Items $snaps
            $stale = @($snaps | Where-Object { $_.Status -eq 'Stale' }).Count
            $txtVmwareHint.Text = "Snapshot audit: $($items.Count) snapshot(s), $stale stale (older than warning threshold)."
            Set-Status "Snapshot audit complete - $stale stale snapshot(s)."
        }
})

$btnVmPowerOn.Add_Click({
    try {
        $vm = Get-SelectedVm
    }
    catch {
        Set-Status $_.Exception.Message
        return
    }

    Invoke-ServerOpsAsync `
        -StatusMessage "Powering on $($vm.VMName)..." `
        -Operation 'VspherePower' `
        -WorkArgs @{ VMName = $vm.VMName; VCenter = $vm.vCenter; Action = 'Start' } `
        -OnSuccess { Start-VsphereFleetLoad }
})

$btnVmPowerOff.Add_Click({
    try {
        $vm = Get-SelectedVm
    }
    catch {
        Set-Status $_.Exception.Message
        return
    }

    $confirm = [System.Windows.MessageBox]::Show(
        "Power OFF $($vm.VMName) on $($vm.vCenter)?",
        'Confirm power off',
        'YesNo',
        'Warning'
    )
    if ($confirm -ne 'Yes') { return }

    Invoke-ServerOpsAsync `
        -StatusMessage "Powering off $($vm.VMName)..." `
        -Operation 'VspherePower' `
        -WorkArgs @{ VMName = $vm.VMName; VCenter = $vm.vCenter; Action = 'Stop' } `
        -OnSuccess { Start-VsphereFleetLoad }
})

# Active Directory
$btnAdRefreshDomain.Add_Click({ Start-AdDomainRefresh })
$btnAdSearch.Add_Click({
    $query = $txtAdSearch.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($query)) {
        Set-Status 'Enter a name, SAM account, UPN, or email to search.'
        return
    }

    Invoke-ServerOpsAsync `
        -StatusMessage "Searching AD for '$query'..." `
        -Operation 'AdSearch' `
        -WorkArgs @{ Query = $query } `
        -OnSuccess {
            param($users)
            Set-AdGridView 'Users'
            $items = Set-DataGridItems -DataGrid $gridAdUsers -Items $users
            Set-Status "Found $($items.Count) user(s)."
        }
})

$btnAdLocked.Add_Click({
    Invoke-ServerOpsAsync `
        -StatusMessage 'Finding locked-out accounts...' `
        -Operation 'AdLocked' `
        -OnSuccess {
            param($users)
            Set-AdGridView 'Users'
            $items = Set-DataGridItems -DataGrid $gridAdUsers -Items $users
            Set-Status "Found $($items.Count) locked account(s)."
        }
})

$btnAdStale.Add_Click({
    $days = if ($script:InfraSettings.staleComputerDays) { [int]$script:InfraSettings.staleComputerDays } else { 90 }

    Invoke-ServerOpsAsync `
        -StatusMessage "Finding computer accounts stale $days+ days..." `
        -Operation 'AdStaleComputers' `
        -OnSuccess {
            param($computers)
            Set-AdGridView 'Stale'
            $items = Set-DataGridItems -DataGrid $gridAdStale -Items $computers
            Set-Status "Found $($items.Count) stale computer account(s)."
        }
})

$btnAdSyncRefresh.Add_Click({
    $server = $txtAadConnectServer.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($server) -and $script:InfraSettings.aadConnectServer) {
        $server = [string]$script:InfraSettings.aadConnectServer
    }

    Invoke-ServerOpsAsync `
        -StatusMessage 'Loading Azure AD Connect sync status...' `
        -Operation 'AdAadConnectStatus' `
        -WorkArgs @{ ConnectServer = $server } `
        -OnSuccess {
            param($status)
            Show-AadConnectStatus -Status $status
        }
})

$btnExportVmware.Add_Click({
    try {
        $path = Export-InfraGridToCsv -Items $gridVmware.ItemsSource -DefaultFileName "vm-fleet-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
        if ($path) { Set-Status "Exported VM fleet to $path" }
    }
    catch {
        Set-Status $_.Exception.Message
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Export failed', 'OK', 'Warning') | Out-Null
    }
})

$btnExportAd.Add_Click({
    try {
        $items = Get-ActiveAdExportGrid
        $label = switch ($script:AdGridView) {
            'Stale'      { 'stale-computers' }
            'Connectors' { 'aad-connect-connectors' }
            default      { 'ad-users' }
        }
        $path = Export-InfraGridToCsv -Items $items -DefaultFileName "$label-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
        if ($path) { Set-Status "Exported AD data to $path" }
    }
    catch {
        Set-Status $_.Exception.Message
        [System.Windows.MessageBox]::Show($_.Exception.Message, 'Export failed', 'OK', 'Warning') | Out-Null
    }
})

$btnAdUnlock.Add_Click({
    try {
        $sam = Get-SelectedAdUser
    }
    catch {
        Set-Status $_.Exception.Message
        return
    }

    Invoke-ServerOpsAsync `
        -StatusMessage "Unlocking $sam..." `
        -Operation 'AdUnlock' `
        -WorkArgs @{ SamAccountName = $sam } `
        -OnSuccess {
            Set-Status "Unlocked $sam."
            Start-AdDomainRefresh
        }
})

$btnAdEnable.Add_Click({
    try {
        $sam = Get-SelectedAdUser
    }
    catch {
        Set-Status $_.Exception.Message
        return
    }

    Invoke-ServerOpsAsync `
        -StatusMessage "Enabling $sam..." `
        -Operation 'AdEnable' `
        -WorkArgs @{ SamAccountName = $sam } `
        -OnSuccess { Set-Status "Enabled $sam." }
})

$btnAdDisable.Add_Click({
    try {
        $sam = Get-SelectedAdUser
    }
    catch {
        Set-Status $_.Exception.Message
        return
    }

    $confirm = [System.Windows.MessageBox]::Show(
        "Disable account $sam?",
        'Confirm disable',
        'YesNo',
        'Warning'
    )
    if ($confirm -ne 'Yes') { return }

    Invoke-ServerOpsAsync `
        -StatusMessage "Disabling $sam..." `
        -Operation 'AdDisable' `
        -WorkArgs @{ SamAccountName = $sam } `
        -OnSuccess { Set-Status "Disabled $sam." }
})

# Settings
$btnAddVCenter.Add_Click({
    $server = $txtNewVCenter.Text.Trim()
    $name = $txtNewVCenterName.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($server)) {
        Set-Status 'Enter a vCenter FQDN.'
        return
    }
    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = $server
    }

    $list = @($script:InfraSettings.vCenters)
    $list += [pscustomobject]@{
        Name                 = $name
        Server               = $server
        UseCredentialManager = $false
        CredentialTarget     = ''
    }
    $script:InfraSettings.vCenters = $list
    Save-InfraSettings -Settings $script:InfraSettings
    Refresh-VcenterList
    $txtNewVCenter.Text = ''
    $txtNewVCenterName.Text = ''
    Set-Status "Added vCenter $name."
})

$btnSaveSettings.Add_Click({
    Save-InfraSettingsFromUi
    if ([bool]$chkDarkTheme.IsChecked -ne $script:IsDarkTheme) {
        $script:IsDarkTheme = [bool]$chkDarkTheme.IsChecked
        Update-InfraTheme
    }
})

$btnThemeToggle.Add_Click({
    $script:IsDarkTheme = -not $script:IsDarkTheme
    $chkDarkTheme.IsChecked = $script:IsDarkTheme
    $script:InfraSettings.darkTheme = $script:IsDarkTheme
    Save-InfraSettings -Settings $script:InfraSettings
    Update-InfraTheme
    Set-Status $(if ($script:IsDarkTheme) { 'Dark theme enabled.' } else { 'Light theme enabled.' })
})

$window.Add_Closed({
    Disconnect-VsphereSessions
    if ($script:RunspacePool) {
        $script:RunspacePool.Close()
        $script:RunspacePool.Dispose()
    }
})

$btnDisconnect.IsEnabled = $false

try {
    Refresh-VcenterList
    if (Get-Command Get-InfraConfigPath -ErrorAction SilentlyContinue) {
        $txtConfigPath.Text = Get-InfraConfigPath
    }
    if ($script:InfraSettings.aadConnectServer) {
        $txtAadConnectServer.Text = [string]$script:InfraSettings.aadConnectServer
    }
    $chkDarkTheme.IsChecked = $script:IsDarkTheme
    Set-AdGridView 'Users'
    Update-InfraTheme
    Set-Status 'Ready - connect vCenters on Settings, search AD on Active Directory tab, or connect a server above.'
}
catch {
    Add-StartupWarning "Startup: $($_.Exception.Message)"
    try {
        Set-Status "Started with errors: $($_.Exception.Message)"
    }
    catch {
        # Status bar not available yet
    }
}

if ($script:StartupWarnings.Count -gt 0) {
    $warningText = ($script:StartupWarnings -join [Environment]::NewLine)
    try {
        Set-Status 'Started with warnings - some features may be unavailable.'
    }
    catch { }

    [System.Windows.MessageBox]::Show(
        "Hybrid Infra Console opened with warnings.`n`nSome features may not work until these are resolved:`n`n$warningText",
        'Startup warnings',
        'OK',
        'Warning'
    ) | Out-Null
}

# --- Show window (always, even if startup had warnings) ---
$null = $window.ShowDialog()
