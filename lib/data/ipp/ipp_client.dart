import '../../core/ipp/ipp_codec.dart';
import '../../core/ipp/ipp_constants.dart';
import '../../core/ipp/ipp_message.dart';
import '../../core/network/ipp_http_transport.dart';
import '../../domain/interfaces/printer_capabilities_provider.dart';
import '../../domain/models/printer_capabilities.dart';
import '../../domain/models/printer_device.dart';

class IppClient implements PrinterCapabilitiesProvider {
  IppClient({
    this.codec = const IppCodec(),
    IppHttpTransport? transport,
  }) : transport = transport ?? const StandardIppHttpTransport();

  final IppCodec codec;
  final IppHttpTransport transport;
  int _requestIdCounter = 1;

  int _nextRequestId() => _requestIdCounter++;

  @override
  Future<PrinterCapabilities> getCapabilities(PrinterDevice printer) async {
    final uri = Uri.parse(printer.endpointUri);
    final reqId = _nextRequestId();

    final request = IppMessage(
      operationOrStatus: IppConstants.opGetPrinterAttributes,
      requestId: reqId,
      attributeGroups: [
        IppAttributeGroup(
          tag: IppConstants.operationAttributesTag,
          attributes: [
            const IppAttribute(
              name: 'attributes-charset',
              tag: IppConstants.tagCharset,
              values: ['utf-8'],
            ),
            const IppAttribute(
              name: 'attributes-natural-language',
              tag: IppConstants.tagNaturalLanguage,
              values: ['en'],
            ),
            IppAttribute(
              name: 'printer-uri',
              tag: IppConstants.tagUri,
              values: [printer.endpointUri],
            ),
            const IppAttribute(
              name: 'requested-attributes',
              tag: IppConstants.tagKeyword,
              values: [
                'printer-name',
                'printer-make-and-model',
                'printer-state',
                'printer-state-reasons',
                'operations-supported',
                'document-format-supported',
                'media-supported',
                'sides-supported',
                'color-supported',
                'copies-supported',
              ],
            ),
          ],
        ),
      ],
    );

    final reqBytes = codec.encode(request);
    final resBytes = await transport.sendIppRequest(
      endpoint: uri,
      requestBytes: reqBytes,
      securityPolicy: printer.securityPolicy,
    );

    final response = codec.decode(resBytes);
    return _parseCapabilities(response);
  }

  PrinterCapabilities _parseCapabilities(IppMessage response) {
    final name = response.findAttribute('printer-name')?.value as String?;
    final makeAndModel =
        response.findAttribute('printer-make-and-model')?.value as String?;
    final state =
        response.findAttribute('printer-state')?.value as String? ?? 'idle';
    final stateReasons =
        response.findAttributeValues('printer-state-reasons').cast<String>();

    final opsSupported = response
        .findAttributeValues('operations-supported')
        .whereType<int>()
        .toList();

    final docFormats = response
        .findAttributeValues('document-format-supported')
        .whereType<String>()
        .toList();

    final paperSizes = response
        .findAttributeValues('media-supported')
        .whereType<String>()
        .toList();

    final sides = response
        .findAttributeValues('sides-supported')
        .whereType<String>()
        .toList();
    final supportsDuplex = sides.any((s) => s.contains('two-sided'));

    final colorSupported =
        response.findAttribute('color-supported')?.value as bool? ?? false;
    final copiesMax =
        response.findAttribute('copies-supported')?.value as int? ?? 1;

    // Parse marker supply levels (marker-names, marker-colors, marker-levels)
    final markerNames = response
        .findAttributeValues('marker-names')
        .whereType<String>()
        .toList();
    final markerColors = response
        .findAttributeValues('marker-colors')
        .whereType<String>()
        .toList();
    final markerLevels =
        response.findAttributeValues('marker-levels').whereType<int>().toList();

    final supplies = <PrinterSupplyLevel>[];
    for (int i = 0; i < markerNames.length; i++) {
      final name = markerNames[i];
      final colorHex = i < markerColors.length ? markerColors[i] : '#000000';
      final level = i < markerLevels.length ? markerLevels[i] : -1;
      supplies.add(PrinterSupplyLevel(
        name: name,
        colorHex: colorHex.startsWith('#') ? colorHex : '#$colorHex',
        levelPercent: level,
      ));
    }

    return PrinterCapabilities(
      printerName: name,
      printerMakeAndModel: makeAndModel,
      printerState: state,
      printerStateReasons: stateReasons,
      operationsSupported: opsSupported,
      documentFormats: docFormats,
      paperSizes: paperSizes,
      supportsColor: colorSupported,
      supportsDuplex: supportsDuplex,
      copiesSupportedMax: copiesMax,
      markerSupplies: supplies,
    );
  }

