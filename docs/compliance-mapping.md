# Compliance Control Mapping

## NIST SP 800-57 (Cryptographic Key Management)

| Requirement | Description | Implementation |
|---|---|---|
| 5.1 | Key generation | RSA 4096 (Root CA) · RSA 2048 (Issuing CA) · SHA-256 |
| 5.2 | Key establishment | Two-tier hierarchy · Issuing CA cert signed by offline Root |
| 5.3 | Key storage | Root CA offline storage · Issuing CA Windows DPAPI |
| 5.5 | Key revocation | OCSP real-time + CRL scheduled revocation |
| 5.6 | Key expiry | Template validity periods · GPO autoenrollment renewal |
| 6.1 | Cryptographic algorithm selection | SHA-256 hashing · RSA 2048+ key lengths |

## CIS Controls v8

| Control | Description | Implementation |
|---|---|---|
| 3.10 | Encrypt sensitive data in transit | Internal TLS via Web Server certificates |
| 5.4 | Restrict administrator privileges | CA role separation · least-privilege admin |
| 6.5 | Require MFA for admin access | Certificate-based admin authentication |
| 8.2 | Collect audit logs | CA audit logging · certificate issuance events |
| 12.8 | Establish secure network segment | PKI server network isolation |
| 16.1 | Establish account inventory | Certificate owner tracking via CA database |

## Zero Trust Architecture (NIST SP 800-207)

| Principle | Description | Implementation |
|---|---|---|
| Verify explicitly | Every access request authenticated | Certificate-based device and user authentication |
| Least privilege access | Minimum required access granted | Template key usage constraints |
| Assume breach | Continuous validation | OCSP real-time revocation checking |
| Strong identity | Cryptographic identity verification | PKI certificates as identity credentials |
