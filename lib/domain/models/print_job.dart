enum PrintJobStatus {
  queued,
  preparing,
  submitting,
  printing,
  completed,
  failed,
  canceled,
}

class PrintJob {
  const PrintJob({
    required this.id,
    required this.name,
    required this.status,
    this.message,
  });

  final String id;
  final String name;
  final PrintJobStatus status;
  final String? message;
}