  /// Capability-driven print job submission
  Future<int> submitJob({
    required PrinterDevice printer,
    required PrinterCapabilities capabilities,
    required String jobName,
    required String mimeType,
    required List<int> documentBytes,
    int copies = 1,
  }) async {
    final uri = Uri.parse(printer.endpointUri);

    // Capability check: reject if printer explicitly does not support the MIME type
    if (capabilities.documentFormats.isNotEmpty &&
        !capabilities.documentFormats.contains(mimeType)) {
      throw IppException(
        'Printer does not support document format "$mimeType". Supported formats: ${capabilities.documentFormats.join(', ')}',
      );
    }

    if (capabilities.supportsTwoStepJob) {
      // 1. Two-step submission: Create-Job + Send-Document
      return _submitTwoStepJob(
        uri: uri,
        printer: printer,
        jobName: jobName,
        mimeType: mimeType,
        documentBytes: documentBytes,
        copies: copies,
      );
    } else if (capabilities.supportsPrintJob) {
      // 2. Single-step submission: Print-Job
      return _submitSingleStepJob(
        uri: uri,
        printer: printer,
        jobName: jobName,
        mimeType: mimeType,
        documentBytes: documentBytes,
        copies: copies,
      );
    } else {
      throw const IppException(
        'Printer supports neither Create-Job (0x0005) nor Print-Job (0x0002) operations',
      );
    }
  }

  Future<int> _submitSingleStepJob({
    required Uri uri,
    required PrinterDevice printer,
    required String jobName,
    required String mimeType,
    required List<int> documentBytes,
    required int copies,
  }) async {
    final reqId = _nextRequestId();
    final message = IppMessage(
      operationOrStatus: IppConstants.opPrintJob,
      requestId: reqId,
      attributeGroups: [
        IppAttributeGroup(
          tag: IppConstants.operationAttributesTag,
          attributes: [
            const IppAttribute(
              name: 'attributes-charset',
              tag: IppConstants.tagCharset,
              values: ['utf-8'],
            ),
            const IppAttribute(
              name: 'attributes-natural-language',
              tag: IppConstants.tagNaturalLanguage,
              values: ['en'],
            ),
            IppAttribute(
              name: 'printer-uri',
              tag: IppConstants.tagUri,
              values: [printer.endpointUri],
            ),
            IppAttribute(
              name: 'job-name',
              tag: IppConstants.tagNameWithoutLanguage,
              values: [jobName],
            ),
            IppAttribute(
              name: 'document-format',
              tag: IppConstants.tagMimeMediaType,
              values: [mimeType],
            ),
          ],
        ),
        IppAttributeGroup(
          tag: IppConstants.jobAttributesTag,
          attributes: [
            IppAttribute(
              name: 'copies',
              tag: IppConstants.tagInteger,
              values: [copies],
            ),
          ],
        ),
      ],
      data: documentBytes,
    );

    final reqBytes = codec.encode(message);
    final resBytes = await transport.sendIppRequest(
      endpoint: uri,
      requestBytes: reqBytes,
      securityPolicy: printer.securityPolicy,
    );

    final response = codec.decode(resBytes);
    if (response.operationOrStatus != IppConstants.statusSuccessfulOk &&
        response.operationOrStatus !=
            IppConstants.statusSuccessfulOkIgnoredOrSubstituted) {
      throw IppException(
        'Print-Job operation rejected by printer with status code: 0x${response.operationOrStatus.toRadixString(16)}',
      );
    }

    final jobId = response.findAttribute('job-id')?.value as int? ?? reqId;
    return jobId;
  }

