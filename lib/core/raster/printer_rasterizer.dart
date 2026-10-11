import 'dart:typed_data';

import '../../domain/models/print_request.dart';
import '../../domain/models/printer_device.dart';

/// Abstract domain interface for printer page rasterization and protocol encoding.
///
/// Implementations of this interface translate rendered document bitmaps or raw data
/// into specific printer control languages (e.g. Brother PJL / brlaser, PWG-Raster,
/// PCL, ESC/P-R, ESC/POS, etc.).
abstract interface class PrinterRasterizer {
  /// Unique identifier of this driver (e.g., 'driver.brother.pjl', 'driver.pwg_raster').
  String get id;

  /// Human-readable brand / driver name.
  String get displayName;

  /// Determines whether this driver is capable of communicating with [device].
  bool canHandle(PrinterDevice device);

  /// Generates session / job header bytes (e.g. PJL header, resolution, media setup).
  List<int> createJobHeader(PrintSettings settings, String jobName);

  /// Encodes a single rasterized page into the printer's native command language.
  ///
  /// [pixelBytes]: Raw 1-bit or 8-bit bitmap byte data of the rendered sheet.
  /// [widthPixels]: Width of the bitmap in pixels.
  /// [heightPixels]: Height of the bitmap in pixels.
  /// [linesize]: Width in bytes per row (typically (widthPixels + 7) ~/ 8 for 1-bit).
  List<int> encodePage({
    required Uint8List pixelBytes,
    required int widthPixels,
    required int heightPixels,
    required int linesize,
    required PrintSettings settings,
    required int pageIndex,
    required int totalPages,
  });

  /// Generates session footer / end-of-job bytes.
  List<int> createJobFooter(String jobName);
}
