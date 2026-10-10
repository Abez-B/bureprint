# BurePrint architecture

## Layers
- Presentation: Flutter screens and navigation.
- Domain: platform-independent printer, capability, settings, and job models.
- Data: fake discovery now; real discovery and storage later.
- Platform adapters: Kotlin Android USB Host and Android printing APIs.
- Protocol adapters: IPP client and future model-specific transports.

## Rules
1. UI code must not implement printer protocols directly.
2. Query printer capabilities before exposing advanced settings.
3. Never assume a printer accepts PDF or a particular raster format.
4. Keep document conversion separate from transport.
5. Report unsupported printers honestly.
