# Architecture Notes -- Enterprise PKI Platform

## CA Hierarchy Design

Two-tier hierarchy -- industry standard for enterprise PKI:
- Tier 1: Offline Root CA -- trust anchor, air-gapped, non-domain-joined
- Tier 2: Enterprise Issuing CA -- domain-joined, handles all end-entity operations

Three-tier hierarchy (optional for large enterprises):
- Tier 1: Offline Root CA
- Tier 2: Offline Policy CA (defines issuance policies)
- Tier 3: Online Issuing CA(s)
- Not implemented here -- justified only for multi-domain or multi-forest environments

## Root CA Operational Procedures

The Root CA is activated ONLY for:
1. Initial PKI deployment (signing Issuing CA certificate)
2. Issuing CA certificate renewal (every 10 years)
3. Emergency CA replacement (Issuing CA compromise)

Activation procedure:
1. Retrieve Root CA from physically secured storage
2. Connect to power -- NO network connection permitted
3. Perform required operation (sign CSR, publish CRL)
4. Copy outputs to removable media
5. Return Root CA to offline state immediately
6. Return to secured storage

## Certificate Template Design

Key parameters per template:

Web Server:
- Key: RSA 2048 / SHA-256
- Validity: 2 years
- SAN: DNS names supplied in request
- Key usage: Digital Signature, Key Encipherment
- EKU: Server Authentication

Computer:
- Key: RSA 2048 / SHA-256
- Validity: 1 year
- Subject: Built from Active Directory (CN=computer$)
- Key usage: Digital Signature, Key Encipherment
- EKU: Client Authentication, Server Authentication
- Autoenrollment: enabled

User:
- Key: RSA 2048 / SHA-256
- Validity: 1 year
- Subject: Built from Active Directory (UPN)
- Key usage: Digital Signature, Key Encipherment
- EKU: Client Authentication, Email Protection
- Autoenrollment: enabled

## GPO Autoenrollment Configuration

Computer Configuration:
- Path: Computer Configuration > Policies > Windows Settings > Security Settings > Public Key Policies
- Setting: Certificate Services Client - Auto-Enrollment
- Enable: Renew expired certificates, update pending certificates, remove revoked certificates

User Configuration:
- Path: User Configuration > Policies > Windows Settings > Security Settings > Public Key Policies
- Setting: Certificate Services Client - Auto-Enrollment
- Enable: Renew expired certificates, update pending certificates

## CRL and OCSP Configuration

CRL schedule:
- Base CRL: Published weekly (Sunday 02:00 UTC)
- Delta CRL: Published daily (every 24 hours)
- Validity: Base CRL valid 2 weeks, Delta CRL valid 48 hours

OCSP:
- Response validity: 24 hours
- OCSP signing certificate: 1-year validity, auto-renewed via autoenrollment
- Monitoring: Alert on OCSP response failure

## PKI Health Monitoring

Key metrics to monitor:
- CRL publication success (daily)
- OCSP responder availability (continuous)
- Certificate expiry (60-day and 30-day warnings)
- Issuing CA service health (continuous)
- Failed certificate requests (daily review)

Tools:
- Get-CertificateExpiryReport.ps1 -- scheduled daily
- PKIView.msc -- visual PKI health assessment
- certutil -url -- OCSP and CRL URL validation
