import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Hero Card: Pure Black & White Contrast
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white : Colors.black,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF333333) : const Color(0xFF000000),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/brand/icon-96.png',
                      width: 44,
                      height: 44,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.print,
                        size: 36,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'BurePrint',
                      style: TextStyle(
                        color: isDark ? Colors.black : Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Private, local-first printing. Your documents stay on your device.',
                style: TextStyle(
                  color: isDark
                      ? const Color(0xFF424242)
                      : const Color(0xFFE0E0E0),
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              // Three quick options: Images, Documents, and Files
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.go('/documents?type=images'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? Colors.black : Colors.white,
                      foregroundColor: isDark ? Colors.white : Colors.black,
                    ),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Images'),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/documents?type=documents'),
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? Colors.black : Colors.white,
                      foregroundColor: isDark ? Colors.white : Colors.black,
                    ),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Documents'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/documents?type=all'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      side: BorderSide(
                        color: isDark ? Colors.black : Colors.white,
                      ),
                    ),
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('All Files'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Section: Printers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Printers',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/printers'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.print_outlined),
            title: const Text(
              'No printer connected',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Discover on Wi-Fi or connect via USB OTG'),
            trailing: OutlinedButton(
              onPressed: () => context.go('/printers'),
              child: const Text('Scan'),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Section: Active Jobs / Queue
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Print Queue',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/queue'),
              child: const Text('View Queue'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading: Icon(Icons.check_circle_outline),
            title: Text(
              'Queue is empty',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text('No jobs currently pending or active'),
          ),
        ),
      ],
    );
  }
}