  Future<int> _submitTwoStepJob({
    required Uri uri,
    required PrinterDevice printer,
    required String jobName,
    required String mimeType,
    required List<int> documentBytes,
    required int copies,
  }) async {
    // Step 1: Create-Job
    final createReqId = _nextRequestId();
    final createMessage = IppMessage(
      operationOrStatus: IppConstants.opCreateJob,
      requestId: createReqId,
      attributeGroups: [
        IppAttributeGroup(
          tag: IppConstants.operationAttributesTag,
          attributes: [
            const IppAttribute(
              name: 'attributes-charset',
              tag: IppConstants.tagCharset,
              values: ['utf-8'],
            ),
            const IppAttribute(
              name: 'attributes-natural-language',
              tag: IppConstants.tagNaturalLanguage,
              values: ['en'],
            ),
            IppAttribute(
              name: 'printer-uri',
              tag: IppConstants.tagUri,
              values: [printer.endpointUri],
            ),
            IppAttribute(
              name: 'job-name',
              tag: IppConstants.tagNameWithoutLanguage,
              values: [jobName],
            ),
          ],
        ),
        IppAttributeGroup(
          tag: IppConstants.jobAttributesTag,
          attributes: [
            IppAttribute(
              name: 'copies',
              tag: IppConstants.tagInteger,
              values: [copies],
            ),
          ],
        ),
      ],
    );

    final createResBytes = await transport.sendIppRequest(
      endpoint: uri,
      requestBytes: codec.encode(createMessage),
      securityPolicy: printer.securityPolicy,
    );
    final createResponse = codec.decode(createResBytes);
    final jobId =
        createResponse.findAttribute('job-id')?.value as int? ?? createReqId;

    // Step 2: Send-Document
    final sendReqId = _nextRequestId();
    final sendMessage = IppMessage(
      operationOrStatus: IppConstants.opSendDocument,
      requestId: sendReqId,
      attributeGroups: [
        IppAttributeGroup(
          tag: IppConstants.operationAttributesTag,
          attributes: [
            const IppAttribute(
              name: 'attributes-charset',
              tag: IppConstants.tagCharset,
              values: ['utf-8'],
            ),
            const IppAttribute(
              name: 'attributes-natural-language',
              tag: IppConstants.tagNaturalLanguage,
              values: ['en'],
            ),
            IppAttribute(
              name: 'printer-uri',
              tag: IppConstants.tagUri,
              values: [printer.endpointUri],
            ),
            IppAttribute(
              name: 'job-id',
              tag: IppConstants.tagInteger,
              values: [jobId],
            ),
            const IppAttribute(
              name: 'last-document',
              tag: IppConstants.tagBoolean,
              values: [true],
            ),
            IppAttribute(
              name: 'document-format',
              tag: IppConstants.tagMimeMediaType,
              values: [mimeType],
            ),
          ],
        ),
      ],
      data: documentBytes,
    );

    final sendResBytes = await transport.sendIppRequest(
      endpoint: uri,
      requestBytes: codec.encode(sendMessage),
      securityPolicy: printer.securityPolicy,
    );
    final sendResponse = codec.decode(sendResBytes);

    if (sendResponse.operationOrStatus != IppConstants.statusSuccessfulOk &&
        sendResponse.operationOrStatus !=
            IppConstants.statusSuccessfulOkIgnoredOrSubstituted) {
      throw IppException(
        'Send-Document rejected by printer with status code: 0x${sendResponse.operationOrStatus.toRadixString(16)}',
      );
    }

    return jobId;
  }
}
