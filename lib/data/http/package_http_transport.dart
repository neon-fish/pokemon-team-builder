import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pokemon_team_builder/data/http/http_transport.dart';

/// [HttpTransport] backed by `package:http`.
///
/// `package:http` is used purely as the socket layer. Status mapping, decoding
/// and error handling are ours.
class PackageHttpTransport implements HttpTransport {
  PackageHttpTransport({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<TransportResponse> get(Uri url) async {
    final http.Response response;
    try {
      response = await _client.get(url);
    } on http.ClientException catch (e) {
      // On web this is what a failed fetch looks like: offline, DNS failure,
      // or a request blocked by CORS.
      throw TransportException(e.message);
    }
    return TransportResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      // Decode as UTF-8 ourselves: without a charset in the response,
      // `response.body` falls back to Latin-1 and mangles names like Flabébé.
      body: utf8.decode(response.bodyBytes, allowMalformed: true),
    );
  }

  /// Releases the underlying connection. Call when the transport is discarded.
  void close() => _client.close();
}
