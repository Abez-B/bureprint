import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/printer_capabilities.dart';
import '../../domain/models/printer_device.dart';
import '../../platform/usb/usb_host_bridge.dart';
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
          const SizedBox(height: 16),

          // USB OTG Printers Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'USB OTG Printers',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh USB'),
                onPressed: () async {
                  final bridge = ref.read(usbHostBridgeProvider);
                  final devices = await bridge.enumerateDevices();
                  ref
                      .read(printerRegistryProvider.notifier)
                      .setUsbPrinters(devices);
                  for (final d in devices) {
                    ref
                        .read(printerRegistryProvider.notifier)
                        .addOrUpdateUsbDevice(d);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (printerState.usbPrinters.isEmpty)
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.usb_outlined,
                      size: 28,
                      color: isDark
                          ? const Color(0xFF888888)
                          : const Color(0xFF777777),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Plug in a USB printer with an OTG cable.\nBurePrint will detect it and request permission automatically.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFFBDBDBD)
                              : const Color(0xFF616161),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (final usbDev in printerState.usbPrinters)
              _buildUsbCard(context, ref, usbDev, printerState, isDark),
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
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No printers discovered yet.\nEnsure your printer is on the same Wi-Fi network.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF9E9E9E)
                          : const Color(0xFF757575),
                      height: 1.4,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            )
          else
            for (final printer in printerState.discoveredPrinters)
              _buildDiscoveredCard(context, ref, printer, printerState, isDark),
          const SizedBox(height: 20),

          // Saved Printers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saved Printers',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh Status'),
                onPressed: () {
                  ref
                      .read(printerRegistryProvider.notifier)
                      .refreshAllPrinters();
                },
              ),
            ],
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
              _buildSavedCard(context, ref, printer, printerState, isDark),
        ],
      ),
    );
  }

  Widget _buildUsbCard(
    BuildContext context,
    WidgetRef ref,
    dynamic usbDev,
    PrinterRegistryState printerState,
    bool isDark,
  ) {
    final isSelected =
        printerState.selectedPrinter?.id == 'usb-${usbDev.deviceId}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.white12 : Colors.black12),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: usbDev.hasPermission
            ? () {
                ref
                    .read(printerRegistryProvider.notifier)
                    .selectPrinter(usbDev.toPrinterDevice());
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.usb_rounded, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usbDev.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      usbDev.hasPermission
                          ? 'USB OTG · Ready'
                          : 'USB OTG · Permission required',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: usbDev.hasPermission
                            ? (isDark ? Colors.white60 : Colors.black54)
                            : (isDark
                                ? const Color(0xFFFFB74D)
                                : const Color(0xFFE65100)),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (usbDev.hasPermission)
                if (isSelected)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : Colors.black,
                      borderRadius: BorderRadius.circular(6),
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
                else
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 0),
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      ref
                          .read(printerRegistryProvider.notifier)
                          .selectPrinter(usbDev.toPrinterDevice());
                    },
                    child: const Text('Select', style: TextStyle(fontSize: 12)),
                  )
              else
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () async {
                    final bridge = ref.read(usbHostBridgeProvider);
                    final granted =
                        await bridge.requestPermission(usbDev.deviceId);
                    if (granted) {
                      ref
                          .read(printerRegistryProvider.notifier)
                          .addOrUpdateUsbDevice(
                              usbDev.copyWith(hasPermission: true));
                    }
                  },
                  child: const Text('Allow', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscoveredCard(
    BuildContext context,
    WidgetRef ref,
    PrinterDevice printer,
    PrinterRegistryState printerState,
    bool isDark,
  ) {
    final hostLabel = printer.host != null && printer.host!.isNotEmpty
        ? 'Wi-Fi · ${printer.host}'
        : 'Wi-Fi Network';
    final supplies =
        printerState.capabilitiesMap[printer.id]?.markerSupplies ?? const [];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.wifi_rounded, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        printer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hostLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => ref
                      .read(printerRegistryProvider.notifier)
                      .savePrinter(printer),
                  child: const Text('Save', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            if (supplies.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildSupplyIndicators(supplies, isDark),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSavedCard(
    BuildContext context,
    WidgetRef ref,
    PrinterDevice printer,
    PrinterRegistryState printerState,
    bool isDark,
  ) {
    final isSelected = printerState.selectedPrinter?.id == printer.id;
    final isNetwork = printer.connectionType == PrinterConnectionType.network;
    final subtitleLabel = isNetwork
        ? (printer.host != null && printer.host!.isNotEmpty
            ? 'Wi-Fi · ${printer.host}'
            : 'Wi-Fi Printer')
        : 'USB OTG Printer';

    final supplies =
        printerState.capabilitiesMap[printer.id]?.markerSupplies ?? const [];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? (isDark ? Colors.white : Colors.black)
              : (isDark ? Colors.white12 : Colors.black12),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            ref.read(printerRegistryProvider.notifier).selectPrinter(printer),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2C2C2E)
                          : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isNetwork ? Icons.wifi_rounded : Icons.usb_rounded,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          printer.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white : Colors.black,
                        borderRadius: BorderRadius.circular(6),
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
                  else
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 0),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => ref
                          .read(printerRegistryProvider.notifier)
                          .selectPrinter(printer),
                      child:
                          const Text('Select', style: TextStyle(fontSize: 12)),
                    ),
                  const SizedBox(width: 2),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Remove',
                    onPressed: () => ref
                        .read(printerRegistryProvider.notifier)
                        .removeSavedPrinter(printer.id),
                  ),
                ],
              ),
              if (supplies.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSupplyIndicators(supplies, isDark),
              ],
            ],
          ),
        ),
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
      notifier.stopNetworkScan();
    } else {
      notifier.startNetworkScan();
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

                  // Save printer so it persists forever
                  ref
                      .read(printerRegistryProvider.notifier)
                      .savePrinter(newDevice);

                  // Fetch supplies and attributes in background
                  ref
                      .read(printerRegistryProvider.notifier)
                      .queryCapabilitiesInBackground(newDevice);

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
