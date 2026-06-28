# Shared theme helpers for Hybrid Infra Console

$Script:Theme = @{
    Primary = '#2563EB'
    Success = '#16A34A'
    Warning = '#CA8A04'
    Danger  = '#DC2626'
    Muted   = '#64748B'
    Surface = '#F8FAFC'
    Border  = '#E2E8F0'
}

$Script:LightPalette = @{
    WindowBg         = '#F1F5F9'
    CardBg           = '#FFFFFF'
    CardBorder       = '#E2E8F0'
    TextPrimary      = '#0F172A'
    TextMuted        = '#64748B'
    PrimaryBtnBg     = '#2563EB'
    PrimaryBtnFg     = '#FFFFFF'
    SecondaryBtnBg   = '#E2E8F0'
    SecondaryBtnFg   = '#0F172A'
    DangerBtnBg      = '#FEE2E2'
    DangerBtnFg      = '#B91C1C'
    StatusBarBg      = '#FFFFFF'
    StatusBarBorder  = '#E2E8F0'
    GridBg           = '#FFFFFF'
    GridBorder       = '#E2E8F0'
    InputBg          = '#FFFFFF'
    InputFg          = '#0F172A'
    InputBorder      = '#CBD5E1'
    TabBg            = 'Transparent'
    OverlayBg        = '#B0F1F5F9'
    ConsoleBg        = '#0F172A'
    ConsoleFg        = '#E2E8F0'
    SuccessText      = '#16A34A'
    DangerText       = '#DC2626'
    WarningText      = '#CA8A04'
}

$Script:DarkPalette = @{
    WindowBg         = '#0B1120'
    CardBg           = '#151F32'
    CardBorder       = '#243049'
    TextPrimary      = '#E2E8F0'
    TextMuted        = '#94A3B8'
    PrimaryBtnBg     = '#3B82F6'
    PrimaryBtnFg     = '#FFFFFF'
    SecondaryBtnBg   = '#243049'
    SecondaryBtnFg   = '#E2E8F0'
    DangerBtnBg      = '#451A1A'
    DangerBtnFg      = '#FCA5A5'
    StatusBarBg      = '#151F32'
    StatusBarBorder  = '#243049'
    GridBg           = '#111827'
    GridBorder       = '#243049'
    InputBg          = '#111827'
    InputFg          = '#E2E8F0'
    InputBorder      = '#334155'
    TabBg            = 'Transparent'
    OverlayBg        = '#CC0B1120'
    ConsoleBg        = '#020617'
    ConsoleFg        = '#CBD5E1'
    SuccessText      = '#4ADE80'
    DangerText       = '#F87171'
    WarningText      = '#FBBF24'
}

function Get-DiskStatusBrush {
    param([double]$FreePercent)

    switch ($FreePercent) {
        { $_ -ge 20 } { return 'Green' }
        { $_ -ge 10 } { return 'Goldenrod' }
        default       { return 'Red' }
    }
}

function Format-Uptime {
    param([TimeSpan]$Span)

    if ($Span.TotalDays -ge 1) {
        return ('{0}d {1}h' -f [int]$Span.TotalDays, $Span.Hours)
    }
    if ($Span.TotalHours -ge 1) {
        return ('{0}h {1}m' -f [int]$Span.TotalHours, $Span.Minutes)
    }
    return ('{0}m' -f [int]$Span.TotalMinutes)
}

function Test-ServerConnection {
    param(
        [Parameter(Mandatory)]
        [string]$ComputerName
    )

    $param = @{ ClassName = 'Win32_OperatingSystem'; ErrorAction = 'Stop' }
    if ($ComputerName -notin @('localhost', '127.0.0.1', $env:COMPUTERNAME)) {
        $param['ComputerName'] = $ComputerName
    }

    $null = Get-CimInstance @param
    return $true
}

function Convert-HexToBrush {
    param([string]$Hex)

    $hex = $Hex.TrimStart('#')
    if ($hex.Length -eq 6) {
        $r = [Convert]::ToByte($hex.Substring(0, 2), 16)
        $g = [Convert]::ToByte($hex.Substring(2, 2), 16)
        $b = [Convert]::ToByte($hex.Substring(4, 2), 16)
        return [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromRgb($r, $g, $b))
    }
    return [System.Windows.Media.Brushes]::Transparent
}

