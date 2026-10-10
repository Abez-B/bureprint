import 'package:flutter/material.dart';

class PrintersScreen extends StatelessWidget {
  const PrintersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Printers', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Discovery is not connected yet. The demo printer in the domain layer is for UI development only.',
        ),
        const SizedBox(height: 20),
        const Card(
          child: ListTile(
            leading: Icon(Icons.wifi_find),
            title: Text('Network discovery'),
            subtitle: Text('Planned: mDNS/DNS-SD and IPP capability queries'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.usb),
            title: Text('USB / OTG'),
            subtitle: Text('Planned: Android USB Host API and explicit device support'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.add_link),
            title: Text('Add printer by address'),
            subtitle: Text('Planned: hostname or IP address'),
          ),
        ),
      ],
    );
  }
}
