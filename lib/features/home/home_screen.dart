import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/print_job.dart';
import '../../domain/models/printer_device.dart';
import '../../platform/share/share_sheet_bridge.dart';
import '../printers/printers_provider.dart';
import '../queue/queue_provider.dart';
import 'onboarding_guide_modal.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        OnboardingGuideModal.checkAndShow(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final printerState = ref.watch(printerRegistryProvider);
    final queueState = ref.watch(printQueueProvider);

    final selectedPrinter = printerState.selectedPrinter;
    final activeJob = queueState.jobs
        .where((j) => j.status == PrintJobStatus.printing)
        .firstOrNull;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  constraints.maxHeight - 28, // account for vertical padding
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Compact Hero Card: Subtle border, balanced padding, sleek typography
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1C1C1E) : Colors.black,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF2C2C2E)
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/brand/icon-512.png',
                                width: 38,
                                height: 38,
                                filterQuality: FilterQuality.medium,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.print,
                                      size: 22, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BurePrint',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  SizedBox(height: 1),
                                  Text(
                                    'Private, local-first printing',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Quick action buttons in a balanced 3-column row
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickAction(
                                context: context,
                                label: 'Images',
                                icon: Icons.photo_library_outlined,
                                route: '/documents?type=images',
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildQuickAction(
                                context: context,
                                label: 'Documents',
                                icon: Icons.description_outlined,
                                route: '/documents?type=documents',
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildQuickAction(
                                context: context,
                                label: 'All Files',
                                icon: Icons.folder_open_outlined,
                                route: '/documents?type=all',
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Section: Printers
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Printer',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/printers'),
                        child: Text(
                          'View All',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildPrinterStatusCard(context, selectedPrinter, isDark),
                  const SizedBox(height: 18),

                  // Section: Active Jobs / Queue
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Print Queue',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/queue'),
                        child: Text(
                          'View Queue',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildQueueStatusCard(
                      context, activeJob, queueState.jobs.length, isDark),
                  const Spacer(),
                  const SizedBox(height: 24),
                  _buildBottomFooter(context, isDark),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomFooter(BuildContext context, bool isDark) {
    final linkColor = isDark ? Colors.white60 : Colors.black54;

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () =>
                _launchExternalUrl(context, 'https://buymeacoffee.com/abhrams'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                'Buy Me a Coffee',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: linkColor,
                ),
              ),
            ),
          ),
          Text(
            ' | ',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: () =>
                _launchExternalUrl(context, 'https://bharath.is-cool.dev'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                'Developer',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: linkColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchExternalUrl(BuildContext context, String url) async {
    try {
      final bridge = ref.read(shareSheetBridgeProvider);
      await bridge.openUrl(url);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link: $url'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildQuickAction({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String route,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(
          color: const Color(0x1FFFFFFF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0x2EFFFFFF),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterStatusCard(
    BuildContext context,
    PrinterDevice? printer,
    bool isDark,
  ) {
    final hasPrinter = printer != null;
    final isNetwork = printer?.connectionType == PrinterConnectionType.network;
    final icon = hasPrinter
        ? (isNetwork ? Icons.wifi_rounded : Icons.usb_rounded)
        : Icons.print_outlined;

    final title = hasPrinter ? printer.name : 'No printer connected';
    final subtitle = hasPrinter
        ? (isNetwork
            ? (printer.host != null
                ? 'Wi-Fi · ${printer.host}'
                : 'Wi-Fi Printer')
            : 'USB OTG · Ready')
        : 'Discover on Wi-Fi or connect via USB OTG';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/printers'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => context.go('/printers'),
                child: Text(
                  hasPrinter ? 'Change' : 'Scan',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueStatusCard(
    BuildContext context,
    PrintJob? activeJob,
    int totalJobs,
    bool isDark,
  ) {
    final hasActive = activeJob != null;
    final title = hasActive
        ? 'Printing: ${activeJob.name}'
        : (totalJobs > 0 ? '$totalJobs completed job(s)' : 'Queue is empty');

    final subtitle = hasActive
        ? (activeJob.message ?? 'Transmitting to printer...')
        : (totalJobs > 0
            ? 'Tap to view history'
            : 'No jobs currently pending or active');

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.white12 : Colors.black12,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/queue'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasActive
                      ? Icons.hourglass_top_rounded
                      : Icons.check_circle_outline,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
