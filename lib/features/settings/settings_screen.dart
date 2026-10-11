import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('Privacy & Security', theme),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.shield_outlined),
                  title: Text('Zero Telemetry'),
                  subtitle: Text(
                      'No tracking, analytics, or third-party monitoring.'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.lock_outline),
                  title: Text('Transport Security (IPPS)'),
                  subtitle:
                      Text('Prefers TLS encrypted connections over port 631.'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.delete_sweep_outlined),
                  title: Text('Auto Cache Purge'),
                  subtitle: Text(
                      'Temporary conversion artifacts are wiped immediately.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('Appearance', theme),
          Card(
            child: ListTile(
              leading: const Icon(Icons.contrast_outlined),
              title: const Text('Theme Mode'),
              subtitle: Text(
                themeMode == ThemeMode.system
                    ? 'Following system theme (${isDark ? "Dark" : "Light"})'
                    : (isDark ? 'Dark mode enabled' : 'Light mode enabled'),
              ),
              trailing: Switch(
                value: isDark,
                onChanged: (val) {
                  ref.read(themeModeProvider.notifier).setThemeMode(
                        val ? ThemeMode.dark : ThemeMode.light,
                      );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader('About', theme),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(
                      'assets/brand/icon-48.png',
                      width: 28,
                      height: 28,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.info_outline),
                    ),
                  ),
                  title: const Text('BurePrint'),
                  subtitle: const Text('Version 0.1.0 · Free & Open-Source'),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.copyright_outlined),
                  title: Text('License'),
                  subtitle: Text('MIT License'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}
