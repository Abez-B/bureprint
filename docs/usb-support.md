# USB / OTG plan

USB support is Android-first and model-dependent.

1. Enumerate devices with Android USB Host API.
2. Request permission through the system permission flow.
3. Identify interfaces/endpoints and supported protocol.
4. Implement IPP-over-USB when available.
5. Add and test specific backends for additional printer languages.
6. Maintain a public matrix of tested printer model, connection, format, and result.

Do not send arbitrary PDF bytes to a USB endpoint and assume it is a print protocol.
