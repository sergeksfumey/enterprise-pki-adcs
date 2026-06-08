# Offline Root CA Activation Runbook

## Purpose

Step-by-step procedure for offline Root CA activation.
This procedure must only be performed by authorised PKI administrators.
A minimum of two administrators must be present during all Root CA activation operations.

## Pre-Activation Checklist

Before activating the Root CA:
- [ ] Change request has been raised and approved
- [ ] Two authorised administrators available for dual-control operation
- [ ] Removable media (USB) available for certificate/CRL transfer
- [ ] Physical access to Root CA storage location authorised
- [ ] Activation log prepared for documentation

## Activation Procedure

1. Retrieve Root CA from secured storage (requires dual authorisation)
2. Connect Root CA to power -- DO NOT connect any network cables
3. Boot the Root CA server
4. Log in with Root CA local administrator account
5. Verify no network connectivity: ipconfig -- all adapters should show no connectivity
6. Insert removable media containing the Issuing CA CSR (or other signed content)

## Signing the Issuing CA Certificate

1. Copy the Issuing CA CSR from removable media to C:\Temp2. Submit the CSR to the Root CA:
   certreq -submit -config "." C:\Temp\IssuingCA.req C:\Temp\IssuingCA.cer
3. Copy the signed certificate to removable media
4. Publish the updated Root CA CRL:
   certutil -crl
5. Copy the Root CA CRL from C:\Windows\System32\CertSrv\CertEnroll\ to removable media

## Post-Operation Shutdown

1. Remove removable media from Root CA
2. Shut down the Root CA server: shutdown /s /t 0
3. Disconnect power
4. Return Root CA to secured storage (dual-control)
5. Document all actions in the activation log with timestamps and administrator signatures

## Emergency Root CA Compromise Response

If Root CA compromise is suspected:
1. Immediately notify CISO and infrastructure management
2. DO NOT activate the Root CA
3. Assess scope of compromise
4. If confirmed -- entire PKI hierarchy must be rebuilt
5. Revoke all certificates under the compromised hierarchy
6. Deploy new PKI hierarchy with new Root CA
7. Reissue all enterprise certificates under new hierarchy
