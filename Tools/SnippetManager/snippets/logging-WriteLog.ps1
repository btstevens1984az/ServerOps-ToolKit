# Snippet: Logging pattern with transcript and structured Write-Log

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -Path $script:LogPath -Value $line
    Write-Host $line
}

$script:LogPath = Join-Path $env:TEMP ('ops-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
Start-Transcript -Path ($script:LogPath -replace '\.log$', '.transcript.log') -Append

try {
    Write-Log -Message 'Operation started'
    # Your work here
    Write-Log -Message 'Operation completed'
}
catch {
    Write-Log -Message $_.Exception.Message -Level 'ERROR'
    throw
}
finally {
    Stop-Transcript
}
