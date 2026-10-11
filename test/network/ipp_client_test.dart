import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:bureprint/core/ipp/ipp_codec.dart';
import 'package:bureprint/core/ipp/ipp_constants.dart';
import 'package:bureprint/core/ipp/ipp_message.dart';
import 'package:bureprint/core/network/ipp_http_transport.dart';
import 'package:bureprint/data/ipp/ipp_client.dart';
import 'package:bureprint/domain/models/printer_capabilities.dart';
import 'package:bureprint/domain/models/printer_device.dart';

class FakeIppHttpTransport implements IppHttpTransport {
  FakeIppHttpTransport(this.handler);

  final Uint8List Function(
          Uri endpoint, Uint8List requestBytes, TransportSecurityPolicy policy)
      handler;

  @override
  Future<Uint8List> sendIppRequest({
    required Uri endpoint,
    required Uint8List requestBytes,
    required TransportSecurityPolicy securityPolicy,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    return handler(endpoint, requestBytes, securityPolicy);
  }
}

void main() {
  const codec = IppCodec();

  const testPrinter = PrinterDevice(
    id: 'test-printer-1',
    name: 'HP LaserJet 400',
    connectionType: PrinterConnectionType.network,
    host: '192.168.1.100',
    port: 631,
    resourcePath: '/ipp/print',
    securityPolicy: TransportSecurityPolicy.ippsStrict,
  );

  group('IppClient Capability Query & Dynamic Submission', () {
    test('queries Get-Printer-Attributes and extracts capabilities', () async {
      final fakeTransport = FakeIppHttpTransport((endpoint, reqBytes, policy) {
        expect(policy, equals(TransportSecurityPolicy.ippsStrict));
        expect(endpoint.scheme, equals('ipps'));

        // Return a mock response with supported operations and formats
        const response = IppMessage(
          operationOrStatus: IppConstants.statusSuccessfulOk,
          requestId: 1,
          attributeGroups: [
            IppAttributeGroup(
              tag: IppConstants.printerAttributesTag,
              attributes: [
                IppAttribute(
                  name: 'printer-name',
                  tag: IppConstants.tagNameWithoutLanguage,
                  values: ['HP LaserJet 400'],
                ),
                IppAttribute(
                  name: 'operations-supported',
                  tag: IppConstants.tagEnum,
                  values: [
                    0x0002,
                    0x0005,
                    0x0006
                  ], // Print-Job, Create-Job, Send-Document
                ),
                IppAttribute(
                  name: 'document-format-supported',
                  tag: IppConstants.tagMimeMediaType,
                  values: ['application/pdf', 'image/pwg-raster'],
                ),
              ],
            ),
          ],
        );
        return codec.encode(response);
      });

      final client = IppClient(transport: fakeTransport);
      final capabilities = await client.getCapabilities(testPrinter);

      expect(capabilities.printerName, equals('HP LaserJet 400'));
      expect(capabilities.supportsTwoStepJob, isTrue);
      expect(capabilities.supportsPdf, isTrue);
    });

    test('selects two-step Create-Job + Send-Document when supported',
        () async {
      int requestCount = 0;
      final fakeTransport = FakeIppHttpTransport((endpoint, reqBytes, policy) {
        final reqMsg = codec.decode(reqBytes);
        requestCount++;

        if (reqMsg.operationOrStatus == IppConstants.opCreateJob) {
          final res = IppMessage(
            operationOrStatus: IppConstants.statusSuccessfulOk,
            requestId: reqMsg.requestId,
            attributeGroups: const [
              IppAttributeGroup(
                tag: IppConstants.jobAttributesTag,
                attributes: [
                  IppAttribute(
                    name: 'job-id',
                    tag: IppConstants.tagInteger,
                    values: [456],
                  ),
                ],
              ),
            ],
          );
          return codec.encode(res);
        } else if (reqMsg.operationOrStatus == IppConstants.opSendDocument) {
          final res = IppMessage(
            operationOrStatus: IppConstants.statusSuccessfulOk,
            requestId: reqMsg.requestId,
          );
          return codec.encode(res);
        }
        throw UnimplementedError();
      });

      final client = IppClient(transport: fakeTransport);
      const capabilities = PrinterCapabilities(
        operationsSupported: [0x0005, 0x0006], // Create-Job & Send-Document
        documentFormats: ['application/pdf'],
      );

      final jobId = await client.submitJob(
        printer: testPrinter,
        capabilities: capabilities,
        jobName: 'Contract.pdf',
        mimeType: 'application/pdf',
        documentBytes: [0x25, 0x50, 0x44, 0x46],
      );

      expect(jobId, equals(456));
      expect(requestCount,
          equals(2)); // Both Create-Job and Send-Document were dispatched
    });

    test('falls back to single-step Print-Job when Create-Job is unsupported',
        () async {
      int requestCount = 0;
      final fakeTransport = FakeIppHttpTransport((endpoint, reqBytes, policy) {
        final reqMsg = codec.decode(reqBytes);
        requestCount++;

        expect(reqMsg.operationOrStatus, equals(IppConstants.opPrintJob));
        final res = IppMessage(
          operationOrStatus: IppConstants.statusSuccessfulOk,
          requestId: reqMsg.requestId,
          attributeGroups: const [
            IppAttributeGroup(
              tag: IppConstants.jobAttributesTag,
              attributes: [
                IppAttribute(
                  name: 'job-id',
                  tag: IppConstants.tagInteger,
                  values: [789],
                ),
              ],
            ),
          ],
        );
        return codec.encode(res);
      });

      final client = IppClient(transport: fakeTransport);
      const capabilities = PrinterCapabilities(
        operationsSupported: [0x0002], // Print-Job only
        documentFormats: ['application/pdf'],
      );

      final jobId = await client.submitJob(
        printer: testPrinter,
        capabilities: capabilities,
        jobName: 'Memo.pdf',
        mimeType: 'application/pdf',
        documentBytes: [0x25, 0x50, 0x44, 0x46],
      );

      expect(jobId, equals(789));
      expect(requestCount, equals(1));
    });

    test(
        'fails safely and throws exception when printer does not support requested MIME type',
        () async {
      final fakeTransport = FakeIppHttpTransport((endpoint, reqBytes, policy) {
        throw StateError('Should not be reached');
      });

      final client = IppClient(transport: fakeTransport);
      const rasterOnlyCapabilities = PrinterCapabilities(
        operationsSupported: [0x0002],
        documentFormats: ['image/pwg-raster'], // Does NOT support PDF
      );

      expect(
        () => client.submitJob(
          printer: testPrinter,
          capabilities: rasterOnlyCapabilities,
          jobName: 'Doc.pdf',
          mimeType: 'application/pdf',
          documentBytes: [0x25, 0x50, 0x44, 0x46],
        ),
        throwsA(isA<IppException>()),
      );
    });
  });
}
