import 'dart:convert';
import 'dart:typed_data';

import 'ipp_constants.dart';
import 'ipp_message.dart';

/// Pure Dart binary encoder and decoder for RFC 8010 IPP frames.
class IppCodec {
  const IppCodec();

  /// Encodes an [IppMessage] into binary bytes.
  Uint8List encode(IppMessage message) {
    final builder = BytesBuilder();

    // 1. Version (2 bytes)
    builder.addByte(message.majorVersion);
    builder.addByte(message.minorVersion);

    // 2. Operation ID or Status Code (2 bytes, big-endian)
    final opBytes = ByteData(2)
      ..setInt16(0, message.operationOrStatus, Endian.big);
    builder.add(opBytes.buffer.asUint8List());

    // 3. Request ID (4 bytes, big-endian)
    final reqBytes = ByteData(4)..setInt32(0, message.requestId, Endian.big);
    builder.add(reqBytes.buffer.asUint8List());

    // 4. Attribute Groups
    for (final group in message.attributeGroups) {
      builder.addByte(group.tag);
      for (final attr in group.attributes) {
        _encodeAttribute(builder, attr);
      }
    }

    // 5. End of Attributes Tag
    builder.addByte(IppConstants.endOfAttributesTag);

    // 6. Data payload
    if (message.data.isNotEmpty) {
      builder.add(message.data);
    }

    return builder.toBytes();
  }

  void _encodeAttribute(BytesBuilder builder, IppAttribute attr) {
    if (attr.values.isEmpty) {
      // Out-of-band attribute without values
      builder.addByte(attr.tag);
      _writeString(builder, attr.name);
      _writeUint16(builder, 0); // Value length = 0
      return;
    }

    for (int i = 0; i < attr.values.length; i++) {
      builder.addByte(attr.tag);
      if (i == 0) {
        _writeString(builder, attr.name);
      } else {
        // Repeated attribute: name length is 0
        _writeUint16(builder, 0);
      }
      _encodeValue(builder, attr.tag, attr.values[i]);
    }
  }

  void _encodeValue(BytesBuilder builder, int tag, dynamic value) {
    switch (tag) {
      case IppConstants.tagInteger:
      case IppConstants.tagEnum:
        _writeUint16(builder, 4);
        final data = ByteData(4)..setInt32(0, value as int, Endian.big);
        builder.add(data.buffer.asUint8List());
        break;
      case IppConstants.tagBoolean:
        _writeUint16(builder, 1);
        builder.addByte((value as bool) ? 1 : 0);
        break;
      case IppConstants.tagOctetString:
        final bytes = value as List<int>;
        _writeUint16(builder, bytes.length);
        builder.add(bytes);
        break;
      case IppConstants.tagTextWithoutLanguage:
      case IppConstants.tagNameWithoutLanguage:
      case IppConstants.tagKeyword:
      case IppConstants.tagUri:
      case IppConstants.tagUriScheme:
      case IppConstants.tagCharset:
      case IppConstants.tagNaturalLanguage:
      case IppConstants.tagMimeMediaType:
        _writeString(builder, value as String);
        break;
      case IppConstants.tagNoValue:
      case IppConstants.tagUnknown:
      case IppConstants.tagUnsupported:
        _writeUint16(builder, 0);
        break;
      default:
        if (value is String) {
          _writeString(builder, value);
        } else if (value is List<int>) {
          _writeUint16(builder, value.length);
          builder.add(value);
        } else {
          _writeUint16(builder, 0);
        }
    }
  }

  void _writeString(BytesBuilder builder, String text) {
    final bytes = utf8.encode(text);
    _writeUint16(builder, bytes.length);
    builder.add(bytes);
  }

  void _writeUint16(BytesBuilder builder, int val) {
    final bytes = ByteData(2)..setUint16(0, val, Endian.big);
    builder.add(bytes.buffer.asUint8List());
  }

