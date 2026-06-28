# Snippet: Register a scheduled task (run as SYSTEM or specified user)

param(
    [string]$TaskName = 'Infra-Nightly-Check',
    [string]$ScriptPath = 'C:\Scripts\Nightly-Check.ps1',
    [string]$RunAsUser = 'SYSTEM'
)

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""

$trigger = New-ScheduledTaskTrigger -Daily -At '02:00'

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -StartWhenAvailable -RunOnlyIfNetworkAvailable

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
    -Settings $settings -User $RunAsUser -RunLevel Highest -Force

Write-Host "Scheduled task '$TaskName' registered."
