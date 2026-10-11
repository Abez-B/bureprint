import '../../domain/models/print_job.dart';

abstract interface class PrintJobQueueStorage {
  Future<List<PrintJob>> loadJobs();
  Future<void> saveJobs(List<PrintJob> jobs);
}

/// In-memory storage implementation for tests and default state.
class InMemoryPrintJobQueueStorage implements PrintJobQueueStorage {
  InMemoryPrintJobQueueStorage([List<PrintJob>? initialJobs])
      : _jobs = List.from(initialJobs ?? const []);

  List<PrintJob> _jobs;

  @override
  Future<List<PrintJob>> loadJobs() async {
    return List.unmodifiable(_jobs);
  }

  @override
  Future<void> saveJobs(List<PrintJob> jobs) async {
    _jobs = List.from(jobs);
  }
}
