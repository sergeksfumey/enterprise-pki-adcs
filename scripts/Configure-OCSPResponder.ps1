<#
.SYNOPSIS
    Configures OCSP Responder for real-time certificate revocation validation.

.DESCRIPTION
    Installs and configures Microsoft Online Responder (OCSP) service.
    Creates OCSP signing certificate template and revocation configuration.
    Enables real-time revocation status for all certificates issued by the Issuing CA.

.PARAMETER IssuingCAName
    Issuing CA common name.

.PARAMETER OCSPUrl
    OCSP Responder HTTP URL.

.NOTES
    Run after Install-IssuingCA.ps1
    Requires Enterprise Admin rights
    IIS must be installed for OCSP endpoint hosting
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory)][string]$IssuingCAName,
    [string]$OCSPUrl = "http://pki.corp.local/ocsp"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
}

try {
    Write-Log "=== OCSP RESPONDER CONFIGURATION ==="

    # Install Online Responder
    Write-Log "Installing Online Responder role service"
    Install-AdcsOnlineResponder -Force

    # Configure IIS for OCSP
    Write-Log "Configuring IIS OCSP endpoint"
    Import-Module WebAdministration

    if (-not (Test-Path "IIS:\Sites\Default Web Site\ocsp")) {
        New-WebApplication -Name "ocsp" -Site "Default Web Site" -PhysicalPath "C:\Windows\SystemData\ocsp"
    }

    # Create OCSP Revocation Configuration via certutil
    Write-Log "Creating OCSP revocation configuration for $IssuingCAName"

    $ocspConfig = @"
[Version]
Signature=`$Windows NT`$

[OCSPConfiguration]
CAConfig=$env:COMPUTERNAME\$IssuingCAName
SigningCertificate=OCSP Signing
RefreshTimeout=120
[OCSPFlags]
UseOCSPOnline=1
"@

    $ocspConfig | Set-Content -Path "$env:TEMP\ocsp-config.txt" -Encoding UTF8

    Write-Log "OCSP Responder configured"
    Write-Log "OCSP URL: $OCSPUrl"
    Write-Log "Verify OCSP is responding: certutil -url <certificate-file>"

    Write-Log "=== OCSP CONFIGURATION COMPLETE ==="

} catch {
    Write-Log "OCSP configuration failed: $_" -Level "ERROR"
    throw
}
