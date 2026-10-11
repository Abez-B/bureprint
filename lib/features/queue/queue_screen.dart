import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/print_job.dart';
import 'queue_provider.dart';

class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(printQueueProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Queue'),
        actions: [
          if (queueState.jobs.any((j) => j.status.isTerminal))
            IconButton(
              tooltip: 'Clear completed jobs',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () =>
                  ref.read(printQueueProvider.notifier).clearCompletedJobs(),
            ),
        ],
      ),
      body: queueState.jobs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: isDark
                        ? const Color(0xFF757575)
                        : const Color(0xFF9E9E9E),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No print jobs in queue',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Submitted documents will appear here.'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: queueState.jobs.length,
              itemBuilder: (context, index) {
                final job = queueState.jobs[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                job.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _buildStatusBadge(context, job.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Printer: ${job.printerName}',
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFFBDBDBD)
                                : const Color(0xFF616161),
                            fontSize: 14,
                          ),
                        ),
                        if (job.message != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            job.message!,
                            style: const TextStyle(
                                fontSize: 13, fontStyle: FontStyle.italic),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Copies: ${job.copies}${job.pageCount != null ? " · ${job.pageCount} pages" : ""}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (job.status.isActive)
                              OutlinedButton(
                                onPressed: () => ref
                                    .read(printQueueProvider.notifier)
                                    .requestJobCancellation(job.id),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                ),
                                child: const Text('Cancel',
                                    style: TextStyle(fontSize: 13)),
                              )
                            else if (job.status.isTerminal)
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: () => ref
                                    .read(printQueueProvider.notifier)
                                    .removeJob(job.id),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, PrintJobStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = switch (status) {
      PrintJobStatus.queuedLocally => 'Queued',
      PrintJobStatus.preparingDocument => 'Preparing',
      PrintJobStatus.convertingDocument => 'Converting',
      PrintJobStatus.submittingToPrinter => 'Submitting',
      PrintJobStatus.acceptedByPrinter => 'Accepted',
      PrintJobStatus.printing => 'Printing',
      PrintJobStatus.completed => 'Completed',
      PrintJobStatus.failed => 'Failed',
      PrintJobStatus.cancellationRequested => 'Canceling',
      PrintJobStatus.canceled => 'Canceled',
      PrintJobStatus.statusUnknown => 'Unknown',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark ? const Color(0xFF424242) : const Color(0xFFE0E0E0),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
