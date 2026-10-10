# Protocol implementation plan

## First target: IPP
Implement discovery and IPP attributes, then Get-Printer-Attributes and Print-Job / Create-Job + Send-Document as appropriate. Negotiate document formats from printer-reported capabilities.

## Discovery
Use mDNS/DNS-SD to discover advertised IPP services. Discovery is a hint, not proof that printing will work. Support manual IP/hostname entry too.

## Security
Validate addresses, set timeouts and size limits, handle TLS deliberately, and avoid sending documents to untrusted endpoints without user intent.
