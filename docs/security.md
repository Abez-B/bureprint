# Security and privacy notes

- Local-first document handling is the default goal.
- Do not log document contents or credentials.
- Restrict temporary-file lifetime and clean up after use.
- Validate printer addresses and cap document/job sizes.
- Treat printer discovery results as untrusted network input.
- Use encrypted connections when supported; make insecure fallback explicit.
- No telemetry should be added without clear disclosure and opt-in.