function Set-InfraButtonStyle {
    param(
        $Button,
        [string]$Background,
        [string]$Foreground
    )

    if (-not $Button) { return }
    $Button.Background = Convert-HexToBrush $Background
    $Button.Foreground = Convert-HexToBrush $Foreground
}

function Set-InfraDataGridTheme {
    param(
        $DataGrid,
        $Palette
    )

    if (-not $DataGrid) { return }
    $DataGrid.Background = Convert-HexToBrush $Palette.GridBg
    $DataGrid.BorderBrush = Convert-HexToBrush $Palette.GridBorder
    $DataGrid.Foreground = Convert-HexToBrush $Palette.TextPrimary
}

function Set-InfraTextBoxTheme {
    param(
        $TextBox,
        $Palette
    )

    if (-not $TextBox) { return }
    $TextBox.Background = Convert-HexToBrush $Palette.InputBg
    $TextBox.Foreground = Convert-HexToBrush $Palette.InputFg
    $TextBox.BorderBrush = Convert-HexToBrush $Palette.InputBorder
}

function Update-InfraTextBlocks {
    param(
        $Node,
        $PrimaryBrush,
        $MutedBrush
    )

    if ($Node -is [System.Windows.Controls.TextBlock]) {
        $weight = $Node.FontWeight.ToString()
        if ($weight -in @('SemiBold', 'Bold') -or $Node.FontSize -ge 15) {
            if ($Node.Name -notin @('txtVmwareOn', 'txtAdLockedCount', 'txtVmwareSnaps')) {
                $Node.Foreground = $PrimaryBrush
            }
        }
        elseif ($Node.FontSize -le 13) {
            $Node.Foreground = $MutedBrush
        }
    }

    if ($Node -is [System.Windows.Controls.Panel]) {
        foreach ($child in $Node.Children) {
            Update-InfraTextBlocks -Node $child -PrimaryBrush $PrimaryBrush -MutedBrush $MutedBrush
        }
    }
    elseif ($Node -is [System.Windows.Controls.ContentControl] -and $null -ne $Node.Content) {
        if ($Node.Content -is [System.Windows.Controls.Panel]) {
            Update-InfraTextBlocks -Node $Node.Content -PrimaryBrush $PrimaryBrush -MutedBrush $MutedBrush
        }
        elseif ($Node.Content -is [System.Windows.Documents.FlowDocument]) {
            # skip
        }
        elseif ($Node.Content -is [System.Windows.UIElement]) {
            Update-InfraTextBlocks -Node $Node.Content -PrimaryBrush $PrimaryBrush -MutedBrush $MutedBrush
        }
    }
    elseif ($Node -is [System.Windows.Controls.ScrollViewer]) {
        Update-InfraTextBlocks -Node $Node.Content -PrimaryBrush $PrimaryBrush -MutedBrush $MutedBrush
    }
    elseif ($Node -is [System.Windows.Controls.TabControl]) {
        foreach ($item in $Node.Items) {
            if ($item.Content) {
                Update-InfraTextBlocks -Node $item.Content -PrimaryBrush $PrimaryBrush -MutedBrush $MutedBrush
            }
        }
    }
    elseif ($Node -is [System.Windows.Controls.TabItem]) {
        if ($Node.Content) {
            Update-InfraTextBlocks -Node $Node.Content -PrimaryBrush $PrimaryBrush -MutedBrush $MutedBrush
        }
    }
}

