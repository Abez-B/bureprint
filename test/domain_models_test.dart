import 'package:bureprint/domain/models/print_job.dart';
import 'package:bureprint/domain/models/print_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Print domain models', () {
    test('default print settings are conservative', () {
      const settings = PrintSettings();
      expect(settings.copies, 1);
      expect(settings.paperSize, 'iso_a4_210x297mm');
      expect(settings.landscape, isFalse);
      expect(settings.duplex, isFalse);
    });

    test('job statuses include a failed state', () {
      expect(PrintJobStatus.values, contains(PrintJobStatus.failed));
      expect(PrintJobStatus.values, contains(PrintJobStatus.completed));
    });
  });
}
