import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF246B57), Color(0xFF399879)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.print_rounded, color: Colors.white, size: 36),
              SizedBox(height: 18),
              Text(
                'Print, without the fuss.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Private, local-first printing. Your documents stay yours.',
                style: TextStyle(color: Colors.white, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text('Get started', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        _ActionCard(
          icon: Icons.description_outlined,
          title: 'Choose a document',
          subtitle: 'PDF and image workflow planned',
          onTap: () => context.go('/documents'),
        ),
        _ActionCard(
          icon: Icons.print_outlined,
          title: 'Find a printer',
          subtitle: 'Network and USB support in development',
          onTap: () => context.go('/printers'),
        ),
        _ActionCard(
          icon: Icons.list_alt_outlined,
          title: 'Print queue',
          subtitle: 'View print jobs and their status',
          onTap: () => context.go('/queue'),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Early development scaffold: no real print jobs are sent yet.',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
