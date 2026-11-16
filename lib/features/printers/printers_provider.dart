import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/local_storage_service.dart';
import '../../data/ipp/ipp_client.dart';
import '../../domain/models/printer_capabilities.dart';
import '../../domain/models/printer_device.dart';
import '../../platform/network/nsd_discovery_bridge.dart';
import '../../platform/usb/usb_printer_device.dart';

class PrinterRegistryState {
  const PrinterRegistryState({
    this.discoveredPrinters = const [],
    this.savedPrinters = const [],
    this.usbPrinters = const [],
    this.selectedPrinter,
    this.isScanning = false,
    this.capabilitiesMap = const {},
  });

  final List<PrinterDevice> discoveredPrinters;
  final List<PrinterDevice> savedPrinters;
  final List<UsbPrinterDevice> usbPrinters;
  final PrinterDevice? selectedPrinter;
  final bool isScanning;
  final Map<String, PrinterCapabilities> capabilitiesMap;

  PrinterRegistryState copyWith({
    List<PrinterDevice>? discoveredPrinters,
    List<PrinterDevice>? savedPrinters,
    List<UsbPrinterDevice>? usbPrinters,
    PrinterDevice? selectedPrinter,
    bool? isScanning,
    Map<String, PrinterCapabilities>? capabilitiesMap,
  }) {
    return PrinterRegistryState(
      discoveredPrinters: discoveredPrinters ?? this.discoveredPrinters,
      savedPrinters: savedPrinters ?? this.savedPrinters,
      usbPrinters: usbPrinters ?? this.usbPrinters,
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

  StreamSubscription<PrinterDevice>? _nsdSubscription;
  Timer? _scanTimeoutTimer;

  @override
  PrinterRegistryState build() {
    ref.onDispose(() {
      _nsdSubscription?.cancel();
      _scanTimeoutTimer?.cancel();
    });
    _loadSavedPrintersFromDisk();
    return const PrinterRegistryState(
      savedPrinters: [],
      selectedPrinter: null,
    );
  }

  Future<void> _loadSavedPrintersFromDisk() async {
    final loaded = await LocalStorageService.instance.loadSavedPrinters();
    final realPrinters =
        loaded.where((p) => p.id != 'save-as-pdf-virtual').toList();
    if (realPrinters.isNotEmpty) {
      state = state.copyWith(
        savedPrinters: realPrinters,
        selectedPrinter: state.selectedPrinter ?? realPrinters.first,
      );
      // Immediately fetch toner/ink and printer status for saved network printers
      for (final p in realPrinters) {
        if (p.connectionType == PrinterConnectionType.network) {
          queryCapabilitiesInBackground(p);
        }
      }
    }
  }

  void startNetworkScan() async {
    state = state.copyWith(isScanning: true);
    final bridge = ref.read(nsdDiscoveryBridgeProvider);
    await _nsdSubscription?.cancel();
    _nsdSubscription = bridge.onPrinterDiscovered.listen((printer) {
      addDiscoveredPrinter(printer);
      queryCapabilitiesInBackground(printer);
    });

    await bridge.startDiscovery();

    // Auto-stop discovery after 15 seconds to conserve device battery
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = Timer(const Duration(seconds: 15), () {
      stopNetworkScan();
    });
  }

  void stopNetworkScan() async {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    try {
      final bridge = ref.read(nsdDiscoveryBridgeProvider);
      await bridge.stopDiscovery();
    } catch (_) {}
    state = state.copyWith(isScanning: false);
  }

  Future<void> queryCapabilitiesInBackground(PrinterDevice printer,
      {bool force = false}) async {
    if (!force && state.capabilitiesMap.containsKey(printer.id)) return;
    try {
      final client = IppClient();
      final caps = await client.getCapabilities(printer);
      setPrinterCapabilities(printer.id, caps);
    } catch (_) {}
  }

  Future<void> refreshAllPrinters() async {
    for (final printer in [
      ...state.savedPrinters,
      ...state.discoveredPrinters
    ]) {
      if (printer.connectionType == PrinterConnectionType.network) {
        queryCapabilitiesInBackground(printer, force: true);
      }
    }
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
    if (printer.id == 'save-as-pdf-virtual') return;
    if (!state.savedPrinters.any((p) => p.id == printer.id)) {
      final updated = [...state.savedPrinters, printer];
      state = state.copyWith(savedPrinters: updated);
      // Persist forever to storage
      LocalStorageService.instance.savePrinters(updated);
      if (printer.connectionType == PrinterConnectionType.network) {
        queryCapabilitiesInBackground(printer, force: true);
      }
    }
  }

  void removeSavedPrinter(String printerId) {
    final updated =
        state.savedPrinters.where((p) => p.id != printerId).toList();
    state = state.copyWith(
      savedPrinters: updated,
      selectedPrinter: state.selectedPrinter?.id == printerId
          ? (updated.isNotEmpty ? updated.first : null)
          : state.selectedPrinter,
    );
    // Persist removal to storage
    LocalStorageService.instance.savePrinters(updated);
  }

  void selectPrinter(PrinterDevice? printer) {
    state = state.copyWith(selectedPrinter: printer);
  }

  void setUsbPrinters(List<UsbPrinterDevice> devices) {
    state = state.copyWith(usbPrinters: devices);
  }

  void addOrUpdateUsbDevice(UsbPrinterDevice device) {
    final existingIndex = state.usbPrinters.indexWhere((d) =>
        d.deviceId == device.deviceId ||
        (d.vendorId == device.vendorId && d.productId == device.productId));
    final updatedList = List<UsbPrinterDevice>.from(state.usbPrinters);
    if (existingIndex >= 0) {
      updatedList[existingIndex] = device;
    } else {
      updatedList.add(device);
    }

    final printerDevice = device.toPrinterDevice();

    // Check if this printer is already in savedPrinters
    final savedIndex = state.savedPrinters.indexWhere((p) =>
        p.id == printerDevice.id ||
        (p.vendorId == device.vendorId && p.productId == device.productId));

    final updatedSaved = List<PrinterDevice>.from(state.savedPrinters);
    final PrinterDevice activePrinter;
    if (savedIndex >= 0) {
      // Update existing saved printer with active runtime usbDeviceId & online status
      activePrinter = updatedSaved[savedIndex].copyWith(
        usbDeviceId: device.deviceId,
        isOnline: true,
      );
      updatedSaved[savedIndex] = activePrinter;
    } else {
      activePrinter = printerDevice;
      updatedSaved.add(activePrinter);
    }

    // Persist saved printers forever
    LocalStorageService.instance.savePrinters(updatedSaved);

    state = state.copyWith(
      usbPrinters: updatedList,
      savedPrinters: updatedSaved,
      selectedPrinter: activePrinter, // Auto-select the plugged-in printer
    );
  }

  void removeUsbDevice(int deviceId) {
    final detached = state.usbPrinters.cast<UsbPrinterDevice?>().firstWhere(
          (d) => d?.deviceId == deviceId,
          orElse: () => null,
        );

    final updatedUsb =
        state.usbPrinters.where((d) => d.deviceId != deviceId).toList();

    // Mark corresponding saved printer as offline
    final updatedSaved = state.savedPrinters.map((p) {
      if (p.usbDeviceId == deviceId ||
          (detached != null &&
              p.vendorId == detached.vendorId &&
              p.productId == detached.productId)) {
        return p.copyWith(isOnline: false);
      }
      return p;
    }).toList();

    LocalStorageService.instance.savePrinters(updatedSaved);

    state = state.copyWith(
      usbPrinters: updatedUsb,
      savedPrinters: updatedSaved,
    );
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
