class PrintSettings {
  const PrintSettings({
    this.copies = 1,
    this.paperSize = 'iso_a4_210x297mm',
    this.landscape = false,
    this.color = true,
    this.duplex = false,
    this.firstPage = 1,
    this.lastPage,
  });

  final int copies;
  final String paperSize;
  final bool landscape;
  final bool color;
  final bool duplex;
  final int firstPage;
  final int? lastPage;
}

class PrintRequest {
  const PrintRequest({
    required this.jobName,
    required this.filePath,
    required this.mimeType,
    required this.printerId,
    this.settings = const PrintSettings(),
  });

  final String jobName;
  final String filePath;
  final String mimeType;
  final String printerId;
  final PrintSettings settings;
}
