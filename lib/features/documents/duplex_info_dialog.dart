import 'package:flutter/material.dart';

class DuplexInfoDialog extends StatelessWidget {
  const DuplexInfoDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => const DuplexInfoDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.info_outline, size: 22),
          SizedBox(width: 8),
          Text('Duplex (2-Sided) Flip Guide'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How the back side of the paper is oriented relative to the front:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),

            // Long Edge Option
            _buildOptionCard(
              context,
              title: 'Long Edge (Book Flip)',
              subtitle:
                  'Standard for portrait documents. Flips like a book page from left-to-right so both sides are right-side-up.',
              isDark: isDark,
              child: _buildBookFlipDiagram(isDark),
            ),
            const SizedBox(height: 14),

            // Short Edge Option
            _buildOptionCard(
              context,
              title: 'Short Edge (Calendar/Notepad Flip)',
              subtitle:
                  'Flips along the top edge like a legal pad or hanging wall calendar.',
              isDark: isDark,
              child: _buildNotepadFlipDiagram(isDark),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Understood'),
        ),
      ],
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF333333) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFFBDBDBD) : const Color(0xFF616161),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildBookFlipDiagram(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageSheet('Page 1', '▲ Top', isDark),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.swap_horiz, size: 24),
        ),
        _buildPageSheet('Page 2', '▲ Top', isDark),
      ],
    );
  }

  Widget _buildNotepadFlipDiagram(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildPageSheet('Page 1', '▲ Top', isDark),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.swap_vert, size: 24),
        ),
        _buildPageSheet('Page 2', '▼ Top (Flipped)', isDark),
      ],
    );
  }

  Widget _buildPageSheet(String pageLabel, String topIndicator, bool isDark) {
    return Container(
      width: 80,
      height: 100,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF757575) : const Color(0xFF000000),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            topIndicator,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
          ),
          Text(
            pageLabel,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 2),
        ],
      ),
    );
  }
}
