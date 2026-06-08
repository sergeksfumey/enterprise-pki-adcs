<#
.SYNOPSIS
    Installs and configures the offline Root Certificate Authority.

.DESCRIPTION
    Installs ADCS Root CA role on an air-gapped, non-domain-joined server.
    Configures CA policy, CDP and AIA extensions, and CRL publication.
    Run on the dedicated offline Root CA server.

.NOTES
    CRITICAL: Run on an air-gapped server with NO network connectivity.
    Server must NOT be domain-joined.
    After running: take server offline immediately.
    Store Root CA certificate and CRL on removable media for Issuing CA signing.

    Pre-requisites:
    - Windows Server 2019/2022
    - No network adapters connected
    - Local administrator access
#>

[CmdletBinding()]
param (
    [string]$CAName            = "Corp-Root-CA",
    [string]$CACommonName      = "Corporate Root Certificate Authority",
    [string]$KeyLength         = "4096",
    [string]$HashAlgorithm     = "SHA256",
    [int]$CAValidityYears      = 20,
    [string]$CRLPublishPath    = "C:\Windows\System32\CertSrv\CertEnroll",
    [string]$CDPUrl            = "http://pki.corp.local/CertEnroll"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
}

try {
    Write-Log "=== ROOT CA INSTALLATION ==="
    Write-Log "CA Name: $CAName | Key Length: $KeyLength | Validity: $CAValidityYears years"
    Write-Log "CRITICAL: Verify server is air-gapped before proceeding"

    # Create CAPolicy.inf
    $caPolicyContent = @"
[Version]
Signature="$Windows NT$"

[PolicyStatementExtension]
Policies=InternalPolicy

[InternalPolicy]
OID=1.2.3.4.1455.67.89.5
Notice="Corporate Internal Use Only"

[Certsrv_Server]
RenewalKeyLength=$KeyLength
RenewalValidityPeriod=Years
RenewalValidityPeriodUnits=$CAValidityYears
CRLPeriod=Weeks
CRLPeriodUnits=26
CRLDeltaPeriod=Days
CRLDeltaPeriodUnits=0
LoadDefaultTemplates=0
AlternateSignatureAlgorithm=0

[CRLDistributionPoint]
Empty=True

[AuthorityInformationAccess]
Empty=True
"@

    $caPolicyContent | Set-Content -Path "C:\Windows\CAPolicy.inf" -Encoding UTF8
    Write-Log "CAPolicy.inf created"

    # Install ADCS role
    Write-Log "Installing ADCS role"
    Install-WindowsFeature -Name ADCS-Cert-Authority -IncludeManagementTools

    # Configure Root CA
    Write-Log "Configuring Root CA"
    Install-AdcsCertificationAuthority `
        -CAType StandaloneRootCA `
        -CACommonName $CACommonName `
        -KeyLength $KeyLength `
        -HashAlgorithmName $HashAlgorithm `
        -ValidityPeriod Years `
        -ValidityPeriodUnits $CAValidityYears `
        -Force

    # Configure CRL and AIA extensions
    Write-Log "Configuring CDP and AIA extensions"

    # Remove default CDP and AIA
    Get-CACRLDistributionPoint | Remove-CACRLDistributionPoint -Force
    Get-CAAuthorityInformationAccess | Remove-CAAuthorityInformationAccess -Force

    # Add CDP
    Add-CACRLDistributionPoint `
        -Uri "C:\Windows\System32\CertSrv\CertEnroll\<CaName><CRLNameSuffix><DeltaCRLAllowed>.crl" `
        -PublishToServer `
        -PublishDeltaToServer

    Add-CACRLDistributionPoint `
        -Uri "$CDPUrl/<CaName><CRLNameSuffix><DeltaCRLAllowed>.crl" `
        -AddToCertificateCDP `
        -AddToFreshestCrl

    # Configure CRL publication schedule
    certutil -setreg CA\CRLPeriodUnits 26
    certutil -setreg CA\CRLPeriod "Weeks"
    certutil -setreg CA\CRLDeltaPeriodUnits 0
    certutil -setreg CA\CRLDeltaPeriod "Days"

    Restart-Service certsvc

    # Publish CRL
    certutil -crl

    Write-Log "Root CA installation complete"
    Write-Log "=== NEXT STEPS ==="
    Write-Log "1. Copy Root CA certificate from $CRLPublishPath to removable media"
    Write-Log "2. Copy Root CA CRL from $CRLPublishPath to removable media"
    Write-Log "3. Take this server OFFLINE IMMEDIATELY"
    Write-Log "4. Store server in physically secured location"
    Write-Log "5. Transfer Root CA certificate to Issuing CA server via removable media"

} catch {
    Write-Log "Root CA installation failed: $_" -Level "ERROR"
    throw
}
