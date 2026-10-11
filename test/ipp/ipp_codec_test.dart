import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

import 'package:bureprint/core/ipp/ipp_codec.dart';
import 'package:bureprint/core/ipp/ipp_constants.dart';
import 'package:bureprint/core/ipp/ipp_message.dart';
import '../fixtures/mock_ipp_attributes.dart';

void main() {
  const codec = IppCodec();

  group('IppCodec Binary Decoding', () {
    test(
        'successfully decodes standard binary Get-Printer-Attributes response fixture',
        () {
      final bytes = Uint8List.fromList(mockIppGetAttributesResponse);
      final message = codec.decode(bytes);

      expect(message.majorVersion, equals(1));
      expect(message.minorVersion, equals(1));
      expect(
          message.operationOrStatus, equals(IppConstants.statusSuccessfulOk));
      expect(message.requestId, equals(1));

      // Operation attributes group
      final charset = message.findAttribute('attributes-charset');
      expect(charset, isNotNull);
      expect(charset!.tag, equals(IppConstants.tagCharset));
      expect(charset.value, equals('utf-8'));

      // Printer attributes group
      final printerName = message.findAttribute('printer-name');
      expect(printerName, isNotNull);
      expect(printerName!.value, equals('OfficeJet '));
    });

    test(
        'throws IppMalformedMessageException when decoding truncated packet header',
        () {
      final truncatedBytes = Uint8List.fromList([0x01, 0x01, 0x00]);
      expect(
        () => codec.decode(truncatedBytes),
        throwsA(isA<IppMalformedMessageException>()),
      );
    });

    test(
        'throws IppMalformedMessageException when attribute name length exceeds payload',
        () {
      final corruptBytes = Uint8List.fromList([
        0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, // header
        0x01, // group tag
        0x47, // charset tag
        0x00, 0xFF, // name length declared as 255 but no bytes follow
      ]);
      expect(
        () => codec.decode(corruptBytes),
        throwsA(isA<IppMalformedMessageException>()),
      );
    });
  });

  group('IppCodec Binary Encoding & Round-Trip', () {
    test(
        'encodes and round-trips Get-Printer-Attributes request message with repeated attributes',
        () {
      const request = IppMessage(
        majorVersion: 1,
        minorVersion: 1,
        operationOrStatus: IppConstants.opGetPrinterAttributes,
        requestId: 42,
        attributeGroups: [
          IppAttributeGroup(
            tag: IppConstants.operationAttributesTag,
            attributes: [
              IppAttribute(
                name: 'attributes-charset',
                tag: IppConstants.tagCharset,
                values: ['utf-8'],
              ),
              IppAttribute(
                name: 'attributes-natural-language',
                tag: IppConstants.tagNaturalLanguage,
                values: ['en'],
              ),
              IppAttribute(
                name: 'printer-uri',
                tag: IppConstants.tagUri,
                values: ['ipp://192.168.1.50:631/ipp/print'],
              ),
              IppAttribute(
                name: 'requested-attributes',
                tag: IppConstants.tagKeyword,
                values: [
                  'printer-name',
                  'operations-supported',
                  'document-format-supported',
                ],
              ),
            ],
          ),
        ],
      );

      final encoded = codec.encode(request);
      final decoded = codec.decode(encoded);

      expect(decoded.operationOrStatus,
          equals(IppConstants.opGetPrinterAttributes));
      expect(decoded.requestId, equals(42));

      final reqAttrs = decoded.findAttribute('requested-attributes');
      expect(reqAttrs, isNotNull);
      expect(reqAttrs!.values.length, equals(3));
      expect(
          reqAttrs.values,
          equals([
            'printer-name',
            'operations-supported',
            'document-format-supported',
          ]));
    });

    test(
        'preserves attached document payload data during encoding and decoding',
        () {
      final documentPayload = [
        0x25,
        0x50,
        0x44,
        0x46,
        0x2d,
        0x31,
        0x2e,
        0x34
      ]; // "%PDF-1.4"
      final printJobMessage = IppMessage(
        operationOrStatus: IppConstants.opPrintJob,
        requestId: 99,
        attributeGroups: const [
          IppAttributeGroup(
            tag: IppConstants.operationAttributesTag,
            attributes: [
              IppAttribute(
                name: 'document-format',
                tag: IppConstants.tagMimeMediaType,
                values: ['application/pdf'],
              ),
            ],
          ),
        ],
        data: documentPayload,
      );

      final encoded = codec.encode(printJobMessage);
      final decoded = codec.decode(encoded);

      expect(decoded.data, equals(documentPayload));
      expect(decoded.findAttribute('document-format')?.value,
          equals('application/pdf'));
    });
  });
}
