import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:gleap_http_interceptor/gleap_http_interceptor.dart';
import 'package:http/testing.dart';
import 'package:http_interceptor/http_interceptor.dart';

// The interceptor observes the app's response body stream, so it has to hand
// every byte, error and cancel through unchanged.
void main() {
  Stream<List<int>> chunked(List<int> body) {
    const int chunkSize = 65536;
    return Stream<List<int>>.fromIterable(<List<int>>[
      for (int i = 0; i < body.length; i += chunkSize)
        body.sublist(i, math.min(i + chunkSize, body.length)),
    ]);
  }

  test('passes text and binary bodies through unchanged', () async {
    final List<int> text = utf8.encode('{"data":"${'x' * 400000}"}');
    final List<int> binary = List<int>.generate(300000, (int i) => i % 256);
    final Client client = InterceptedClient.build(
      interceptors: <HttpInterceptor>[GleapHttpInterceptor()],
      client: MockClient.streaming((BaseRequest request, _) async {
        final bool isText = request.url.path == '/text';
        return StreamedResponse(
          chunked(isText ? text : binary),
          200,
          request: request,
          headers: <String, String>{
            'content-type':
                isText ? 'application/json' : 'application/octet-stream',
          },
        );
      }),
    );

    final Response textResponse =
        await client.get(Uri.parse('https://api.example.com/text'));
    final Response binaryResponse =
        await client.get(Uri.parse('https://api.example.com/binary'));

    expect(textResponse.bodyBytes, text);
    expect(binaryResponse.bodyBytes, binary);
  });

  test('passes body errors and cancellation through', () async {
    bool upstreamCancelled = false;
    final Client client = InterceptedClient.build(
      interceptors: <HttpInterceptor>[GleapHttpInterceptor()],
      client: MockClient.streaming((BaseRequest request, _) async {
        final bool isCancelTest = request.url.path == '/cancel';
        final StreamController<List<int>> body = StreamController<List<int>>(
          onCancel: () => upstreamCancelled = upstreamCancelled || isCancelTest,
        );
        body.add(utf8.encode('{"partial":'));
        if (request.url.path == '/error') {
          body.addError(const FormatException('connection reset'));
          body.close();
        }
        return StreamedResponse(
          body.stream,
          200,
          request: request,
          headers: <String, String>{'content-type': 'application/json'},
        );
      }),
    );

    await expectLater(
      client.get(Uri.parse('https://api.example.com/error')),
      throwsA(isA<FormatException>()),
    );

    final StreamedResponse streamed = await client
        .send(Request('GET', Uri.parse('https://api.example.com/cancel')));
    expect(utf8.decode(await streamed.stream.first), '{"partial":');
    expect(upstreamCancelled, isTrue);
  });
}
