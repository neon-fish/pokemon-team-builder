import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokemon_team_builder/data/http/http_transport.dart';
import 'package:pokemon_team_builder/data/http/package_http_transport.dart';

void main() {
  final url = Uri.parse('https://example.test/pokemon/1');

  test('close releases the underlying client', () {
    final client = _CloseTrackingClient();
    PackageHttpTransport(client: client).close();
    expect(client.closed, isTrue);
  });

  test('returns status, headers and body', () async {
    final transport = PackageHttpTransport(
      client: MockClient(
        (_) async =>
            http.Response('{"ok":true}', 200, headers: {'x-test': 'yes'}),
      ),
    );
    final response = await transport.get(url);
    expect(response.statusCode, 200);
    expect(response.headers['x-test'], 'yes');
    expect(response.body, '{"ok":true}');
  });

  test('passes error statuses through rather than throwing', () async {
    final transport = PackageHttpTransport(
      client: MockClient((_) async => http.Response('', 503)),
    );
    expect((await transport.get(url)).statusCode, 503);
  });

  test('decodes UTF-8 even when the response names no charset', () async {
    final bytes = utf8.encode('{"name":"Flabébé"}');
    final transport = PackageHttpTransport(
      client: MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    expect((await transport.get(url)).body, '{"name":"Flabébé"}');
  });

  test('does not crash on malformed UTF-8', () async {
    final transport = PackageHttpTransport(
      client: MockClient(
        (_) async => http.Response.bytes([0x7b, 0xff, 0x7d], 200),
      ),
    );
    expect((await transport.get(url)).body, isNotEmpty);
  });

  test('a client exception becomes a TransportException', () async {
    final transport = PackageHttpTransport(
      client: MockClient(
        (_) async => throw http.ClientException('Failed to fetch'),
      ),
    );
    await expectLater(
      transport.get(url),
      throwsA(
        isA<TransportException>().having(
          (e) => e.message,
          'message',
          'Failed to fetch',
        ),
      ),
    );
  });
}

class _CloseTrackingClient extends http.BaseClient {
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw UnimplementedError();

  @override
  void close() => closed = true;
}