  /// Decodes raw binary bytes into an [IppMessage].
  IppMessage decode(Uint8List bytes) {
    if (bytes.length < 9) {
      throw const IppMalformedMessageException(
        'Packet too short to contain valid IPP header (minimum 9 bytes required)',
      );
    }

    final byteData = ByteData.sublistView(bytes);
    int offset = 0;

    final majorVersion = byteData.getUint8(offset++);
    final minorVersion = byteData.getUint8(offset++);
    final operationOrStatus = byteData.getInt16(offset, Endian.big);
    offset += 2;
    final requestId = byteData.getInt32(offset, Endian.big);
    offset += 4;

    final List<IppAttributeGroup> attributeGroups = [];
    IppAttributeGroup? currentGroup;
    final List<IppAttribute> currentAttributes = [];
    IppAttribute? currentAttribute;

    while (offset < bytes.length) {
      final tag = byteData.getUint8(offset++);

      if (tag == IppConstants.endOfAttributesTag) {
        if (currentGroup != null) {
          attributeGroups.add(
            IppAttributeGroup(
              tag: currentGroup.tag,
              attributes: List.unmodifiable(currentAttributes),
            ),
          );
        }
        break;
      }

      // Check for attribute group delimiter tags (0x01 - 0x0F)
      if (tag >= 0x01 && tag <= 0x0F) {
        if (currentGroup != null) {
          attributeGroups.add(
            IppAttributeGroup(
              tag: currentGroup.tag,
              attributes: List.unmodifiable(currentAttributes),
            ),
          );
          currentAttributes.clear();
        }
        currentGroup = IppAttributeGroup(tag: tag, attributes: const []);
        currentAttribute = null;
        continue;
      }

      // Value tag encountered: parse attribute name and value
      if (offset + 2 > bytes.length) {
        throw const IppMalformedMessageException(
            'Unexpected EOF reading attribute name length');
      }
      final nameLength = byteData.getUint16(offset, Endian.big);
      offset += 2;

      String name = '';
      if (nameLength > 0) {
        if (offset + nameLength > bytes.length) {
          throw const IppMalformedMessageException(
              'Unexpected EOF reading attribute name');
        }
        name = utf8.decode(bytes.sublist(offset, offset + nameLength));
        offset += nameLength;
      }

      if (offset + 2 > bytes.length) {
        throw const IppMalformedMessageException(
            'Unexpected EOF reading attribute value length');
      }
      final valueLength = byteData.getUint16(offset, Endian.big);
      offset += 2;

      dynamic parsedValue;
      if (valueLength > 0) {
        if (offset + valueLength > bytes.length) {
          throw const IppMalformedMessageException(
              'Unexpected EOF reading attribute value');
        }
        parsedValue = _decodeValue(bytes, byteData, offset, tag, valueLength);
        offset += valueLength;
      } else {
        parsedValue = null;
      }

      if (name.isNotEmpty) {
        // New attribute
        currentAttribute = IppAttribute(
          name: name,
          tag: tag,
          values: parsedValue != null ? [parsedValue] : [],
        );
        currentAttributes.add(currentAttribute);
      } else if (currentAttribute != null) {
        // Continuation / repeated value for previous attribute
        currentAttribute.values.add(parsedValue);
      }
    }

    final dataPayload =
        offset < bytes.length ? bytes.sublist(offset) : const <int>[];

    return IppMessage(
      majorVersion: majorVersion,
      minorVersion: minorVersion,
      operationOrStatus: operationOrStatus,
      requestId: requestId,
      attributeGroups: List.unmodifiable(attributeGroups),
      data: dataPayload,
    );
  }

  dynamic _decodeValue(
    Uint8List bytes,
    ByteData byteData,
    int offset,
    int tag,
    int length,
  ) {
    switch (tag) {
      case IppConstants.tagInteger:
      case IppConstants.tagEnum:
        if (length == 4) {
          return byteData.getInt32(offset, Endian.big);
        }
        return byteData.getInt16(offset, Endian.big);
      case IppConstants.tagBoolean:
        return byteData.getUint8(offset) != 0;
      case IppConstants.tagOctetString:
        return bytes.sublist(offset, offset + length);
      case IppConstants.tagTextWithoutLanguage:
      case IppConstants.tagNameWithoutLanguage:
      case IppConstants.tagKeyword:
      case IppConstants.tagUri:
      case IppConstants.tagUriScheme:
      case IppConstants.tagCharset:
      case IppConstants.tagNaturalLanguage:
      case IppConstants.tagMimeMediaType:
        return utf8.decode(bytes.sublist(offset, offset + length));
      default:
        try {
          return utf8.decode(bytes.sublist(offset, offset + length));
        } catch (_) {
          return bytes.sublist(offset, offset + length);
        }
    }
  }
}
