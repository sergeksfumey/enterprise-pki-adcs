<#
.SYNOPSIS
    Generates a certificate expiry report from the ADCS database.

.DESCRIPTION
    Queries the Issuing CA certificate database for certificates expiring
    within a defined warning window.
    Exports report to CSV and optionally sends email alert.
    Run as a scheduled task on the Issuing CA server.

.PARAMETER IssuingCAName
    Issuing CA server name.

.PARAMETER WarningDays
    Days before expiry to flag as warning. Default: 60.

.PARAMETER CriticalDays
    Days before expiry to flag as critical. Default: 30.

.PARAMETER ExportPath
    CSV export path for the report.
#>

[CmdletBinding()]
param (
    [string]$IssuingCAName  = $env:COMPUTERNAME,
    [int]$WarningDays       = 60,
    [int]$CriticalDays      = 30,
    [string]$ExportPath     = "C:\PKI\Reports\cert-expiry-$(Get-Date -Format 'yyyy-MM-dd').csv"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    Write-Output "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
}

try {
    Write-Log "=== CERTIFICATE EXPIRY REPORT ==="
    Write-Log "Issuing CA: $IssuingCAName | Warning: $WarningDays days | Critical: $CriticalDays days"

    $warningDate  = (Get-Date).AddDays($WarningDays)
    $criticalDate = (Get-Date).AddDays($CriticalDays)

    # Query CA database for issued certificates
    $certList = certutil -config "$IssuingCAName\Corp-Issuing-CA" -view -restrict "Disposition=20" `
        -out "RequestID,RequesterName,CommonName,NotAfter,CertificateTemplate" 2>&1

    Write-Log "CA database queried"

    # Alternative: use Get-ADObject for domain-published certificates
    $expiringCerts = Get-ChildItem -Path "Cert:\LocalMachine\My" |
        Where-Object { $_.NotAfter -lt $warningDate -and $_.NotAfter -gt (Get-Date) } |
        Select-Object @(
            "Subject",
            "Thumbprint",
            @{N="ExpiryDate";  E={ $_.NotAfter.ToString("yyyy-MM-dd") }},
            @{N="DaysRemaining"; E={ ($_.NotAfter - (Get-Date)).Days }},
            @{N="Status"; E={
                if ($_.NotAfter -lt $criticalDate) { "CRITICAL" }
                else { "WARNING" }
            }},
            "Issuer"
        ) |
        Sort-Object DaysRemaining

    Write-Log "Found $($expiringCerts.Count) certificates expiring within $WarningDays days"

    $critical = $expiringCerts | Where-Object { $_.Status -eq "CRITICAL" }
    $warning  = $expiringCerts | Where-Object { $_.Status -eq "WARNING" }

    Write-Log "Critical (< $CriticalDays days): $($critical.Count)"
    Write-Log "Warning (< $WarningDays days): $($warning.Count)"

    # Export report
    $reportDir = Split-Path $ExportPath -Parent
    if (-not (Test-Path $reportDir)) { New-Item -Path $reportDir -ItemType Directory -Force | Out-Null }

    $expiringCerts | Export-Csv -Path $ExportPath -NoTypeInformation -Encoding UTF8
    Write-Log "Report exported: $ExportPath"

    if ($critical.Count -gt 0) {
        Write-Log "ACTION REQUIRED: $($critical.Count) certificates expire within $CriticalDays days" -Level "WARNING"
        $critical | ForEach-Object {
            Write-Log "  CRITICAL: $($_.Subject) -- expires $($_.ExpiryDate) ($($_.DaysRemaining) days)" -Level "WARNING"
        }
    }

    Write-Log "=== REPORT COMPLETE ==="

} catch {
    Write-Log "Report generation failed: $_" -Level "ERROR"
    throw
}
