enum PrinterConnectionType { network, usb, operatingSystem }

class PrinterDevice {
  const PrinterDevice({
    required this.id,
    required this.name,
    required this.connectionType,
    this.host,
    this.isOnline = false,
    this.model,
  });

  final String id;
  final String name;
  final PrinterConnectionType connectionType;
  final String? host;
  final bool isOnline;
  final String? model;
}
