library gleap_http_interceptor;

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:gleap_sdk/gleap_sdk.dart';
import 'package:gleap_sdk/helpers/gleap_network_log_helper.dart';
import 'package:http_interceptor/http_interceptor.dart';

/// Logs requests made with an http_interceptor `InterceptedClient` to Gleap,
/// so they show up in the activity log of tickets and bug reports.
///
/// ```dart
/// final Client client = InterceptedClient.build(interceptors: [
///   GleapHttpInterceptor(),
/// ]);
/// ```
///
/// Every request is logged with its full url, method, start time, duration,
/// request / response headers and text bodies (capped at 150 KB).
///
/// The interceptor never changes a request. Response bodies arrive as a
/// stream: text bodies are observed while the app reads them (every chunk
/// is passed on unchanged, at most 150 KB is copied) and the request is
/// logged once the body is complete. Binary and streaming bodies (server-sent
/// events, ndjson, grpc) are not observed at all.
///
/// Requests that fail without a response (no connection, timeout, TLS
/// error) are not logged: http_interceptor does not pass errors to
/// interceptors.
class GleapHttpInterceptor implements HttpInterceptor {
  GleapHttpInterceptor();

  static final Stopwatch _clock = Stopwatch()..start();
  static final Expando<int> _requestStarts = Expando<int>('gleapRequestStart');

  @override
  FutureOr<bool> shouldInterceptRequest({required BaseRequest request}) =>
      true;

  @override
  FutureOr<bool> shouldInterceptResponse({required BaseResponse response}) =>
      true;

  @override
  FutureOr<BaseRequest> interceptRequest({required BaseRequest request}) {
    try {
      _requestStarts[request] = _clock.elapsedMicroseconds;
    } catch (_) {}

    return request;
  }

  @override
  FutureOr<BaseResponse> interceptResponse({required BaseResponse response}) {
    try {
      final BaseRequest? request = response.request;
      if (request == null) {
        return response;
      }

      final int? start = _requestStarts[request];
      final String? contentType =
          GleapNetworkLogHelper.headerValue(response.headers, 'content-type');

      if (response is Response) {
        _log(
          request,
          response,
          start,
          responseText: _decode(response.bodyBytes, contentType),
        );
        return response;
      }

      if (response is StreamedResponse && _isCapturable(contentType)) {
        return _observe(response, (_BodyCapture capture) {
          _log(
            request,
            response,
            start,
            responseText: capture.cancelled
                ? GleapNetworkLogHelper.bodyNotCapturedMarker
                : GleapNetworkLogHelper.decodeBody(
                    capture.bytes,
                    contentType: contentType,
                    totalBytes: capture.totalBytes,
                  ),
            errorText: capture.error != null
                ? 'Reading the response body failed: ${capture.error}'
                : null,
          );
        });
      }

      _log(
        request,
        response,
        start,
        responseText: response is StreamedResponse
            ? _marker(contentType)
            : GleapNetworkLogHelper.bodyNotCapturedMarker,
      );
    } catch (_) {}

    return response;
  }

  /// Text-like and unknown content types are observed; unknown ones are
  /// only kept when they turn out to be UTF-8 text.
  static bool _isCapturable(String? contentType) {
    if (contentType == null || contentType.trim().isEmpty) {
      return true;
    }

    return GleapNetworkLogHelper.isTextContentType(contentType);
  }

  static String _marker(String? contentType) {
    return GleapNetworkLogHelper.isStreamingContentType(contentType)
        ? GleapNetworkLogHelper.streamingBodyMarker
        : GleapNetworkLogHelper.binaryBodyMarker;
  }

  static String _decode(List<int> bytes, String? contentType) {
    final int total = bytes.length;
    return GleapNetworkLogHelper.decodeBody(
      total > GleapNetworkLogHelper.maxBodyLength
          ? bytes.sublist(0, GleapNetworkLogHelper.maxBodyLength)
          : bytes,
      contentType: contentType,
      totalBytes: total,
    );
  }

