import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/printer_capabilities.dart';
import '../../domain/models/printer_device.dart';
import 'printers_provider.dart';

class PrintersScreen extends ConsumerWidget {
  const PrintersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printerState = ref.watch(printerRegistryProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printers'),
        actions: [
          IconButton(
            tooltip: 'Add by IP/Host',
            icon: const Icon(Icons.add_link),
            onPressed: () => _showAddPrinterDialog(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Scan header banner
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.wifi_find_outlined, size: 36),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Network Discovery (mDNS)',
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          printerState.isScanning
                              ? 'Scanning subnet for IPP printers...'
                              : 'Tap scan to locate printers on your local Wi-Fi.',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFBDBDBD)
                                : const Color(0xFF616161),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => _toggleScan(ref, printerState.isScanning),
                    child: Text(printerState.isScanning ? 'Stop' : 'Scan'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Discovered Printers
          Text(
            'Discovered Printers',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          if (printerState.discoveredPrinters.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No printers discovered yet.\nEnsure your printer is on the same Wi-Fi network.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF9E9E9E)
                          : const Color(0xFF757575),
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            )
          else
            for (final printer in printerState.discoveredPrinters)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.print_outlined),
                  title: Text(
                    printer.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(printer.endpointUri),
                      if (printerState.capabilitiesMap[printer.id]
                              ?.markerSupplies.isNotEmpty ??
                          false)
                        _buildSupplyIndicators(
                          printerState
                              .capabilitiesMap[printer.id]!.markerSupplies,
                          isDark,
                        ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: () => ref
                            .read(printerRegistryProvider.notifier)
                            .savePrinter(printer),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: 20),

          // Saved Printers
          Text(
            'Saved Printers',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          if (printerState.savedPrinters.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No saved printers.'),
              ),
            )
          else
            for (final printer in printerState.savedPrinters)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  selected: printerState.selectedPrinter?.id == printer.id,
                  leading: const Icon(Icons.print_outlined),
                  title: Text(
                    printer.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${printer.endpointUri} · ${printerState.selectedPrinter?.id == printer.id ? "Selected (Default)" : "Ready"}',
                      ),
                      if (printerState.capabilitiesMap[printer.id]
                              ?.markerSupplies.isNotEmpty ??
                          false)
                        _buildSupplyIndicators(
                          printerState
                              .capabilitiesMap[printer.id]!.markerSupplies,
                          isDark,
                        ),
                    ],
                  ),
                  trailing: printerState.selectedPrinter?.id == printer.id
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white : Colors.black,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Active',
                            style: TextStyle(
                              color: isDark ? Colors.black : Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: () => ref
                              .read(printerRegistryProvider.notifier)
                              .selectPrinter(printer),
                          child: const Text('Select'),
                        ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildSupplyIndicators(
      List<PrinterSupplyLevel> supplies, bool isDark) {
    if (supplies.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: supplies.map((s) {
          final color = Color(int.parse(
                  s.colorHex.replaceFirst('#', '').padLeft(6, '0'),
                  radix: 16) |
              0xFF000000);
          final percent = s.levelPercent.clamp(0, 100);

          return Tooltip(
            message: '${s.name}: $percent%',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white54 : Colors.black26,
                      width: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 32,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: percent / 100.0,
                      backgroundColor: isDark ? Colors.white12 : Colors.black12,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        color == Colors.black && isDark
                            ? Colors.white70
                            : color,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFBDBDBD)
                        : const Color(0xFF616161),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _toggleScan(WidgetRef ref, bool isScanning) {
    final notifier = ref.read(printerRegistryProvider.notifier);
    if (isScanning) {
      notifier.setScanning(false);
    } else {
      notifier.setScanning(true);
      // Simulate discovering a local IPP printer
      Future.delayed(const Duration(milliseconds: 600), () {
        notifier.addDiscoveredPrinter(
          const PrinterDevice(
            id: 'discovered-ipp-1',
            name: 'Office LaserJet Pro',
            connectionType: PrinterConnectionType.network,
            host: '192.168.1.150',
            port: 631,
            resourcePath: '/ipp/print',
            isOnline: true,
            isDiscovered: true,
          ),
        );
        notifier.setScanning(false);
      });
    }
  }

  void _showAddPrinterDialog(BuildContext context, WidgetRef ref) {
    final hostController = TextEditingController();
    final nameController = TextEditingController();
    final portController = TextEditingController(text: '631');
    final pathController = TextEditingController(text: '/ipp/print');
    TransportSecurityPolicy securityPolicy = TransportSecurityPolicy.ippsStrict;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Printer by IP/Host'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Printer Name (Optional)',
                    hintText: 'e.g. Office LaserJet Pro',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hostController,
                  decoration: const InputDecoration(
                    labelText: 'Host or IP Address *',
                    hintText: 'e.g. 192.168.1.50 or printer.local',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: portController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          hintText: '631',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: pathController,
                        decoration: const InputDecoration(
                          labelText: 'Queue Path',
                          hintText: '/ipp/print',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text(
                  'Transport Security',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                SegmentedButton<TransportSecurityPolicy>(
                  segments: const [
                    ButtonSegment(
                      value: TransportSecurityPolicy.ippsStrict,
                      label: Text('IPPS (TLS)'),
                    ),
                    ButtonSegment(
                      value: TransportSecurityPolicy.plainIppExplicit,
                      label: Text('Plain IPP'),
                    ),
                  ],
                  selected: {securityPolicy},
                  onSelectionChanged: (val) {
                    setDialogState(() => securityPolicy = val.first);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final host = hostController.text.trim();
                final name = nameController.text.trim();
                final port = int.tryParse(portController.text.trim()) ?? 631;
                final path = pathController.text.trim().isEmpty
                    ? '/ipp/print'
                    : pathController.text.trim();

                if (host.isNotEmpty) {
                  final newDevice = PrinterDevice(
                    id: 'manual-${host.replaceAll(".", "-")}-$port',
                    name: name.isNotEmpty ? name : 'Printer ($host)',
                    connectionType: PrinterConnectionType.network,
                    host: host,
                    port: port,
                    resourcePath: path.startsWith('/') ? path : '/$path',
                    securityPolicy: securityPolicy,
                    isOnline: true,
                    isDiscovered: false,
                  );

                  ref
                      .read(printerRegistryProvider.notifier)
                      .addDiscoveredPrinter(newDevice);

                  // Provide simulated supply levels for manual test device
                  ref
                      .read(printerRegistryProvider.notifier)
                      .setPrinterCapabilities(
                        newDevice.id,
                        PrinterCapabilities(
                          printerName: newDevice.name,
                          printerMakeAndModel: 'Manual Network Printer',
                          printerState: 'idle',
                          supportsColor: true,
                          supportsDuplex: true,
                          operationsSupported: const [0x0002, 0x0005, 0x0006],
                          documentFormats: const [
                            'application/pdf',
                            'image/pwg-raster',
                            'image/jpeg',
                            'image/png'
                          ],
                          markerSupplies: const [
                            PrinterSupplyLevel(
                                name: 'Black Toner',
                                colorHex: '#000000',
                                levelPercent: 78),
                            PrinterSupplyLevel(
                                name: 'Color Toner',
                                colorHex: '#00AAFF',
                                levelPercent: 55),
                          ],
                        ),
                      );

                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('Add Printer'),
            ),
          ],
        ),
      ),
    );
  }
}
