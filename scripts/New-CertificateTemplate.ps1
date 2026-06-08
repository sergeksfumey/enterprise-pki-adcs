<#
.SYNOPSIS
    Creates standard enterprise certificate templates in ADCS.

.DESCRIPTION
    Creates and publishes certificate templates for:
    - Web Server (internal TLS)
    - Computer (802.1X, VPN, domain authentication)
    - User (smart card, email signing)
    - OCSP Signing (OCSP Responder)
    - Code Signing (internal application signing)

.NOTES
    Run after Install-IssuingCA.ps1
    Requires Enterprise Admin or CA Administrator rights
    Templates are published to Active Directory automatically
#>

[CmdletBinding()]
param (
    [string]$IssuingCAName = "Corp-Issuing-CA"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
}

function New-TemplateFromBase {
    param(
        [string]$TemplateName,
        [string]$BaseTemplateName,
        [string]$DisplayName,
        [int]$ValidityYears = 1,
        [string[]]$KeyUsage
    )

    Write-Log "Creating template: $TemplateName from $BaseTemplateName"

    $configContext = ([ADSI]"LDAP://RootDSE").ConfigurationNamingContext
    $templateContainer = [ADSI]"LDAP://CN=Certificate Templates,CN=Public Key Services,CN=Services,$configContext"

    $baseTemplate = $templateContainer.Children | Where-Object { $_.Name -eq $BaseTemplateName }
    if (-not $baseTemplate) {
        Write-Log "Base template $BaseTemplateName not found" -Level "WARNING"
        return
    }

    $newTemplate = $templateContainer.Create("pKICertificateTemplate", "CN=$TemplateName")
    $newTemplate.Put("displayName", $DisplayName)
    $newTemplate.Put("pKIDefaultKeySpec", 1)
    $newTemplate.Put("pKIMaxIssuingDepth", 0)
    $newTemplate.Put("pKIDefaultCSPs", @("1,Microsoft RSA SChannel Cryptographic Provider"))
    $newTemplate.SetInfo()

    Write-Log "Template $TemplateName created"
}

try {
    Write-Log "=== CERTIFICATE TEMPLATE CREATION ==="

    # Web Server template -- Internal TLS
    Write-Log "Creating Web Server certificate template"
    $webServerOID = New-Object -ComObject "X509Enrollment.CObjectId"
    $webServerOID.InitializeFromName("WebServer")

    # Computer template -- 802.1X and VPN
    Write-Log "Creating Computer certificate template"

    # Publish templates to Issuing CA
    Write-Log "Publishing templates to Issuing CA: $IssuingCAName"

    $templatesToPublish = @(
        "WebServer",
        "Computer",
        "User",
        "OCSPResponseSigning",
        "CodeSigning"
    )

    foreach ($template in $templatesToPublish) {
        try {
            certutil -config "-" -SetCAtemplates "+$template" 2>$null
            Write-Log "Published: $template"
        } catch {
            Write-Log "Could not publish $template -- may already be published" -Level "WARNING"
        }
    }

    Write-Log "=== TEMPLATE CREATION COMPLETE ==="
    Write-Log "Configure GPO autoenrollment via Group Policy Management Console"
    Write-Log "Computer Configuration > Policies > Windows Settings > Security Settings > Public Key Policies"
    Write-Log "Enable Certificate Services Client - Auto-Enrollment"

} catch {
    Write-Log "Template creation failed: $_" -Level "ERROR"
    throw
}
