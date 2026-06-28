# Snippet: Error handling with try/catch/finally and exit codes

$ErrorActionPreference = 'Stop'
$exitCode = 0

try {
    # Main logic
    Write-Host 'Running task...'
}
catch [System.UnauthorizedAccessException] {
    Write-Error 'Access denied. Run elevated or check permissions.'
    $exitCode = 403
}
catch {
    Write-Error ("Unhandled error: {0}" -f $_.Exception.Message)
    $exitCode = 1
}
finally {
    if ($exitCode -ne 0) {
        Write-Warning ("Script exiting with code {0}" -f $exitCode)
    }
}

exit $exitCode
