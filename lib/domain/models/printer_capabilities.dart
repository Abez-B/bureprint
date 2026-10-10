class PrinterCapabilities {
  const PrinterCapabilities({
    this.documentFormats = const [],
    this.paperSizes = const [],
    this.supportsColor = false,
    this.supportsDuplex = false,
    this.resolutionsDpi = const [],
  });

  final List<String> documentFormats;
  final List<String> paperSizes;
  final bool supportsColor;
  final bool supportsDuplex;
  final List<int> resolutionsDpi;
}
