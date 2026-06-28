# Snippet: Credential management with Secret Server hook

Import-Module (Join-Path $PSScriptRoot '..\src\SnippetStore.psm1') -Force -ErrorAction SilentlyContinue

param(
    [int]$SecretId = 12345,
    [string]$Target = 'server01.example.local'
)

$cred = Get-SecretServerCredential -SecretId $SecretId

$sessionOption = New-CimSessionOption -Protocol Dcom
$session = New-CimSession -ComputerName $Target -Credential $cred -SessionOption $sessionOption

try {
    Get-CimInstance -CimSession $session -ClassName Win32_OperatingSystem |
        Select-Object CSName, Caption, Version
}
finally {
    if ($session) { Remove-CimSession $session }
}
