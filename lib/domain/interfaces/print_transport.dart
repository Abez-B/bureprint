import '../models/print_request.dart';

class PrintJobResult {
  const PrintJobResult({
    required this.jobId,
    required this.accepted,
    this.message,
  });

  final String jobId;
  final bool accepted;
  final String? message;
}

abstract interface class PrintTransport {
  Future<PrintJobResult> submit(PrintRequest request);
  Future<void> cancel(String jobId);
}
