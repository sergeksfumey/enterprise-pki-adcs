<#
.SYNOPSIS
    Installs and configures the Enterprise Issuing Certificate Authority.

.DESCRIPTION
    Installs ADCS Enterprise CA role on a domain-joined server.
    Configures CA policy, CDP and AIA extensions, OCSP, and autoenrollment.
    Requires Root CA certificate imported to server before running.

.PARAMETER CAName
    Issuing CA common name.

.PARAMETER RootCACertPath
    Path to Root CA certificate file (copied from Root CA via removable media).

.PARAMETER CDPUrl
    HTTP URL for CRL distribution point.

.PARAMETER OCSPUrl
    HTTP URL for OCSP Responder.

.NOTES
    Pre-requisites:
    - Windows Server 2019/2022, domain-joined
    - Enterprise Admin or Domain Admin rights
    - Root CA certificate available at RootCACertPath
    - IIS installed for CRL and OCSP hosting
#>

[CmdletBinding()]
param (
    [string]$CAName         = "Corp-Issuing-CA",
    [string]$CACommonName   = "Corporate Issuing Certificate Authority",
    [Parameter(Mandatory)][string]$RootCACertPath,
    [string]$CDPUrl         = "http://pki.corp.local/CertEnroll",
    [string]$OCSPUrl        = "http://pki.corp.local/ocsp",
    [string]$KeyLength      = "2048",
    [string]$HashAlgorithm  = "SHA256",
    [int]$CAValidityYears   = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
}

try {
    Write-Log "=== ISSUING CA INSTALLATION ==="
    Write-Log "CA Name: $CAName | Domain: $env:USERDNSDOMAIN"

    # Verify domain membership
    if (-not (Get-WmiObject Win32_ComputerSystem).PartOfDomain) {
        throw "Server must be domain-joined for Enterprise CA installation"
    }

    # Import Root CA certificate to Trusted Root store
    Write-Log "Importing Root CA certificate"
    certutil -addstore Root $RootCACertPath
    Write-Log "Root CA certificate imported to Trusted Root store"

    # Create CAPolicy.inf
    $caPolicyContent = @"
[Version]
Signature="$Windows NT$"

[Certsrv_Server]
RenewalKeyLength=$KeyLength
RenewalValidityPeriod=Years
RenewalValidityPeriodUnits=$CAValidityYears
CRLPeriod=Weeks
CRLPeriodUnits=1
CRLDeltaPeriod=Days
CRLDeltaPeriodUnits=1
LoadDefaultTemplates=1
AlternateSignatureAlgorithm=0
"@

    $caPolicyContent | Set-Content -Path "C:\Windows\CAPolicy.inf" -Encoding UTF8
    Write-Log "CAPolicy.inf created"

    # Install ADCS role
    Write-Log "Installing ADCS and OCSP roles"
    Install-WindowsFeature -Name ADCS-Cert-Authority, ADCS-Online-Cert -IncludeManagementTools

    # Configure Enterprise Issuing CA
    Write-Log "Configuring Enterprise Issuing CA"
    Install-AdcsCertificationAuthority `
        -CAType EnterpriseSubordinateCA `
        -CACommonName $CACommonName `
        -KeyLength $KeyLength `
        -HashAlgorithmName $HashAlgorithm `
        -Force

    Write-Log "CA installed -- certificate request generated"
    Write-Log "Copy the CSR to the Root CA for signing, then import the signed certificate"

    # Configure CDP extensions
    Write-Log "Configuring CDP and AIA extensions"
    Get-CACRLDistributionPoint | Remove-CACRLDistributionPoint -Force
    Get-CAAuthorityInformationAccess | Remove-CAAuthorityInformationAccess -Force

    # CDP
    Add-CACRLDistributionPoint `
        -Uri "C:\Windows\System32\CertSrv\CertEnroll\<CaName><CRLNameSuffix><DeltaCRLAllowed>.crl" `
        -PublishToServer `
        -PublishDeltaToServer

    Add-CACRLDistributionPoint `
        -Uri "$CDPUrl/<CaName><CRLNameSuffix><DeltaCRLAllowed>.crl" `
        -AddToCertificateCDP `
        -AddToFreshestCrl

    # AIA -- include OCSP
    Add-CAAuthorityInformationAccess `
        -Uri "$CDPUrl/<ServerDNSName>_<CaName><CertificateName>.crt" `
        -AddToCertificateAia

    Add-CAAuthorityInformationAccess `
        -Uri "$OCSPUrl" `
        -AddToCertificateOcsp

    # Set CRL schedule
    certutil -setreg CA\CRLPeriodUnits 1
    certutil -setreg CA\CRLPeriod "Weeks"
    certutil -setreg CA\CRLDeltaPeriodUnits 1
    certutil -setreg CA\CRLDeltaPeriod "Days"

    Restart-Service certsvc
    certutil -crl

    Write-Log "=== ISSUING CA CONFIGURED ==="
    Write-Log "Next: Run Configure-OCSPResponder.ps1 to enable real-time revocation"
    Write-Log "Next: Run New-CertificateTemplate.ps1 to create certificate templates"
    Write-Log "Next: Configure GPO autoenrollment via Group Policy Management Console"

} catch {
    Write-Log "Issuing CA installation failed: $_" -Level "ERROR"
    throw
}
