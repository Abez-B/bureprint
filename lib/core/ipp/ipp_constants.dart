/// Standard RFC 8010 & RFC 8011 IPP constants, operation IDs, status codes, and delimiter tags.
class IppConstants {
  const IppConstants._();

  // Version numbers
  static const int majorVersion1 = 1;
  static const int minorVersion1 = 1;
  static const int majorVersion2 = 2;
  static const int minorVersion0 = 0;

  // Delimiter tags (RFC 8010 Section 3.5.1)
  static const int operationAttributesTag = 0x01;
  static const int jobAttributesTag = 0x02;
  static const int endOfAttributesTag = 0x03;
  static const int printerAttributesTag = 0x04;
  static const int unsupportedAttributesTag = 0x05;

  // Value tags (RFC 8010 Section 3.5.2)
  static const int tagUnsupported = 0x10;
  static const int tagUnknown = 0x12;
  static const int tagNoValue = 0x13;
  static const int tagInteger = 0x21;
  static const int tagBoolean = 0x22;
  static const int tagEnum = 0x23;
  static const int tagOctetString = 0x30;
  static const int tagDateTime = 0x31;
  static const int tagResolution = 0x32;
  static const int tagRangeOfInteger = 0x33;
  static const int tagTextWithLanguage = 0x35;
  static const int tagNameWithLanguage = 0x36;
  static const int tagTextWithoutLanguage = 0x41;
  static const int tagNameWithoutLanguage = 0x42;
  static const int tagKeyword = 0x44;
  static const int tagUri = 0x45;
  static const int tagUriScheme = 0x46;
  static const int tagCharset = 0x47;
  static const int tagNaturalLanguage = 0x48;
  static const int tagMimeMediaType = 0x49;

  // Operations (RFC 8011 Section 4)
  static const int opPrintJob = 0x0002;
  static const int opValidateJob = 0x0004;
  static const int opCreateJob = 0x0005;
  static const int opSendDocument = 0x0006;
  static const int opCancelJob = 0x0008;
  static const int opGetJobAttributes = 0x0009;
  static const int opGetPrinterAttributes = 0x000B;

  // Status codes (RFC 8011 Section 6)
  static const int statusSuccessfulOk = 0x0000;
  static const int statusSuccessfulOkIgnoredOrSubstituted = 0x0001;
  static const int statusSuccessfulOkConflictingAttributes = 0x0002;

  static const int statusClientErrorBadRequest = 0x0400;
  static const int statusClientErrorForbidden = 0x0401;
  static const int statusClientErrorNotAuthenticated = 0x0402;
  static const int statusClientErrorNotAuthorized = 0x0403;
  static const int statusClientErrorNotFound = 0x0406;
  static const int statusClientErrorGone = 0x0407;
  static const int statusClientErrorRequestEntityTooLarge = 0x0408;
  static const int statusClientErrorRequestValueTooLong = 0x0409;
  static const int statusClientErrorDocumentFormatNotSupported = 0x040A;
  static const int statusClientErrorAttributesOrValuesNotSupported = 0x040B;

  static const int statusServerErrorInternalError = 0x0500;
  static const int statusServerErrorOperationNotSupported = 0x0501;
  static const int statusServerErrorServiceUnavailable = 0x0502;
  static const int statusServerErrorVersionNotSupported = 0x0503;
  static const int statusServerErrorDeviceError = 0x0504;
  static const int statusServerErrorTemporaryError = 0x0505;
  static const int statusServerErrorNotAcceptingJobs = 0x0506;
}
