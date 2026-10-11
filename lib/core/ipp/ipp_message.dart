import 'package:flutter/foundation.dart';

@immutable
class IppAttribute {
  const IppAttribute({
    required this.name,
    required this.tag,
    required this.values,
  });

  final String name;
  final int tag;
  final List<dynamic> values;

  dynamic get value => values.isNotEmpty ? values.first : null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IppAttribute &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          tag == other.tag &&
          listEquals(values, other.values);

  @override
  int get hashCode => Object.hash(name, tag, Object.hashAll(values));

  @override
  String toString() =>
      'IppAttribute($name, tag: 0x${tag.toRadixString(16)}, values: $values)';
}

@immutable
class IppAttributeGroup {
  const IppAttributeGroup({
    required this.tag,
    required this.attributes,
  });

  final int tag;
  final List<IppAttribute> attributes;

  IppAttribute? getAttribute(String name) {
    for (final attr in attributes) {
      if (attr.name == name) return attr;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IppAttributeGroup &&
          runtimeType == other.runtimeType &&
          tag == other.tag &&
          listEquals(attributes, other.attributes);

  @override
  int get hashCode => Object.hash(tag, Object.hashAll(attributes));
}

@immutable
class IppMessage {
  const IppMessage({
    this.majorVersion = 1,
    this.minorVersion = 1,
    required this.operationOrStatus,
    required this.requestId,
    this.attributeGroups = const [],
    this.data = const [],
  });

  final int majorVersion;
  final int minorVersion;
  final int operationOrStatus;
  final int requestId;
  final List<IppAttributeGroup> attributeGroups;
  final List<int> data;

  IppAttribute? findAttribute(String name) {
    for (final group in attributeGroups) {
      final attr = group.getAttribute(name);
      if (attr != null) return attr;
    }
    return null;
  }

  List<dynamic> findAttributeValues(String name) {
    final attr = findAttribute(name);
    return attr?.values ?? const [];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IppMessage &&
          runtimeType == other.runtimeType &&
          majorVersion == other.majorVersion &&
          minorVersion == other.minorVersion &&
          operationOrStatus == other.operationOrStatus &&
          requestId == other.requestId &&
          listEquals(attributeGroups, other.attributeGroups) &&
          listEquals(data, other.data);

  @override
  int get hashCode => Object.hash(
        majorVersion,
        minorVersion,
        operationOrStatus,
        requestId,
        Object.hashAll(attributeGroups),
        Object.hashAll(data),
      );
}

class IppException implements Exception {
  const IppException(this.message);
  final String message;

  @override
  String toString() => 'IppException: $message';
}

class IppMalformedMessageException extends IppException {
  const IppMalformedMessageException(super.message);
}
