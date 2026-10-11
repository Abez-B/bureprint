import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/interfaces/print_job_queue_storage.dart';
import '../../domain/models/print_job.dart';

class PrintQueueState {
  const PrintQueueState({
    this.jobs = const [],
    this.isLoading = false,
  });

  final List<PrintJob> jobs;
  final bool isLoading;

  PrintQueueState copyWith({
    List<PrintJob>? jobs,
    bool? isLoading,
  }) {
    return PrintQueueState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PrintQueueNotifier extends Notifier<PrintQueueState> {
  PrintQueueNotifier({PrintJobQueueStorage? storage})
      : _storage = storage ?? InMemoryPrintJobQueueStorage();

  final PrintJobQueueStorage _storage;

  @override
  PrintQueueState build() {
    return const PrintQueueState();
  }

  Future<void> loadStoredJobs() async {
    state = state.copyWith(isLoading: true);
    final stored = await _storage.loadJobs();
    state = state.copyWith(jobs: stored, isLoading: false);
  }

  Future<void> addJob(PrintJob job) async {
    final updated = [job, ...state.jobs];
    state = state.copyWith(jobs: updated);
    await _storage.saveJobs(updated);
  }

  Future<void> updateJobStatus(
    String jobId,
    PrintJobStatus newStatus, {
    String? message,
    int? sheetsCompleted,
  }) async {
    final updated = [
      for (final job in state.jobs)
        if (job.id == jobId)
          job.copyWith(
            status: newStatus,
            message: message ?? job.message,
            sheetsCompleted: sheetsCompleted ?? job.sheetsCompleted,
            updatedAt: DateTime.now(),
          )
        else
          job,
    ];
    state = state.copyWith(jobs: updated);
    await _storage.saveJobs(updated);
  }

  Future<void> requestJobCancellation(String jobId) async {
    await updateJobStatus(
      jobId,
      PrintJobStatus.cancellationRequested,
      message: 'Cancellation requested by user',
    );
  }

  Future<void> removeJob(String jobId) async {
    final updated = state.jobs.where((job) => job.id != jobId).toList();
    state = state.copyWith(jobs: updated);
    await _storage.saveJobs(updated);
  }

  Future<void> clearCompletedJobs() async {
    final updated = state.jobs.where((job) => !job.status.isTerminal).toList();
    state = state.copyWith(jobs: updated);
    await _storage.saveJobs(updated);
  }
}

final printQueueProvider =
    NotifierProvider<PrintQueueNotifier, PrintQueueState>(
  PrintQueueNotifier.new,
);

final activePrintJobsProvider = Provider<List<PrintJob>>((ref) {
  final queueState = ref.watch(printQueueProvider);
  return queueState.jobs.where((job) => job.status.isActive).toList();
});

final completedPrintJobsProvider = Provider<List<PrintJob>>((ref) {
  final queueState = ref.watch(printQueueProvider);
  return queueState.jobs.where((job) => job.status.isTerminal).toList();
});
