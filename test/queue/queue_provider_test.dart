import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bureprint/domain/interfaces/print_job_queue_storage.dart';
import 'package:bureprint/domain/models/print_job.dart';
import 'package:bureprint/features/queue/queue_provider.dart';

void main() {
  group('PrintQueueNotifier state machine & storage persistence', () {
    test('adds job and persists to storage', () async {
      final storage = InMemoryPrintJobQueueStorage();
      final container = ProviderContainer(
        overrides: [
          printQueueProvider.overrideWith(
            () => PrintQueueNotifier(storage: storage),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(printQueueProvider.notifier);

      final job1 = PrintJob(
        id: 'job-1',
        name: 'Invoice.pdf',
        status: PrintJobStatus.queuedLocally,
        printerId: 'printer-1',
        printerName: 'LaserJet',
        createdAt: DateTime.now(),
      );

      await notifier.addJob(job1);

      final state = container.read(printQueueProvider);
      expect(state.jobs.length, equals(1));
      expect(state.jobs.first.id, equals('job-1'));

      final stored = await storage.loadJobs();
      expect(stored.length, equals(1));
      expect(stored.first.id, equals('job-1'));
    });

    test('updates status and transitions to cancellation requested', () async {
      final storage = InMemoryPrintJobQueueStorage();
      final container = ProviderContainer(
        overrides: [
          printQueueProvider.overrideWith(
            () => PrintQueueNotifier(storage: storage),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(printQueueProvider.notifier);

      final job = PrintJob(
        id: 'job-2',
        name: 'Report.pdf',
        status: PrintJobStatus.submittingToPrinter,
        printerId: 'printer-1',
        printerName: 'LaserJet',
        createdAt: DateTime.now(),
      );

      await notifier.addJob(job);
      await notifier.requestJobCancellation('job-2');

      final state = container.read(printQueueProvider);
      expect(state.jobs.first.status,
          equals(PrintJobStatus.cancellationRequested));
    });

    test('clears completed jobs safely while retaining active jobs', () async {
      final storage = InMemoryPrintJobQueueStorage();
      final container = ProviderContainer(
        overrides: [
          printQueueProvider.overrideWith(
            () => PrintQueueNotifier(storage: storage),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(printQueueProvider.notifier);

      final activeJob = PrintJob(
        id: 'job-active',
        name: 'Active.pdf',
        status: PrintJobStatus.printing,
        printerId: 'printer-1',
        printerName: 'LaserJet',
        createdAt: DateTime.now(),
      );

      final completedJob = PrintJob(
        id: 'job-done',
        name: 'Done.pdf',
        status: PrintJobStatus.completed,
        printerId: 'printer-1',
        printerName: 'LaserJet',
        createdAt: DateTime.now(),
      );

      await notifier.addJob(activeJob);
      await notifier.addJob(completedJob);

      expect(container.read(printQueueProvider).jobs.length, equals(2));

      await notifier.clearCompletedJobs();

      final state = container.read(printQueueProvider);
      expect(state.jobs.length, equals(1));
      expect(state.jobs.first.id, equals('job-active'));
    });
  });
}
