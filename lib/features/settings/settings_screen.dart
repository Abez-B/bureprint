import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 12),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Privacy-first by design'),
            subtitle: Text('No account or cloud upload is required by this scaffold.'),
          ),
          const ListTile(
            leading: Icon(Icons.palette_outlined),
            title: Text('Appearance'),
            subtitle: Text('Follows the system theme'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('BurePrint'),
            subtitle: Text('Version 0.1.0 · Early development'),
          ),
        ],
      );
}
