import 'package:flutter/material.dart';

class DocumentsScreen extends StatelessWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderScreen(
      icon: Icons.description_outlined,
      title: 'Documents',
      description:
          'Next: add file_picker and a PDF renderer, then build a preview and print-settings flow.',
      bullets: [
        'Import PDFs and images',
        'Preview pages before printing',
        'Choose page ranges and copies',
      ],
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({
    required this.icon,
    required this.title,
    required this.description,
    required this.bullets,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Icon(icon, size: 54),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(description),
          const SizedBox(height: 24),
          for (final bullet in bullets)
            ListTile(
              leading: const Icon(Icons.radio_button_unchecked),
              title: Text(bullet),
            ),
        ],
      );
}
