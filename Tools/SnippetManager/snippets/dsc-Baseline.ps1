# Snippet: DSC configuration basics (push mode)

Configuration ServerBaseline {
    param(
        [string[]]$NodeName = 'localhost'
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node $NodeName {
        WindowsFeature WebServer {
            Name   = 'Web-Server'
            Ensure = 'Present'
        }

        Registry DisableGuest {
            Key       = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
            ValueName = 'EnableLUA'
            ValueData = '1'
            ValueType = 'DWord'
            Ensure    = 'Present'
        }
    }
}

ServerBaseline -OutputPath "$env:TEMP\DscConfig"
Start-DscConfiguration -Path "$env:TEMP\DscConfig" -Wait -Verbose -Force
