import 'package:flutter/material.dart';

class QueueScreen extends StatelessWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Print queue', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Your print jobs will appear here once job submission is implemented.'),
          const SizedBox(height: 20),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 48),
                  SizedBox(height: 12),
                  Text('No print jobs yet'),
                ],
              ),
            ),
          ),
        ],
      );
}
