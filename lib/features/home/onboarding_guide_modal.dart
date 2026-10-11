import 'package:flutter/material.dart';
import '../../core/storage/local_storage_service.dart';

class OnboardingGuideModal extends StatefulWidget {
  const OnboardingGuideModal({super.key});

  static Future<void> checkAndShow(BuildContext context) async {
    final seen = await LocalStorageService.instance.hasSeenGuide();
    if (!seen && context.mounted) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const OnboardingGuideModal(),
      );
    }
  }

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const OnboardingGuideModal(),
    );
  }

  @override
  State<OnboardingGuideModal> createState() => _OnboardingGuideModalState();
}

class _OnboardingGuideModalState extends State<OnboardingGuideModal> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const _steps = [
    _GuideStep(
      icon: Icons.shield_outlined,
      title: 'Private & Local-First',
      subtitle:
          'Your documents and print jobs are rendered and processed 100% locally on your phone. No tracking, no external cloud servers.',
    ),
    _GuideStep(
      icon: Icons.folder_zip_outlined,
      title: 'Save to BurePrint',
      subtitle:
          'When saving or merging PDFs, documents are saved directly to your phone\'s accessible BurePrint folder in Downloads / File Manager.',
    ),
    _GuideStep(
      icon: Icons.wifi_find_outlined,
      title: 'Wi-Fi & USB OTG Ready',
      subtitle:
          'Discovers network printers automatically on Wi-Fi using mDNS/IPP, or plug in a printer with an OTG cable for direct hardware printing.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finish() {
    LocalStorageService.instance.setGuideSeen();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: theme.scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        side: BorderSide(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top indicator handle
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title badge
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/brand/icon-512.png',
                      width: 24,
                      height: 24,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.print, size: 24),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Welcome to BurePrint',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Step Carousel
              SizedBox(
                height: 190,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (idx) {
                    setState(() => _currentPage = idx);
                  },
                  itemBuilder: (ctx, idx) {
                    final step = _steps[idx];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2C2C2E)
                                  : const Color(0xFFF2F2F7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(step.icon, size: 28),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            step.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            step.subtitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : Colors.black87,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Dots indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (idx) {
                  final isActive = _currentPage == idx;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.white24 : Colors.black26),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Action button
              Row(
                children: [
                  if (_currentPage < _steps.length - 1) ...[
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : Colors.black,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text('Next'),
                    ),
                  ] else ...[
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: isDark ? Colors.white : Colors.black,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _finish,
                        child: const Text(
                          'Get Started',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideStep {
  const _GuideStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}
