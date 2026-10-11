import 'package:flutter/foundation.dart';

/// Comprehensive print job lifecycle state machine.
enum PrintJobStatus {
  queuedLocally,
  preparingDocument,
  convertingDocument,
  submittingToPrinter,
  acceptedByPrinter,
  printing,
  completed,
  failed,
  cancellationRequested,
  canceled,
  statusUnknown;

  bool get isActive =>
      this == queuedLocally ||
      this == preparingDocument ||
      this == convertingDocument ||
      this == submittingToPrinter ||
      this == acceptedByPrinter ||
      this == printing ||
      this == cancellationRequested;

  bool get isTerminal =>
      this == completed || this == failed || this == canceled;
}

@immutable
class PrintJob {
  const PrintJob({
    required this.id,
    required this.name,
    required this.status,
    required this.printerId,
    required this.printerName,
    required this.createdAt,
    this.message,
    this.pageCount,
    this.copies = 1,
    this.sheetsCompleted,
    this.updatedAt,
  });

  final String id;
  final String name;
  final PrintJobStatus status;
  final String printerId;
  final String printerName;
  final DateTime createdAt;
  final String? message;
  final int? pageCount;
  final int copies;
  final int? sheetsCompleted;
  final DateTime? updatedAt;

  PrintJob copyWith({
    String? id,
    String? name,
    PrintJobStatus? status,
    String? printerId,
    String? printerName,
    DateTime? createdAt,
    String? message,
    int? pageCount,
    int? copies,
    int? sheetsCompleted,
    DateTime? updatedAt,
  }) {
    return PrintJob(
      id: id ?? this.id,
      name: name ?? this.name,
      status: status ?? this.status,
      printerId: printerId ?? this.printerId,
      printerName: printerName ?? this.printerName,
      createdAt: createdAt ?? this.createdAt,
      message: message ?? this.message,
      pageCount: pageCount ?? this.pageCount,
      copies: copies ?? this.copies,
      sheetsCompleted: sheetsCompleted ?? this.sheetsCompleted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status.name,
        'printerId': printerId,
        'printerName': printerName,
        'createdAt': createdAt.toIso8601String(),
        if (message != null) 'message': message,
        if (pageCount != null) 'pageCount': pageCount,
        'copies': copies,
        if (sheetsCompleted != null) 'sheetsCompleted': sheetsCompleted,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory PrintJob.fromJson(Map<String, dynamic> json) {
    return PrintJob(
      id: json['id'] as String,
      name: json['name'] as String,
      status: PrintJobStatus.values.byName(json['status'] as String),
      printerId: json['printerId'] as String,
      printerName: json['printerName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      message: json['message'] as String?,
      pageCount: json['pageCount'] as int?,
      copies: json['copies'] as int? ?? 1,
      sheetsCompleted: json['sheetsCompleted'] as int?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrintJob &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          status == other.status &&
          printerId == other.printerId &&
          printerName == other.printerName &&
          createdAt == other.createdAt &&
          message == other.message &&
          pageCount == other.pageCount &&
          copies == other.copies &&
          sheetsCompleted == other.sheetsCompleted &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        status,
        printerId,
        printerName,
        createdAt,
        message,
        pageCount,
        copies,
        sheetsCompleted,
        updatedAt,
      );
}
