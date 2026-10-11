import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/printer_capabilities.dart';
import '../../domain/models/printer_device.dart';

class PrinterRegistryState {
  const PrinterRegistryState({
    this.discoveredPrinters = const [],
    this.savedPrinters = const [],
    this.selectedPrinter,
    this.isScanning = false,
    this.capabilitiesMap = const {},
  });

  final List<PrinterDevice> discoveredPrinters;
  final List<PrinterDevice> savedPrinters;
  final PrinterDevice? selectedPrinter;
  final bool isScanning;
  final Map<String, PrinterCapabilities> capabilitiesMap;

  PrinterRegistryState copyWith({
    List<PrinterDevice>? discoveredPrinters,
    List<PrinterDevice>? savedPrinters,
    PrinterDevice? selectedPrinter,
    bool? isScanning,
    Map<String, PrinterCapabilities>? capabilitiesMap,
  }) {
    return PrinterRegistryState(
      discoveredPrinters: discoveredPrinters ?? this.discoveredPrinters,
      savedPrinters: savedPrinters ?? this.savedPrinters,
      selectedPrinter: selectedPrinter ?? this.selectedPrinter,
      isScanning: isScanning ?? this.isScanning,
      capabilitiesMap: capabilitiesMap ?? this.capabilitiesMap,
    );
  }
}

class PrinterRegistryNotifier extends Notifier<PrinterRegistryState> {
  static const saveAsPdfPrinter = PrinterDevice(
    id: 'save-as-pdf-virtual',
    name: 'Save as PDF (Download to Device)',
    connectionType: PrinterConnectionType.network,
    host: 'localhost',
    port: 0,
    resourcePath: '/export-pdf',
    isOnline: true,
    isDiscovered: false,
    capabilitiesQueried: true,
  );

  static const testVirtualPrinter = PrinterDevice(
    id: 'virtual-test-printer',
    name: 'Virtual Test Printer (IPP Duplex)',
    connectionType: PrinterConnectionType.network,
    host: '127.0.0.1',
    port: 631,
    resourcePath: '/ipp/print',
    isOnline: true,
    isDiscovered: false,
    capabilitiesQueried: true,
  );

  static const defaultVirtualCapabilities = PrinterCapabilities(
    printerName: 'Virtual Test Printer (IPP Duplex)',
    printerMakeAndModel: 'Generic IPP Everywhere Printer',
    printerState: 'idle',
    supportsColor: true,
    supportsDuplex: true,
    operationsSupported: [0x0002, 0x0005, 0x0006],
    documentFormats: [
      'application/pdf',
      'image/pwg-raster',
      'image/jpeg',
      'image/png'
    ],
    markerSupplies: [
      PrinterSupplyLevel(name: 'Black', colorHex: '#000000', levelPercent: 85),
      PrinterSupplyLevel(name: 'Cyan', colorHex: '#00FFFF', levelPercent: 62),
      PrinterSupplyLevel(
          name: 'Magenta', colorHex: '#FF00FF', levelPercent: 48),
      PrinterSupplyLevel(name: 'Yellow', colorHex: '#FFFF00', levelPercent: 90),
    ],
  );

  @override
  PrinterRegistryState build() {
    return const PrinterRegistryState(
      savedPrinters: [saveAsPdfPrinter, testVirtualPrinter],
      selectedPrinter: saveAsPdfPrinter,
      capabilitiesMap: {
        'virtual-test-printer': defaultVirtualCapabilities,
      },
    );
  }

  void setScanning(bool scanning) {
    state = state.copyWith(isScanning: scanning);
  }

  void addDiscoveredPrinter(PrinterDevice printer) {
    final existing =
        state.discoveredPrinters.indexWhere((p) => p.id == printer.id);
    if (existing >= 0) {
      final updated = List<PrinterDevice>.from(state.discoveredPrinters);
      updated[existing] = printer;
      state = state.copyWith(discoveredPrinters: updated);
    } else {
      state = state.copyWith(
        discoveredPrinters: [...state.discoveredPrinters, printer],
      );
    }
  }

  void savePrinter(PrinterDevice printer) {
    if (!state.savedPrinters.any((p) => p.id == printer.id)) {
      state = state.copyWith(savedPrinters: [...state.savedPrinters, printer]);
    }
  }

  void removeSavedPrinter(String printerId) {
    state = state.copyWith(
      savedPrinters:
          state.savedPrinters.where((p) => p.id != printerId).toList(),
      selectedPrinter:
          state.selectedPrinter?.id == printerId ? null : state.selectedPrinter,
    );
  }

  void selectPrinter(PrinterDevice? printer) {
    state = state.copyWith(selectedPrinter: printer);
  }

  void setPrinterCapabilities(
      String printerId, PrinterCapabilities capabilities) {
    final updated =
        Map<String, PrinterCapabilities>.from(state.capabilitiesMap);
    updated[printerId] = capabilities;
    state = state.copyWith(capabilitiesMap: updated);
  }
}

final printerRegistryProvider =
    NotifierProvider<PrinterRegistryNotifier, PrinterRegistryState>(
  PrinterRegistryNotifier.new,
);