  /// Returns a response whose body stream passes every event of
  /// [response.stream] through unchanged (including pause, resume and
  /// cancel) while copying at most 150 KB; [onEnd] runs once when the body
  /// is complete, failed or was cancelled.
  static StreamedResponse _observe(
    StreamedResponse response,
    void Function(_BodyCapture capture) onEnd,
  ) {
    final _BodyCapture capture = _BodyCapture();
    final StreamController<List<int>> controller =
        StreamController<List<int>>(sync: true);
    StreamSubscription<List<int>>? subscription;
    bool ended = false;

    void end() {
      if (ended) {
        return;
      }
      ended = true;
      try {
        onEnd(capture);
      } catch (_) {}
    }

    controller.onListen = () {
      subscription = response.stream.listen(
        (List<int> chunk) {
          capture.add(chunk);
          controller.add(chunk);
        },
        onError: (Object error, StackTrace stackTrace) {
          capture.error ??= error;
          end();
          controller.addError(error, stackTrace);
        },
        onDone: () {
          end();
          controller.close();
        },
      );
    };
    controller.onPause = () => subscription?.pause();
    controller.onResume = () => subscription?.resume();
    controller.onCancel = () {
      if (!ended) {
        capture.cancelled = true;
      }
      end();
      return subscription?.cancel();
    };

    return StreamedResponse(
      controller.stream,
      response.statusCode,
      contentLength: response.contentLength,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  static void _log(
    BaseRequest request,
    BaseResponse response,
    int? start, {
    required String responseText,
    String? errorText,
  }) {
    try {
      final int elapsedMicroseconds =
          start != null ? math.max(0, _clock.elapsedMicroseconds - start) : 0;

      Gleap.logNetworkRequest(
        GleapNetworkLog(
          type: request.method.toUpperCase(),
          url: request.url.toString(),
          date: DateTime.now()
              .subtract(Duration(microseconds: elapsedMicroseconds)),
          duration: elapsedMicroseconds / 1000,
          success: true,
          request: GleapNetworkRequest(
            headers: request.headers,
            payload: _requestBody(request),
          ),
          response: GleapNetworkResponse(
            status: response.statusCode,
            statusText: response.reasonPhrase,
            headers: response.headers,
            responseText: responseText,
            errorText: errorText,
          ),
        ),
      );
    } catch (_) {}
  }

  static String _requestBody(BaseRequest request) {
    try {
      if (request is Request) {
        return _decode(
          request.bodyBytes,
          GleapNetworkLogHelper.headerValue(request.headers, 'content-type'),
        );
      }

      if (request is MultipartRequest) {
        // Fields and file metadata only (never file contents); JSON, so the
        // props to ignore apply to the field names.
        return jsonEncode(<String, dynamic>{
          'fields': request.fields,
          'files': <Map<String, dynamic>>[
            for (final MultipartFile file in request.files)
              <String, dynamic>{
                'field': file.field,
                'filename': file.filename,
                'contentType': file.contentType.toString(),
                'length': file.length,
              },
          ],
        });
      }

      if (request is StreamedRequest) {
        return GleapNetworkLogHelper.streamingBodyMarker;
      }
    } catch (_) {}

    return GleapNetworkLogHelper.bodyNotCapturedMarker;
  }
}

class _BodyCapture {
  final BytesBuilder _builder = BytesBuilder(copy: true);
  int totalBytes = 0;
  Object? error;
  bool cancelled = false;

  void add(List<int> chunk) {
    try {
      final int remaining =
          GleapNetworkLogHelper.maxBodyLength - _builder.length;
      if (remaining > 0) {
        _builder.add(
          chunk.length > remaining ? chunk.sublist(0, remaining) : chunk,
        );
      }
      totalBytes += chunk.length;
    } catch (_) {}
  }

  List<int> get bytes => _builder.toBytes();
}
