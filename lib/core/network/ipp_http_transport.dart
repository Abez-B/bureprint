import 'dart:io';
import 'dart:typed_data';

import '../../domain/models/printer_device.dart';

abstract interface class IppHttpTransport {
  Future<Uint8List> sendIppRequest({
    required Uri endpoint,
    required Uint8List requestBytes,
    required TransportSecurityPolicy securityPolicy,
    Duration timeout = const Duration(seconds: 15),
  });
}

class StandardIppHttpTransport implements IppHttpTransport {
  const StandardIppHttpTransport();

  @override
  Future<Uint8List> sendIppRequest({
    required Uri endpoint,
    required Uint8List requestBytes,
    required TransportSecurityPolicy securityPolicy,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final client = HttpClient();

    // Security policy handling:
    // - ippsStrict: platform default certificate validation (strict TLS)
    // - ippsAllowSelfSigned: printer-scoped exception allowing self-signed certificates
    // - plainIppExplicit: unencrypted HTTP (explicit user opt-in only)
    if (securityPolicy == TransportSecurityPolicy.ippsAllowSelfSigned) {
      client.badCertificateCallback =
          (X509Certificate cert, String host, int port) {
        // Scoped to this specific host/port connection attempt
        return host == endpoint.host && port == endpoint.port;
      };
    }

    try {
      // Convert ipp/ipps scheme to standard http/https for dart:io HttpClient
      final httpUri = endpoint.replace(
        scheme: endpoint.scheme == 'ipps' ? 'https' : 'http',
      );

      final request = await client.postUrl(httpUri).timeout(timeout);
      request.headers.set('Content-Type', 'application/ipp');
      request.headers.set('Accept', 'application/ipp');
      request.contentLength = requestBytes.length;
      request.add(requestBytes);

      final response = await request.close().timeout(timeout);

      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'IPP server returned HTTP ${response.statusCode} (${response.reasonPhrase})',
          uri: endpoint,
        );
      }

      final bytesBuilder = BytesBuilder();
      await for (final chunk in response.timeout(timeout)) {
        bytesBuilder.add(chunk);
      }
      return bytesBuilder.toBytes();
    } finally {
      client.close();
    }
  }
}
