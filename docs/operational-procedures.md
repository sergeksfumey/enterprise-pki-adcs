# PKI Operational Procedures

## Routine Operations

### Daily
- Verify CRL publication succeeded (certutil -CRL on Issuing CA)
- Check OCSP Responder availability: certutil -url http://pki.corp.local/ocsp
- Review failed certificate requests in CA management console
- Check CA event log for errors (Event Viewer > Application and Services Logs > Certificate Services)

### Weekly
- Run Get-CertificateExpiryReport.ps1 -- review 60-day expiry warnings
- Verify Delta CRL published successfully
- Review certificate issuance statistics (volume by template)

### Monthly
- Review CA audit log for anomalous issuance patterns
- Verify OCSP signing certificate has > 60 days validity remaining
- Check Issuing CA certificate validity (should be > 1 year remaining)
- Test certificate revocation end-to-end: issue test cert, revoke, verify OCSP response

### Annual
- Full PKI health review -- PKIView.msc assessment
- Cryptographic algorithm review against current NIST guidance
- Review and update certificate template validity periods if required
- Test offline Root CA activation procedure (documented simulation only)

## Certificate Revocation Procedure

When a certificate must be revoked immediately:
1. Open Certification Authority console on Issuing CA
2. Navigate to Issued Certificates
3. Right-click target certificate > All Tasks > Revoke Certificate
4. Select revocation reason (Key Compromise, CA Compromise, Affiliation Changed, etc.)
5. Confirm revocation
6. Publish CRL immediately: certutil -CRL
7. Verify OCSP shows Revoked status: certutil -url <certificate-file>
8. Document revocation in incident record

## Issuing CA Certificate Renewal (every 10 years)

1. Schedule offline Root CA activation window (4-hour window minimum)
2. Generate new CSR on Issuing CA: certutil -renewCert ReuseKeys
3. Copy CSR to removable media
4. Activate offline Root CA (follow offline Root CA runbook)
5. Sign Issuing CA CSR on Root CA
6. Copy signed certificate to removable media
7. Return Root CA to offline state immediately
8. Import signed certificate to Issuing CA: certutil -installcert
9. Restart Certificate Services: Restart-Service certsvc
10. Publish new Issuing CA certificate to AD: certutil -dspublish
11. Verify PKI health: PKIView.msc