function Set-InfraTheme {
    param(
        [Parameter(Mandatory)]$Window,
        [Parameter(Mandatory)]$Controls,
        [bool]$IsDark
    )

    $palette = if ($IsDark) { $Script:DarkPalette } else { $Script:LightPalette }

    $Window.Background = Convert-HexToBrush $palette.WindowBg

    if ($Controls.HeaderTitle) {
        $Controls.HeaderTitle.Foreground = Convert-HexToBrush $palette.TextPrimary
    }
    if ($Controls.HeaderSubtitle) {
        $Controls.HeaderSubtitle.Foreground = Convert-HexToBrush $palette.TextMuted
    }
    if ($Controls.BusyMessage) {
        $Controls.BusyMessage.Foreground = Convert-HexToBrush $palette.TextPrimary
    }
    if ($Controls.StatusText) {
        $Controls.StatusText.Foreground = Convert-HexToBrush $palette.TextMuted
    }
    if ($Controls.StatusBar) {
        $Controls.StatusBar.Background = Convert-HexToBrush $palette.StatusBarBg
        $Controls.StatusBar.BorderBrush = Convert-HexToBrush $palette.StatusBarBorder
    }
    if ($Controls.BusyOverlay) {
        $Controls.BusyOverlay.Background = Convert-HexToBrush $palette.OverlayBg
    }
    if ($Controls.CommandOutput) {
        $Controls.CommandOutput.Background = Convert-HexToBrush $palette.ConsoleBg
        $Controls.CommandOutput.Foreground = Convert-HexToBrush $palette.ConsoleFg
    }
    if ($Controls.VmwareOn) {
        $Controls.VmwareOn.Foreground = Convert-HexToBrush $palette.SuccessText
    }
    if ($Controls.VmwareOff) {
        $Controls.VmwareOff.Foreground = Convert-HexToBrush $palette.TextMuted
    }
    if ($Controls.VmwareSnaps) {
        $Controls.VmwareSnaps.Foreground = Convert-HexToBrush $palette.WarningText
    }
    if ($Controls.AdLockedCount) {
        $Controls.AdLockedCount.Foreground = Convert-HexToBrush $palette.DangerText
    }
    if ($Controls.AdSyncStatus) {
        $Controls.AdSyncStatus.Foreground = Convert-HexToBrush $palette.TextPrimary
    }

    foreach ($card in @($Controls.Cards)) {
        if ($card) {
            $card.Background = Convert-HexToBrush $palette.CardBg
            $card.BorderBrush = Convert-HexToBrush $palette.CardBorder
        }
    }

    foreach ($tb in @($Controls.TextBoxes)) {
        Set-InfraTextBoxTheme -TextBox $tb -Palette $palette
    }

    foreach ($grid in @($Controls.DataGrids)) {
        Set-InfraDataGridTheme -DataGrid $grid -Palette $palette
    }

    if ($Controls.PrimaryButtons) {
        foreach ($btn in @($Controls.PrimaryButtons)) {
            Set-InfraButtonStyle -Button $btn -Background $palette.PrimaryBtnBg -Foreground $palette.PrimaryBtnFg
        }
    }
    elseif ($Controls.BtnPrimary) {
        Set-InfraButtonStyle -Button $Controls.BtnPrimary -Background $palette.PrimaryBtnBg -Foreground $palette.PrimaryBtnFg
    }
    foreach ($btn in @($Controls.SecondaryButtons)) {
        Set-InfraButtonStyle -Button $btn -Background $palette.SecondaryBtnBg -Foreground $palette.SecondaryBtnFg
    }
    foreach ($btn in @($Controls.DangerButtons)) {
        Set-InfraButtonStyle -Button $btn -Background $palette.DangerBtnBg -Foreground $palette.DangerBtnFg
    }

    if ($Controls.ThemeToggle) {
        $Controls.ThemeToggle.Content = if ($IsDark) { 'Light mode' } else { 'Dark mode' }
    }

    Update-InfraTextBlocks -Node $Window.Content `
        -PrimaryBrush (Convert-HexToBrush $palette.TextPrimary) `
        -MutedBrush (Convert-HexToBrush $palette.TextMuted)

    return $palette
}

function Export-InfraGridToCsv {
    param(
        [Parameter(Mandatory)]$Items,
        [Parameter(Mandatory)][string]$DefaultFileName
    )

    if (-not $Items -or @($Items).Count -eq 0) {
        throw 'Nothing to export. Load data into the grid first.'
    }

    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $dialog.Filter = 'CSV files (*.csv)|*.csv'
    $dialog.FileName = $DefaultFileName
    $dialog.InitialDirectory = [Environment]::GetFolderPath('Desktop')

    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        return $null
    }

    @($Items) | Export-Csv -Path $dialog.FileName -NoTypeInformation -Encoding UTF8
    return $dialog.FileName
}
